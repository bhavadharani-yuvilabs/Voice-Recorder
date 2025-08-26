import { IRecording, RecordingModel } from '../models/recording_model';

export class RecordingService {

  static async getUserRecording(email: string) {
    return RecordingModel.dbGetUserRecording(email);
  }

  static async createRecording(email: string, userRecording: IRecording) {
    return RecordingModel.dbCreateRecording(email, userRecording);
  }

  static async deleteRecording(email: string, fileName: string) {
    return RecordingModel.dbDeleteRecording(email, fileName);
  }

  static async deleteAllRecording(email: string) {
    return RecordingModel.dbDeleteAllRecording(email);
  }

  static async updateRecording(email: string, fileName: string, newFileName: String) {
    return RecordingModel.dbUpdateRecording(email, fileName, newFileName);
  }

  static async getRecordingByEmailAndFileName(email: string, fileName: string) {
    return RecordingModel.dbGetRecordingByEmailAndFileName(email, fileName);
  }

}