import {readFile, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';

const configPath = resolve(process.argv[2] || 'config/dev.json');
const config = JSON.parse(await readFile(configPath, 'utf8'));
const firebaseConfig = {
  apiKey: config.FIREBASE_API_KEY,
  authDomain: config.FIREBASE_AUTH_DOMAIN,
  projectId: config.FIREBASE_PROJECT_ID,
  storageBucket: config.FIREBASE_STORAGE_BUCKET,
  messagingSenderId: config.FIREBASE_MESSAGING_SENDER_ID,
  appId: config.FIREBASE_APP_ID_WEB,
  measurementId: config.FIREBASE_MEASUREMENT_ID,
};
for (const key of ['apiKey', 'projectId', 'messagingSenderId', 'appId']) {
  if (!firebaseConfig[key]) throw new Error(`Configurazione Firebase mancante: ${key}`);
}
const template = await readFile(
  resolve('web/firebase-messaging-sw.template.js'),
  'utf8',
);
await writeFile(
  resolve('web/firebase-messaging-sw.js'),
  template.replace('__FIREBASE_CONFIG__', JSON.stringify(firebaseConfig, null, 2)),
  'utf8',
);
console.log('web/firebase-messaging-sw.js generato.');
