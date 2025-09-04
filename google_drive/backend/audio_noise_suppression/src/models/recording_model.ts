import mongoose, { Schema, Types } from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

const userRecordingsSchema = new Schema({
  email: String,
  recordings: [
    {
      recordingId: { type: String, default: uuidv4 }, // Random UUID
      fileName: String,
      audioData: String,
      processedAudio: String, // New field for processed

      // ADD THESE NEW FIELDS:
      driveFileId: String,        // Google Drive file ID
      status: { type: String, default: 'raw' }, // New: e.g., 'raw', 'processing', 'processed', 'uploaded'
      downloadCount: { type: Number, default: 0 },

      // EXISTING FIELDS:
      duration: Number,
      createdAt: { type: Date, default: Date.now },
      fileSize: Number,
      _id: false,
    }
  ],
});


export const BaseModel = mongoose.model('UserRecording', userRecordingsSchema);


export class RecordingModel {

  static async dbGetUserRecording(email: string) {//In next version, instead of sending user email send user itself.
    const userDoc = await BaseModel.findOne({ email: email }).lean();
    return userDoc ? userDoc.recordings : [];
  }

  static async dbGetRecordingByEmailAndRecordingId(email: string, recordingId: string) {
    const userDoc = await BaseModel.findOne(
      {
        email: email,
        'recordings.recordingId': recordingId
      },
      { 'recordings.$': 1 } // Return only the matching recording
    ).lean();

    return userDoc;
  }


  static async dbGetAudioDataByEmailAndRecordingId(email: string, recordingId: string): Promise<string> {
    const userDoc = await BaseModel.findOne(
      {
        email: email,
        'recordings.recordingId': recordingId
      },
      { 'recordings.$': 1 }
    ).lean();

    if (
      !userDoc ||
      !userDoc.recordings ||
      userDoc.recordings.length === 0 ||
      !userDoc.recordings[0]
    ) {
      return "";
    }

    const rec = userDoc.recordings[0];
    if (!rec || !rec.audioData) {
      return "";
    }

    return rec.audioData;
  }

  static async dbCreateRecording(email: string, userRecording: IRecording) {
    if (!userRecording.createdAt) userRecording.createdAt = new Date();

    return await BaseModel.findOneAndUpdate(
      { email: email },
      { $push: { recordings: userRecording } },
      { new: true, upsert: true }
    ).lean();
  }

  static async dbDeleteRecording(email: string, recordingId: string) {
    return await BaseModel.updateOne(
      {
        email: email,
        "recordings.recordingId": recordingId
      },
      { $pull: { recordings: { recordingId: recordingId } } }
    ).lean();
  }

  static async dbDeleteAllRecording(email: string) {
    return await BaseModel.updateOne(
      { email: email },
      { $set: { recordings: [] } }
    ).lean();
  }

  static async dbUpdateRecordingFileName(email: string, recordingId: string, newFileName: String) {
    return await BaseModel.updateOne(
      {
        email: email,
        "recordings.recordingId": recordingId
      },
      { $set: { "recordings.$.fileName": newFileName } }
    ).lean();
  }

  static async dbUpdateRecordingProcessedAudio(email: string, recordingId: string, processedAudio: String) {
    return await BaseModel.updateOne(
      {
        email: email,
        "recordings.recordingId": recordingId
      },
      { $set: { "recordings.$.processedAudio": processedAudio } }
    ).lean();
  }

  //new drive methods
  static async dbUpdateRecordingDriveFileId(email: string, recordingId: string, driveFileId: string, status: string) {
  return await BaseModel.updateOne(
    { email, "recordings.recordingId": recordingId },
    { $set: { "recordings.$.driveFileId": driveFileId, "recordings.$.status": status } }
  ).lean();
}

static async dbUpdateRecordingStatus(email: string, recordingId: string, status: string) {
  return await BaseModel.updateOne(
    { email, "recordings.recordingId": recordingId },
    { $set: { "recordings.$.status": status } }
  ).lean();
}

static async dbIncrementDownloadCount(email: string, recordingId: string) {
  return await BaseModel.updateOne(
    { email, "recordings.recordingId": recordingId },
    { $inc: { "recordings.$.downloadCount": 1 } }
  ).lean();
}

}

export interface IRecording {
  recordingId?: string;
  fileName?: string;
  audioData?: string;
  processedAudio?: string;
  duration?: number;
  createdAt?: Date;
  fileSize?: number;
  driveFileId?: string; // New
  status?: string; // New
  downloadCount?: number; // New
}

export interface IUserRecordings {
  email: string;
  recordings: IRecording[];
}