// firebase_service/firebase_admin.ts
import admin from 'firebase-admin';
import serviceAccount from '../firebase_service/firebase-service-account.json';  

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  });
}

export default admin;
  