importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp(__FIREBASE_CONFIG__);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.info('FCM background message', message.messageId);
});
