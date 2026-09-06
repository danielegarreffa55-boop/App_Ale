import {
  DocumentReference,
  Firestore,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {DateTime} from "luxon";
import {OpeningDay, StudioConfig} from "./types";

export const LOCK_BUCKET_MINUTES = 5;
const BUCKET_MS = LOCK_BUCKET_MINUTES * 60_000;
const DAY_KEYS = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];

export const defaultOpeningHours: Record<string, OpeningDay> = {
  monday: {enabled: true, open: "09:00", close: "18:00", breaks: []},
  tuesday: {enabled: true, open: "09:00", close: "18:00", breaks: []},
  wednesday: {enabled: true, open: "09:00", close: "18:00", breaks: []},
  thursday: {enabled: true, open: "09:00", close: "18:00", breaks: []},
  friday: {enabled: true, open: "09:00", close: "18:00", breaks: []},
  saturday: {enabled: true, open: "09:00", close: "13:00", breaks: []},
  sunday: {enabled: false, open: "09:00", close: "18:00", breaks: []},
};

export function lockBucketIds(startAt: Date, endAt: Date): string[] {
  if (!(endAt.getTime() > startAt.getTime())) {
    throw new Error("INVALID_INTERVAL");
  }
  const ids: string[] = [];
  let cursor = Math.floor(startAt.getTime() / BUCKET_MS) * BUCKET_MS;
  while (cursor < endAt.getTime()) {
    ids.push(String(Math.floor(cursor / BUCKET_MS)).padStart(12, "0"));
    cursor += BUCKET_MS;
  }
  return ids;
}

export function openingDayFor(
  startAt: Date,
  config: StudioConfig,
): {localStart: DateTime; day: OpeningDay; timezone: string} {
  const timezone = config.timezone || "Europe/Rome";
  const localStart = DateTime.fromJSDate(startAt, {zone: "utc"}).setZone(timezone);
  const key = DAY_KEYS[localStart.weekday - 1];
  const hours = config.openingHours || defaultOpeningHours;
  return {
    localStart,
    day: hours[key] || defaultOpeningHours[key],
    timezone,
  };
}

function minuteOfDay(value: string): number {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) throw new Error("INVALID_OPENING_HOURS");
  return Number(match[1]) * 60 + Number(match[2]);
}

export function ensureWithinOpeningHours(
  startAt: Date,
  endWithBufferAt: Date,
  config: StudioConfig,
): void {
  const {localStart, day, timezone} = openingDayFor(startAt, config);
  const localEnd = DateTime.fromJSDate(endWithBufferAt, {zone: "utc"}).setZone(
    timezone,
  );
  if (!day.enabled || !localStart.hasSame(localEnd, "day")) {
    throw new Error("OUTSIDE_OPENING_HOURS");
  }
  const startMinute = localStart.hour * 60 + localStart.minute;
  const endMinute = localEnd.hour * 60 + localEnd.minute;
  if (startMinute < minuteOfDay(day.open) || endMinute > minuteOfDay(day.close)) {
    throw new Error("OUTSIDE_OPENING_HOURS");
  }
  for (const pause of day.breaks || []) {
    if (
      startMinute < minuteOfDay(pause.end) &&
      endMinute > minuteOfDay(pause.start)
    ) {
      throw new Error("OVERLAPS_BREAK");
    }
  }
}

export function lockReferences(
  db: Firestore,
  startAt: Date,
  endWithBufferAt: Date,
): DocumentReference[] {
  return lockBucketIds(startAt, endWithBufferAt).map((id) =>
    db.collection("appointmentLocks").doc(id),
  );
}

export async function acquireLocks(
  db: Firestore,
  transaction: Transaction,
  holderId: string,
  holderType: "appointment" | "block",
  startAt: Date,
  endWithBufferAt: Date,
): Promise<void> {
  const references = lockReferences(db, startAt, endWithBufferAt);
  const snapshots = await transaction.getAll(...references);
  for (const snapshot of snapshots) {
    const canReplaceSoftBlock = holderType === "appointment" &&
      snapshot.get("holderType") === "block";
    if (
      snapshot.exists &&
      snapshot.get("holderId") !== holderId &&
      !canReplaceSoftBlock
    ) {
      throw new Error("SLOT_UNAVAILABLE");
    }
  }
  references.forEach((reference, index) => {
    const bucketStart = new Date(
      Math.floor(startAt.getTime() / BUCKET_MS) * BUCKET_MS + index * BUCKET_MS,
    );
    transaction.set(reference, {
      holderId,
      holderType,
      bucketStartAt: Timestamp.fromDate(bucketStart),
      updatedAt: Timestamp.now(),
    });
  });
}

export async function releaseLocks(
  db: Firestore,
  transaction: Transaction,
  holderId: string,
  startAt: Date,
  endWithBufferAt: Date,
): Promise<void> {
  const references = lockReferences(db, startAt, endWithBufferAt);
  const snapshots = await transaction.getAll(...references);
  snapshots.forEach((snapshot) => {
    if (snapshot.exists && snapshot.get("holderId") === holderId) {
      transaction.delete(snapshot.ref);
    }
  });
}

export async function replaceLocks(
  db: Firestore,
  transaction: Transaction,
  holderId: string,
  oldStartAt: Date,
  oldEndAt: Date,
  newStartAt: Date,
  newEndAt: Date,
): Promise<void> {
  const oldReferences = lockReferences(db, oldStartAt, oldEndAt);
  const newReferences = lockReferences(db, newStartAt, newEndAt);
  const byPath = new Map(
    [...oldReferences, ...newReferences].map((reference) => [reference.path, reference]),
  );
  const references = [...byPath.values()];
  const snapshots = await transaction.getAll(...references);
  const snapshotsByPath = new Map(
    snapshots.map((snapshot) => [snapshot.ref.path, snapshot]),
  );
  const newPaths = new Set(newReferences.map((reference) => reference.path));
  for (const reference of newReferences) {
    const snapshot = snapshotsByPath.get(reference.path)!;
    if (
      snapshot.exists &&
      snapshot.get("holderId") !== holderId &&
      snapshot.get("holderType") !== "block"
    ) {
      throw new Error("SLOT_UNAVAILABLE");
    }
  }
  for (const reference of oldReferences) {
    const snapshot = snapshotsByPath.get(reference.path)!;
    if (
      !newPaths.has(reference.path) &&
      snapshot.exists &&
      snapshot.get("holderId") === holderId
    ) {
      transaction.delete(reference);
    }
  }
  for (const reference of newReferences) {
    const bucketIndex = Number(reference.id);
    transaction.set(reference, {
      holderId,
      holderType: "appointment",
      bucketStartAt: Timestamp.fromMillis(bucketIndex * BUCKET_MS),
      updatedAt: Timestamp.now(),
    });
  }
}

export function localDayBounds(
  date: string,
  timezone = "Europe/Rome",
): {start: DateTime; end: DateTime} {
  const start = DateTime.fromISO(date, {zone: timezone}).startOf("day");
  if (!start.isValid || start.toISODate() !== date) throw new Error("INVALID_DATE");
  return {start, end: start.plus({days: 1})};
}
