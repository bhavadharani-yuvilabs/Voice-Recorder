import { Request, Response, NextFunction } from 'express';
import admin from '../firebase_service/firebase_admin';

export const verifyToken = async (req: any, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'No or malformed token provided' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.firebaseUser = decoded;
    req.user = decoded; // ✅ Add this line to set req.user
    next();
  } catch (err) {
    console.error('❌ Token verification failed:', err);
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
};