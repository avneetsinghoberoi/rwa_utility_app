// Firebase Cloud Messaging Service Worker
// This file MUST be at the root of your web server (web/ folder in Flutter).
// It enables background push notifications in the browser.

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyADZVamGULEVlQyaa0b-hcvFqrvrbkUv0Q',
  appId: '1:1085944093717:web:ca6cafb339bb0a5e2d421c',
  messagingSenderId: '1085944093717',
  projectId: 'rms-app-3d585',
  authDomain: 'rms-app-3d585.firebaseapp.com',
  storageBucket: 'rms-app-3d585.firebasestorage.app',
  measurementId: 'G-88SK4X45J3',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title ?? 'GateBasic';
  const notificationOptions = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
