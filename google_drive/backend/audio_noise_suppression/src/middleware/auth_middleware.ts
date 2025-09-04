import { Request, Response, NextFunction } from 'express';
import { verifyToken } from './verify_token';
import { UserModel } from '../models/user_model';
import { UserService } from '../services/user_service';

export async function ioCheckAuth(req: Request, res: Response, next: NextFunction) {
  await verifyToken(req, res, async () => {
    const firebaseUser = (req as any).firebaseUser;//In next version send firebaseUser in body instead of outside body.
    console.log('✅ Firebase User:', firebaseUser);
    const firebaseEmail = firebaseUser.email;

    let user = await UserModel.dbFindOne(firebaseEmail);

    if (!user) {
      try {
        user = await UserService.createUser(firebaseUser);
      } catch (err) {
        console.error('❌ Error creating user from token:', err);
        return res.status(500).json({ success: false, message: 'Failed to create user' });
      }
    }

    if (!req.body) req.body = {}; // ← add this

    req.body.currentUser = user;

    next();
  });
}


