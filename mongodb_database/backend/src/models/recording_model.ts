import mongoose, { Schema, Types } from 'mongoose';

const userRecordingsSchema = new Schema({
  email: String,
  recordings: [
    {
      fileName: String,
      audioData: String,
      duration: Number,
      createdAt: { type: Date, default: Date.now },
      fileSize: Number,
      _id: false,
    }
  ],
});


export const BaseModel = mongoose.model('UserRecording', userRecordingsSchema, 'user-recordings');


export class RecordingModel {

  static async dbGetUserRecording(email: string) {//In next version, instead of sending user email send user itself.
    const userDoc = await BaseModel.findOne({ email: email }).lean();
    return userDoc ? userDoc.recordings : [];
  }

  static async dbGetRecordingByEmailAndFileName(email: string, fileName: string) {
    return await BaseModel.findOne({ email: email, fileName: fileName }).lean();
  }

  static async dbCreateRecording(email: string, userRecording: IRecording) {
    if (!userRecording.createdAt) userRecording.createdAt = new Date();

    return await BaseModel.findOneAndUpdate(
      { email: email },
      { $push: { recordings: userRecording } },
      { new: true, upsert: true }
    ).lean();
  }

  static async dbDeleteRecording(email: string, fileName: string) {
    return await BaseModel.updateOne(
      {
        email: email,
        "recordings.fileName": fileName
      },
      { $pull: { recordings: { fileName: fileName } } }
    ).lean();
  }

  static async dbDeleteAllRecording(email: string) {
    return await BaseModel.updateOne(
      { email: email },
      { $set: { recordings: [] } }
    ).lean();
  }

  static async dbUpdateRecording(email: string, fileName: string, newFileName: String) {
    return await BaseModel.updateOne(
      {
        email: email,
        "recordings.fileName": fileName
      },
      { $set: { "recordings.$.fileName": newFileName } }
    ).lean();
  }

}

export interface IRecording {
  fileName?: string;
  audioData?: string;
  duration?: number;
  createdAt?: Date;
  fileSize?: number;
}

export interface IUserRecordings {
  email: string;
  recordings: IRecording[];
}