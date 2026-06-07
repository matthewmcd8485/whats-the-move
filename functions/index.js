/**
 * wtm? — Firebase Cloud Functions
 *
 * Fans out a push notification whenever a new bored request lands in Firestore.
 *
 * Trigger: friend groups/{groupId}/bored requests/{requestId} document create.
 * Sends a multicast push via FCM HTTP v1 to every group member except the
 * initiator, blocked pairs (either direction), and anyone whose Status is
 * "do not disturb". Honors the request's "Time Sensitive" flag.
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/v2");

initializeApp();

// Firestore collection / field names — keep in sync with FirestoreKeys.swift
const COLLECTIONS = {
  users: "users",
  friendGroups: "friend groups",
  boredRequests: "bored requests",
  blockedUsers: "blocked users",
};

const REQUEST_FIELDS = {
  requestIdentifier: "Request Identifier",
  groupIdentifier: "Group Identifier",
  initiatedBy: "Initiated By",
  activity: "Activity",
  timeSensitive: "Time Sensitive",
  availabilitySuffix: " Availability",
};

const USER_FIELDS = {
  fcmToken: "FCM Token",
  status: "Status",
  name: "Name",
};

const GROUP_FIELDS = {
  people: "People",
};

const BLOCKED_FIELDS = {
  blockingUserIdentifier: "Blocking User's Identifier",
  blockedUserIdentifier: "Blocked User's Identifier",
};

exports.fanOutBoredRequest = onDocumentCreated(
  {
    document: "friend groups/{groupId}/bored requests/{requestId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("No snapshot in event");
      return;
    }

    const data = snap.data();
    const groupId = event.params.groupId;
    const requestId = event.params.requestId;

    const activity = data[REQUEST_FIELDS.activity];
    const initiatorName = data[REQUEST_FIELDS.initiatedBy];
    const timeSensitive = data[REQUEST_FIELDS.timeSensitive] === true;

    if (!activity || !initiatorName) {
      logger.warn("Missing activity or initiator name", { requestId, groupId });
      return;
    }

    // The initiator's UID isn't stored as its own field — it's the prefix of
    // the only `<uid> Availability` key written at create time. Extract it.
    let initiatorUID = null;
    for (const key of Object.keys(data)) {
      if (key.endsWith(REQUEST_FIELDS.availabilitySuffix)) {
        initiatorUID = key.slice(0, -REQUEST_FIELDS.availabilitySuffix.length);
        break;
      }
    }
    if (!initiatorUID) {
      logger.warn("Could not determine initiator UID from request", { requestId, groupId });
      return;
    }

    const db = getFirestore();

    // Group people
    const groupDoc = await db.collection(COLLECTIONS.friendGroups).doc(groupId).get();
    const people = groupDoc.get(GROUP_FIELDS.people) || [];
    if (people.length === 0) {
      logger.info("Group has no people", { groupId });
      return;
    }

    // Blocked pairs (either direction) involving the initiator
    const [outgoingBlockSnap, incomingBlockSnap] = await Promise.all([
      db
        .collection(COLLECTIONS.blockedUsers)
        .where(BLOCKED_FIELDS.blockingUserIdentifier, "==", initiatorUID)
        .get(),
      db
        .collection(COLLECTIONS.blockedUsers)
        .where(BLOCKED_FIELDS.blockedUserIdentifier, "==", initiatorUID)
        .get(),
    ]);

    const blockedByInitiator = new Set();
    for (const doc of outgoingBlockSnap.docs) {
      const uid = doc.get(BLOCKED_FIELDS.blockedUserIdentifier);
      if (uid) blockedByInitiator.add(uid);
    }
    const blockingInitiator = new Set();
    for (const doc of incomingBlockSnap.docs) {
      const uid = doc.get(BLOCKED_FIELDS.blockingUserIdentifier);
      if (uid) blockingInitiator.add(uid);
    }

    const candidateUIDs = people.filter(
      (uid) =>
        typeof uid === "string" &&
        uid !== initiatorUID &&
        !blockedByInitiator.has(uid) &&
        !blockingInitiator.has(uid),
    );

    if (candidateUIDs.length === 0) {
      logger.info("No candidates remain after filtering", { requestId, groupId });
      return;
    }

    // Resolve FCM tokens, skipping DND users and empty tokens
    const userDocs = await Promise.all(
      candidateUIDs.map((uid) => db.collection(COLLECTIONS.users).doc(uid).get()),
    );

    const tokens = [];
    const tokenToUID = new Map();
    for (let i = 0; i < userDocs.length; i++) {
      const userDoc = userDocs[i];
      if (!userDoc.exists) continue;
      const status = userDoc.get(USER_FIELDS.status);
      if (status === "do not disturb") continue;
      const token = userDoc.get(USER_FIELDS.fcmToken);
      if (typeof token === "string" && token.length > 0 && token !== "no token") {
        tokens.push(token);
        tokenToUID.set(token, candidateUIDs[i]);
      }
    }

    if (tokens.length === 0) {
      logger.info("No deliverable tokens", { requestId, groupId });
      return;
    }

    const title = `${initiatorName} ${activity}`;
    const body = "tap to respond";

    const apsBase = {
      sound: "default",
      "thread-id": groupId,
      category: "CustomPush",
      "mutable-content": 1,
    };

    const message = {
      tokens,
      notification: { title, body },
      data: {
        requestId,
        groupId,
        activity,
        initiator: initiatorName,
        initiatorUID,
        timeSensitive: timeSensitive ? "true" : "false",
      },
      apns: {
        headers: {
          "apns-priority": timeSensitive ? "10" : "5",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            ...apsBase,
            "interruption-level": timeSensitive ? "time-sensitive" : "active",
          },
        },
      },
      android: {
        priority: timeSensitive ? "high" : "normal",
        notification: {
          channelId: timeSensitive ? "wtm_time_sensitive" : "wtm_default",
        },
      },
    };

    const response = await getMessaging().sendEachForMulticast(message);

    logger.info("Fan-out complete", {
      requestId,
      groupId,
      timeSensitive,
      delivered: response.successCount,
      failed: response.failureCount,
      totalRecipients: tokens.length,
    });

    // Clean up FCM tokens that the service tells us are dead.
    if (response.failureCount > 0) {
      const staleTokens = [];
      response.responses.forEach((r, idx) => {
        if (!r.success && r.error) {
          const code = r.error.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token" ||
            code === "messaging/invalid-argument"
          ) {
            staleTokens.push(tokens[idx]);
          } else {
            logger.warn("Push failed for a token", { code, message: r.error.message });
          }
        }
      });

      await Promise.all(
        staleTokens.map(async (token) => {
          const uid = tokenToUID.get(token);
          if (!uid) return;
          try {
            const userRef = db.collection(COLLECTIONS.users).doc(uid);
            const current = (await userRef.get()).get(USER_FIELDS.fcmToken);
            if (current === token) {
              await userRef.update({ [USER_FIELDS.fcmToken]: "" });
              logger.info("Cleared stale FCM token", { uid });
            }
          } catch (err) {
            logger.warn("Failed to clear stale token", { uid, err: err.message });
          }
        }),
      );
    }
  },
);
