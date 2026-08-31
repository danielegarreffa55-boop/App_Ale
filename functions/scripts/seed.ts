import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {defaultOpeningHours} from "../src/schedule";

const demoPassword = "DemoOnly-ChangeMe-123!";

async function upsertUser(email: string, displayName: string) {
  const auth = getAuth();
  try {
    return await auth.getUserByEmail(email);
  } catch {
    return auth.createUser({email, password: demoPassword, displayName, emailVerified: true});
  }
}

async function main(): Promise<void> {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error("Seed bloccato: avvia prima gli emulatori Firebase.");
  }
  process.env.GCLOUD_PROJECT ||= "salon-booking-demo";
  if (getApps().length === 0) initializeApp({projectId: process.env.GCLOUD_PROJECT});
  const [admin, client] = await Promise.all([
    upsertUser("admin@demo.local", "Admin Demo"),
    upsertUser("cliente@demo.local", "Cliente Demo"),
  ]);
  await getAuth().setCustomUserClaims(admin.uid, {admin: true});
  const db = getFirestore();
  const batch = db.batch();
  batch.set(db.collection("users").doc(admin.uid), {
    uid: admin.uid,
    firstName: "Admin",
    lastName: "Demo",
    email: admin.email,
    phone: "+390000000001",
    isAdmin: true,
    notificationEnabled: false,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  batch.set(db.collection("users").doc(client.uid), {
    uid: client.uid,
    firstName: "Cliente",
    lastName: "Demo",
    email: client.email,
    phone: "+390000000002",
    isAdmin: false,
    notificationEnabled: false,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  [
    ["taglio", "Taglio", 30, 5, 3000],
    ["taglio-barba", "Taglio + Barba", 45, 5, 4500],
    ["colore", "Colore", 90, 10, 7500],
  ].forEach(([id, name, duration, buffer, price], index) => {
    batch.set(db.collection("services").doc(String(id)), {
      name,
      description: "Servizio demo modificabile dall'area admin",
      durationMinutes: duration,
      bufferMinutes: buffer,
      priceCents: price,
      active: true,
      displayOrder: index,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
  batch.set(db.collection("studio").doc("config"), {
    studioName: "Atelier Studio",
    timezone: "Europe/Rome",
    currency: "EUR",
    reminderTime: "18:00",
    openingHours: defaultOpeningHours,
    updatedAt: Timestamp.now(),
  });
  await batch.commit();
  console.log("Seed emulatori completato.");
  console.log(`Admin: admin@demo.local / ${demoPassword}`);
  console.log(`Cliente: cliente@demo.local / ${demoPassword}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
