/**
 * wtm? — Firebase Cloud Functions
 *
 * Two push fan-outs, both on `friend groups/{groupId}/bored requests/{requestId}`:
 *
 * - `fanOutBoredRequest` (document create) — someone is bored. Goes to every
 *   group member except the initiator, carries the activity artwork, and offers
 *   the reply buttons on the "CustomPush" category.
 *
 * - `fanOutBoredResponse` (document update) — someone answered. Goes to the rest
 *   of the group, including the initiator, who is the person actually waiting
 *   to hear. This restores the client-side fan-out that
 *   `BoredRequestResponseViewController.notifyFriends` used to do before the
 *   SwiftUI migration, which left the message-composing behind with a note that
 *   it needed a trigger on response updates. This is that trigger; the wording
 *   is carried over verbatim.
 *
 * Both skip blocked pairs (either direction), anyone whose Status is
 * "do not disturb", and dead device tokens — which get cleared as they're found.
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/v2");

initializeApp();

const REGION = "us-central1";
const REQUEST_DOCUMENT = "friend groups/{groupId}/bored requests/{requestId}";

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
  imageURL: "Image URL",
  availabilitySuffix: " Availability",
  substatusSuffix: " Substatus",
};

const USER_FIELDS = {
  fcmToken: "FCM Token",
  status: "Status",
  name: "Name",
};

const GROUP_FIELDS = {
  people: "People",
  name: "Name",
  direct: "Direct",
};

const BLOCKED_FIELDS = {
  blockingUserIdentifier: "Blocking User's Identifier",
  blockedUserIdentifier: "Blocked User's Identifier",
};

/**
 * Titles for a response push, keyed by the availability that was chosen.
 * Must stay in step with `BoredResponseCategory` in the app — "custom" is a
 * reply that deliberately didn't say whether the person is free.
 */
const RESPONSE_TITLES = {
  "available": (name) => `${name} is in!`,
  "busy": (name) => `${name} might be busy`,
  "not available": (name) => `${name} is not available`,
  "custom": (name) => `${name} replied`,
};

// MARK: - Shared recipient resolution

/**
 * Everyone in `groupId` who should receive a push about something `actorUID`
 * did: group members minus the actor, minus blocked pairs in either direction,
 * minus anyone on "do not disturb", minus empty or placeholder tokens.
 *
 * Returns `{ tokens, tokenToUID, groupDoc }`.
 */
async function resolveRecipients(db, groupId, actorUID) {
  const groupDoc = await db.collection(COLLECTIONS.friendGroups).doc(groupId).get();
  const people = groupDoc.get(GROUP_FIELDS.people) || [];
  if (people.length === 0) {
    logger.info("Group has no people", { groupId });
    return { tokens: [], tokenToUID: new Map(), groupDoc };
  }

  const [outgoingBlockSnap, incomingBlockSnap] = await Promise.all([
    db
      .collection(COLLECTIONS.blockedUsers)
      .where(BLOCKED_FIELDS.blockingUserIdentifier, "==", actorUID)
      .get(),
    db
      .collection(COLLECTIONS.blockedUsers)
      .where(BLOCKED_FIELDS.blockedUserIdentifier, "==", actorUID)
      .get(),
  ]);

  const blockedByActor = new Set();
  for (const doc of outgoingBlockSnap.docs) {
    const uid = doc.get(BLOCKED_FIELDS.blockedUserIdentifier);
    if (uid) blockedByActor.add(uid);
  }
  const blockingActor = new Set();
  for (const doc of incomingBlockSnap.docs) {
    const uid = doc.get(BLOCKED_FIELDS.blockingUserIdentifier);
    if (uid) blockingActor.add(uid);
  }

  const candidateUIDs = people.filter(
    (uid) =>
      typeof uid === "string" &&
      uid !== actorUID &&
      !blockedByActor.has(uid) &&
      !blockingActor.has(uid),
  );

  if (candidateUIDs.length === 0) {
    logger.info("No candidates remain after filtering", { groupId, actorUID });
    return { tokens: [], tokenToUID: new Map(), groupDoc };
  }

  const [actorDoc, ...userDocs] = await Promise.all([
    db.collection(COLLECTIONS.users).doc(actorUID).get(),
    ...candidateUIDs.map((uid) => db.collection(COLLECTIONS.users).doc(uid).get()),
  ]);

  // Filtering by UID isn't enough on its own: a device that has been signed in
  // to more than one account can leave its token on an old account's document,
  // and pushing that token delivers the message back to the person who caused
  // it. Excluding the actor's own token covers that directly.
  const actorToken = actorDoc.exists ? actorDoc.get(USER_FIELDS.fcmToken) : null;

  const tokens = [];
  const tokenToUID = new Map();
  for (let i = 0; i < userDocs.length; i++) {
    const userDoc = userDocs[i];
    if (!userDoc.exists) continue;
    if (userDoc.get(USER_FIELDS.status) === "do not disturb") continue;

    const token = userDoc.get(USER_FIELDS.fcmToken);
    if (typeof token !== "string" || token.length === 0 || token === "no token") continue;
    if (actorToken && token === actorToken) {
      logger.info("Skipped a token that matches the actor's", { uid: candidateUIDs[i] });
      continue;
    }
    tokens.push(token);
    tokenToUID.set(token, candidateUIDs[i]);
  }

  return { tokens, tokenToUID, groupDoc };
}

/** Clears FCM tokens that the service reports as dead. */
async function clearStaleTokens(db, response, tokens, tokenToUID) {
  if (response.failureCount === 0) return;

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

/**
 * The initiator's UID isn't stored as its own field — it's the prefix of the
 * only `<uid> Availability` key written at create time.
 */
function initiatorUIDFrom(data) {
  for (const key of Object.keys(data)) {
    if (key.endsWith(REQUEST_FIELDS.availabilitySuffix)) {
      return key.slice(0, -REQUEST_FIELDS.availabilitySuffix.length);
    }
  }
  return null;
}

// MARK: - New bored request

exports.fanOutBoredRequest = onDocumentCreated(
  { document: REQUEST_DOCUMENT, region: REGION },
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
    const rawImageURL = data[REQUEST_FIELDS.imageURL];
    // Only forward a usable https URL — the notification service extension
    // downloads whatever lands in `url`, so junk here costs delivery latency.
    const imageURL =
      typeof rawImageURL === "string" && rawImageURL.startsWith("https://")
        ? rawImageURL
        : null;

    if (!activity || !initiatorName) {
      logger.warn("Missing activity or initiator name", { requestId, groupId });
      return;
    }

    const initiatorUID = initiatorUIDFrom(data);
    if (!initiatorUID) {
      logger.warn("Could not determine initiator UID from request", { requestId, groupId });
      return;
    }

    const db = getFirestore();
    const { tokens, tokenToUID } = await resolveRecipients(db, groupId, initiatorUID);

    if (tokens.length === 0) {
      logger.info("No deliverable tokens", { requestId, groupId });
      return;
    }

    const message = {
      tokens,
      notification: { title: `${initiatorName} ${activity}`, body: "tap to respond" },
      data: {
        requestId,
        groupId,
        activity,
        initiator: initiatorName,
        initiatorUID,
        timeSensitive: timeSensitive ? "true" : "false",
        // `NotificationService` reads this key out of `userInfo` and attaches
        // the download as a UNNotificationAttachment, which is what puts the
        // artwork on the banner and in the expanded notification.
        ...(imageURL ? { url: imageURL } : {}),
      },
      apns: {
        headers: {
          "apns-priority": timeSensitive ? "10" : "5",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            sound: "default",
            "thread-id": groupId,
            category: "CustomPush",
            "mutable-content": 1,
            "interruption-level": timeSensitive ? "time-sensitive" : "active",
          },
        },
      },
      android: {
        priority: timeSensitive ? "high" : "normal",
        notification: {
          channelId: timeSensitive ? "wtm_time_sensitive" : "wtm_default",
          ...(imageURL ? { imageUrl: imageURL } : {}),
        },
      },
    };

    const response = await getMessaging().sendEachForMulticast(message);

    logger.info("Request fan-out complete", {
      requestId,
      groupId,
      timeSensitive,
      hasImage: imageURL !== null,
      delivered: response.successCount,
      failed: response.failureCount,
      totalRecipients: tokens.length,
    });

    await clearStaleTokens(db, response, tokens, tokenToUID);
  },
);

// MARK: - Response to a bored request

/**
 * Finds who just answered by diffing the per-person response fields.
 *
 * The client writes `<uid> Availability` and `<uid> Substatus` together, so one
 * changed key is enough to identify the responder. A repeat of the same send
 * rewrites the document with identical values and so changes nothing here,
 * which is what keeps it from pushing a second time.
 */
function changedResponderUID(before, after) {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);

  for (const key of keys) {
    let uid = null;
    if (key.endsWith(REQUEST_FIELDS.availabilitySuffix)) {
      uid = key.slice(0, -REQUEST_FIELDS.availabilitySuffix.length);
    } else if (key.endsWith(REQUEST_FIELDS.substatusSuffix)) {
      uid = key.slice(0, -REQUEST_FIELDS.substatusSuffix.length);
    }
    if (!uid) continue;

    if (before[key] !== after[key]) return uid;
  }
  return null;
}

exports.fanOutBoredResponse = onDocumentUpdated(
  { document: REQUEST_DOCUMENT, region: REGION },
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const after = event.data && event.data.after ? event.data.after.data() : null;
    if (!before || !after) {
      logger.warn("Missing before/after in update event");
      return;
    }

    const groupId = event.params.groupId;
    const requestId = event.params.requestId;

    const responderUID = changedResponderUID(before, after);
    if (!responderUID) {
      // An edit that touched something other than a response — nothing to say.
      return;
    }

    const availability = after[`${responderUID}${REQUEST_FIELDS.availabilitySuffix}`];
    const substatus = after[`${responderUID}${REQUEST_FIELDS.substatusSuffix}`];
    if (typeof substatus !== "string" || substatus.length === 0) {
      logger.info("Response has no message to relay", { requestId, groupId, responderUID });
      return;
    }

    const db = getFirestore();

    const responderDoc = await db.collection(COLLECTIONS.users).doc(responderUID).get();
    const responderName = responderDoc.exists ? responderDoc.get(USER_FIELDS.name) : null;
    if (!responderName) {
      logger.warn("Could not resolve the responder's name", { requestId, responderUID });
      return;
    }

    const { tokens, tokenToUID, groupDoc } = await resolveRecipients(db, groupId, responderUID);
    if (tokens.length === 0) {
      logger.info("No deliverable tokens for response", { requestId, groupId });
      return;
    }

    const titleFor = RESPONSE_TITLES[availability] || RESPONSE_TITLES["custom"];
    const title = titleFor(responderName);
    const body = `they said "${substatus}"`;

    // A direct group's name isn't anything a person chose, so it's only worth
    // showing for real groups — same rule the request screens follow.
    const isDirect = groupDoc.get(GROUP_FIELDS.direct) === true;
    const groupName = groupDoc.get(GROUP_FIELDS.name);
    const subtitle = !isDirect && typeof groupName === "string" ? groupName : null;

    const message = {
      tokens,
      notification: { title, body },
      data: {
        requestId,
        groupId,
        responderUID,
        responder: responderName,
        availability: typeof availability === "string" ? availability : "custom",
        substatus,
      },
      apns: {
        headers: {
          // Never time-sensitive: an answer is worth knowing, not worth
          // breaking through a Focus for.
          "apns-priority": "5",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            // Spelled out here rather than left to the common `notification`
            // block, because a subtitle has no equivalent there.
            alert: {
              title,
              ...(subtitle ? { subtitle } : {}),
              body,
            },
            sound: "default",
            // Same thread as the request, so an answer files itself under the
            // notification it's answering.
            "thread-id": groupId,
            "interruption-level": "active",
            // No `category`: a response carries no reply buttons of its own.
            // Tapping it still deep-links, off `requestId` / `groupId` above.
          },
        },
      },
      android: {
        priority: "normal",
        notification: { channelId: "wtm_default" },
      },
    };

    const response = await getMessaging().sendEachForMulticast(message);

    logger.info("Response fan-out complete", {
      requestId,
      groupId,
      responderUID,
      availability,
      delivered: response.successCount,
      failed: response.failureCount,
      totalRecipients: tokens.length,
    });

    await clearStaleTokens(db, response, tokens, tokenToUID);
  },
);
