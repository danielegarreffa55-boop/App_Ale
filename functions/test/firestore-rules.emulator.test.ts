import {readFileSync} from "node:fs";
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, Timestamp} from "firebase/firestore";
import {afterAll, beforeAll, describe, expect, it} from "vitest";

const emulatorEnabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

describe.skipIf(!emulatorEnabled)("Firestore Security Rules", () => {
  let environment: RulesTestEnvironment;

  beforeAll(async () => {
    const [host, portText] = process.env.FIRESTORE_EMULATOR_HOST!.split(":");
    environment = await initializeTestEnvironment({
      projectId: process.env.GCLOUD_PROJECT || "salon-booking-demo",
      firestore: {
        host,
        port: Number(portText),
        rules: readFileSync("../firestore.rules", "utf8"),
      },
    });
    await environment.withSecurityRulesDisabled(async (context) => {
      const firestore = context.firestore();
      await setDoc(doc(firestore, "appointments/own"), {
        clientId: "client-1",
        status: "PENDING_ADMIN",
        createdAt: Timestamp.now(),
      });
      await setDoc(doc(firestore, "appointments/other"), {
        clientId: "client-2",
        status: "PENDING_ADMIN",
        createdAt: Timestamp.now(),
      });
      await setDoc(doc(firestore, "users/client-1"), {
        uid: "client-1",
        firstName: "Mario",
        isAdmin: false,
      });
    });
  });

  afterAll(async () => environment.cleanup());

  it("consente al cliente di leggere solo il proprio appuntamento", async () => {
    const firestore = environment.authenticatedContext("client-1").firestore();
    await assertSucceeds(getDoc(doc(firestore, "appointments/own")));
    await assertFails(getDoc(doc(firestore, "appointments/other")));
  });

  it("impedisce al client di scrivere CONFIRMED e di auto-promuoversi", async () => {
    const firestore = environment.authenticatedContext("client-1").firestore();
    await assertFails(
      setDoc(doc(firestore, "appointments/own"), {status: "CONFIRMED"}, {merge: true}),
    );
    await assertFails(
      setDoc(doc(firestore, "users/client-1"), {isAdmin: true}, {merge: true}),
    );
  });

  it("riconosce esclusivamente il custom claim admin", async () => {
    const firestore = environment
      .authenticatedContext("admin-1", {admin: true})
      .firestore();
    const result = await assertSucceeds(
      getDoc(doc(firestore, "appointments/other")),
    );
    expect(result.exists()).toBe(true);
  });
});
