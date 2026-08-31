import {applicationDefault, getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

async function main(): Promise<void> {
  const email = process.argv[2]?.trim().toLowerCase();
  if (!email) {
    throw new Error("Uso: npm run set-admin -- amministratore@example.it");
  }
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault()});
  }
  const user = await getAuth().getUserByEmail(email);
  await getAuth().setCustomUserClaims(user.uid, {
    ...(user.customClaims || {}),
    admin: true,
  });
  await getFirestore().collection("users").doc(user.uid).set(
    {isAdmin: true, adminGrantedAt: Timestamp.now()},
    {merge: true},
  );
  console.log(`Ruolo ADMIN assegnato a ${email} (${user.uid}).`);
  console.log("L'utente deve uscire e rientrare per aggiornare il token.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
