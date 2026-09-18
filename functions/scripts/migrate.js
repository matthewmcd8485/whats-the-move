#!/usr/bin/env node
/**
 * One-off data migration for the schema change that moved bored requests to a
 * top-level collection and made contact matching server-side.
 *
 * Idempotent: every step skips documents that are already in the target shape,
 * so re-running it is safe and is the intended way to recover from a partial
 * run.
 *
 * Steps:
 *
 *   1. `Phone Key` on every user document — the last 10 digits of their phone
 *      number. `findUsersByPhone` queries this field, so contact matching and
 *      the add-friend search both find nobody until it exists.
 *
 *   2. `Blocked On` from a preformatted string to a real Timestamp. Nothing
 *      reads the field today; this is so it's sortable if anything ever does.
 *
 *   3. Reports gain nothing here — the old ones can't be attributed, because
 *      who filed them was never recorded. They're left alone.
 *
 * Old bored requests under `friend groups/{id}/bored requests/{id}` are NOT
 * migrated. Requests expire within hours, so there's nothing worth carrying
 * over; `--purge-old-requests` deletes them once they've all aged out.
 *
 * Usage:
 *
 *   # Authenticate once. Either works:
 *   gcloud auth application-default login
 *   #   ...or set GOOGLE_APPLICATION_CREDENTIALS to a service-account key path.
 *
 *   node scripts/migrate.js --project <your-project-id> --dry-run
 *   node scripts/migrate.js --project <your-project-id>
 *   node scripts/migrate.js --project <your-project-id> --purge-old-requests
 */

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");
const PURGE_OLD_REQUESTS = args.includes("--purge-old-requests");

const projectFlag = args.indexOf("--project");
const PROJECT_ID =
  projectFlag !== -1 ? args[projectFlag + 1] : process.env.GOOGLE_CLOUD_PROJECT;

if (!PROJECT_ID) {
  console.error("Pass --project <id>, or set GOOGLE_CLOUD_PROJECT.");
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

// Firestore caps a batch at 500 writes.
const BATCH_LIMIT = 400;

function phoneKey(raw) {
  if (typeof raw !== "string") return "";
  return raw.replace(/\D/g, "").slice(-10);
}

/** Applies `updates` in chunked batches. */
async function commit(updates, label) {
  if (updates.length === 0) {
    console.log(`  ${label}: nothing to do`);
    return;
  }
  if (DRY_RUN) {
    console.log(`  ${label}: would write ${updates.length} document(s)`);
    return;
  }

  for (let i = 0; i < updates.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const { ref, data } of updates.slice(i, i + BATCH_LIMIT)) {
      batch.set(ref, data, { merge: true });
    }
    await batch.commit();
  }
  console.log(`  ${label}: wrote ${updates.length} document(s)`);
}

// MARK: - 1. Phone Key

async function backfillPhoneKeys() {
  console.log("Phone Key on users");
  const snapshot = await db.collection("users").get();

  const updates = [];
  let skippedDeleted = 0;

  for (const doc of snapshot.docs) {
    const name = doc.get("Name");
    const number = doc.get("Phone Number");

    // A soft-deleted account has "user deleted" in every field, phone number
    // included. Giving it a key would make every deleted account collide on
    // one value and show up as a contact match.
    if (name === "user deleted" || number === "user deleted") {
      if (doc.get("Phone Key") !== "") {
        updates.push({ ref: doc.ref, data: { "Phone Key": "" } });
      }
      skippedDeleted++;
      continue;
    }

    const key = phoneKey(number);
    if (key.length !== 10) {
      console.warn(`  ! ${doc.id}: unusable phone number ${JSON.stringify(number)}`);
      continue;
    }
    if (doc.get("Phone Key") === key) continue;

    updates.push({ ref: doc.ref, data: { "Phone Key": key } });
  }

  console.log(`  ${snapshot.size} user(s), ${skippedDeleted} soft-deleted`);
  await commit(updates, "Phone Key");
}

// MARK: - 2. Blocked On

async function convertBlockedOn() {
  console.log("Blocked On to Timestamp");
  const snapshot = await db.collection("blocked users").get();

  const updates = [];
  for (const doc of snapshot.docs) {
    const value = doc.get("Blocked On");
    if (typeof value !== "string") continue; // already a Timestamp

    // Written as "yyyy-MM-dd 'at' HH:mm:ss" in local time, which is all
    // there is to go on.
    const parsed = new Date(value.replace(" at ", " "));
    if (Number.isNaN(parsed.getTime())) {
      console.warn(`  ! ${doc.id}: unparseable date ${JSON.stringify(value)}`);
      continue;
    }
    updates.push({
      ref: doc.ref,
      data: { "Blocked On": Timestamp.fromDate(parsed) },
    });
  }

  console.log(`  ${snapshot.size} block(s)`);
  await commit(updates, "Blocked On");
}

// MARK: - 3. Old request subcollections

async function purgeOldRequests() {
  console.log("Old bored request subcollections");
  const groups = await db.collection("friend groups").get();

  let found = 0;
  const refs = [];
  for (const group of groups.docs) {
    const requests = await group.ref.collection("bored requests").get();
    found += requests.size;
    for (const request of requests.docs) refs.push(request.ref);
  }

  console.log(`  ${found} old request(s) under ${groups.size} group(s)`);

  if (refs.length === 0) return;
  if (DRY_RUN) {
    console.log(`  would delete ${refs.length} document(s)`);
    return;
  }

  for (let i = 0; i < refs.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const ref of refs.slice(i, i + BATCH_LIMIT)) batch.delete(ref);
    await batch.commit();
  }
  console.log(`  deleted ${refs.length} document(s)`);
}

// MARK: - Run

(async () => {
  console.log(
    `Project ${PROJECT_ID}${DRY_RUN ? " (dry run — nothing will be written)" : ""}\n`,
  );

  await backfillPhoneKeys();
  await convertBlockedOn();

  if (PURGE_OLD_REQUESTS) {
    await purgeOldRequests();
  } else {
    console.log("Old request subcollections left alone (--purge-old-requests to delete)");
  }

  console.log("\nDone.");
  process.exit(0);
})().catch((err) => {
  console.error("\nMigration failed:", err);
  process.exit(1);
});
