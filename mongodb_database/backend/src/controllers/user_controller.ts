import { Request, Response } from 'express';
import { IUser } from '../models/user_model';
import { UserService } from '../services/user_service';

export class UserController {

  static async ioCreateUser(req: Request, res: Response) {
    try {
      console.log("-------------in backend");
      const { userId, email, displayName, photoURL, token } = req.body;//In next version send it as user object.
      if (!email) return res.status(400).json({ success: false, message: 'Email is required' });

      const userData: IUser = {
        userId: userId,
        email: email
      };

      if (userId != null) userData.userId = userId;
      if (displayName != null) userData.displayName = displayName;
      if (photoURL != null) userData.photoURL = photoURL;
      if (token != null) userData.token = token;

      const result = await UserService.createUser(userData);

      res.json({ success: true, message: 'User created or updated', data: result });
    } catch (err) {
      console.error(err);
      res.status(500).json({ success: false, message: 'Error creating or updating user' });
    }
  }
}