import { IRecording, RecordingModel } from '../models/recording_model';
// import ffmpeg from 'fluent-ffmpeg';

// Import the native RNNoise package for Node.js
// import * as rnnoise from 'rnnoise';

// import * as fs from 'fs/promises';
// import * as path from 'path'

export class RecordingService {
  static async getAudioDataByEmailAndRecordingId(email: string, recordingId: string): Promise<string> {
    return RecordingModel.dbGetAudioDataByEmailAndRecordingId(email, recordingId);
  }

  static async getUserRecording(email: string) {
    return RecordingModel.dbGetUserRecording(email);
  }

  static async createRecording(email: string, userRecording: IRecording) {
    return RecordingModel.dbCreateRecording(email, userRecording);
  }

  static async deleteRecording(email: string, recordingId: string) {
    return RecordingModel.dbDeleteRecording(email, recordingId);
  }

  static async deleteAllRecording(email: string) {
    return RecordingModel.dbDeleteAllRecording(email);
  }

  static async updateRecordingFileName(email: string, recordingId: string, newFileName: String) {
    return RecordingModel.dbUpdateRecordingFileName(email, recordingId, newFileName);
  }

  static async updateRecordingProcessedAudio(email: string, recordingId: string, processedAudio: string) {
    return RecordingModel.dbUpdateRecordingProcessedAudio(email, recordingId, processedAudio);
  }

  static async getRecordingByEmailAndRecordingId(email: string, recordingId: string) {
    return RecordingModel.dbGetRecordingByEmailAndRecordingId(email, recordingId);
  }

  // ADD these new methods to your existing RecordingService class:
  static async updateRecordingDriveFileId(email: string, recordingId: string, driveFileId: string, status: string) {
    return RecordingModel.dbUpdateRecordingDriveFileId(email, recordingId, driveFileId, status);
  }

  static async updateRecordingStatus(email: string, recordingId: string, status: string) {
    return RecordingModel.dbUpdateRecordingStatus(email, recordingId, status);
  }

  static async incrementDownloadCount(email: string, recordingId: string) {
    return RecordingModel.dbIncrementDownloadCount(email, recordingId);
  }



}