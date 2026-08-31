import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {describe, expect, it} from "vitest";
import {acquireLocks} from "../src/schedule";

const emulatorEnabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

describe.skipIf(!emulatorEnabled)("concorrenza con Firestore Emulator", () => {
  it("una sola transazione può acquisire lo stesso slot", async () => {
    process.env.GCLOUD_PROJECT ||= "salon-booking-demo";
    if (getApps().length === 0) initializeApp({projectId: process.env.GCLOUD_PROJECT});
    const db = getFirestore();
    const locks = await db.collection("appointmentLocks").get();
    await Promise.all(locks.docs.map((document) => document.ref.delete()));
    const start = new Date("2026-09-01T08:00:00Z");
    const end = new Date("2026-09-01T08:45:00Z");
    const attempt = (id: string) =>
      db.runTransaction(async (transaction) => {
        await acquireLocks(db, transaction, id, "appointment", start, end);
      });
    const result = await Promise.allSettled([attempt("first"), attempt("second")]);
    expect(result.filter((item) => item.status === "fulfilled")).toHaveLength(1);
    expect(result.filter((item) => item.status === "rejected")).toHaveLength(1);
  });
});
