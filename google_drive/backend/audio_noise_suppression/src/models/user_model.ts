import { randomUUID } from 'crypto';
import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
  userId: { type: String, default: () => randomUUID() },
  email: { type: String},
  displayName: { type: String },
  photoURL: { type: String },
  createdAt: { type: Date, default: new Date() },  //This is a constructor call (creating an instance of a Date object).
  lastLoginAt: { type: Date, default: Date.now },  //This is a static method of the Date class.
  token: { type: String },                         //Your theme highlights methods/functions differently from constructors.
});

userSchema.index({ userId: 1 }, { unique: true });
userSchema.index({ email: 1 }, { unique: true });

export const BaseModel = mongoose.model('User', userSchema);

export class UserModel {
  
  static async dbFindOne(email: string) {
    return BaseModel.findOne({ email: email }).lean();
  }

  static async dbFindOneAndUpdate(user: IUser) {
    if (user.email == null) return;
    if (!user.userId) user.userId = randomUUID();
  
    return BaseModel.findOneAndUpdate(
      { email: user.email },
      {
        $set: user,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    ).lean();
  }
}

export interface IUser {
  userId?: string;
  email?: string;
  displayName?: string;
  photoURL?: string ;
  createdAt?: Date;
  lastLoginAt?: Date;
  token?: string ;
}