import { UserModel, IUser } from '../models/user_model';

//TODO: If there is no value for any attribute remove it from user object.
export class UserService {
  static async createUser(user: IUser) {
    const userObject: IUser = {
      userId: user.userId,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      createdAt: user.createdAt,
      lastLoginAt: user.lastLoginAt,
      token: user.token,
    };
    return await UserModel.dbFindOneAndUpdate(userObject);
  }
}