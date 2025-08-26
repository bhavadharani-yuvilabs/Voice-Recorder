import { Request, Response } from 'express';
import { RecordingService } from '../services/recording_service';
import { IRecording } from '../models/recording_model';

export class RecordingController {
  static async iogetUserRecording(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      if (!email) return res.status(401).json({ success: false, message: 'Authentication required' });

      const recordings = await RecordingService.getUserRecording(email);
      res.status(200).json(recordings);
    } catch (err) {
      console.error('❌ Error in getUserRecordings:', err);
      res.status(500).json({ success: false, message: 'Error fetching recordings' });
    }
  }

  static async iocreateRecording(req: any, res: Response) {
    try {
      const { fileName, audioData, duration, createdAt, fileSize } = req.body;
      const email = req.firebaseUser?.email;
      if (!email) {
        return res.status(401).json({ success: false, message: 'Authentication required' });
      }

      const recordingData: IRecording = {
        fileName: fileName,
        audioData,
        duration,
        createdAt,
        fileSize,
      };

      if (audioData != null) recordingData.audioData = audioData;
      if (duration != null) recordingData.duration = duration;
      if (fileSize != null) recordingData.fileSize = fileSize;


      const updatedUserDocument = await RecordingService.createRecording(email, recordingData);


      const newRecording = updatedUserDocument.recordings[updatedUserDocument.recordings.length - 1];
      res.status(201).json(newRecording);

    } catch (err) {
      console.error('❌ Error creating recording:', err);
      res.status(500).json({ success: false, message: 'Error creating recording' });
    }
  }

  static async iodeleteRecording(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { fileName } = req.body;

      if (!email) return res.status(401).json({ success: false, message: 'Authentication required' });
      if (!fileName) return res.status(401).json({ success: false, message: 'Authentication required' });
      
      const result = await RecordingService.deleteRecording(email, fileName);
      if (result.modifiedCount === 0) {
        return res.status(404).json({ success: false, message: 'Recording not found or user does not have permission' });
      }

      res.status(200).json({ success: true, message: 'Recording deleted' });
    } catch (err) {
      console.error('❌ Error deleting recording:', err);
      res.status(500).json({ success: false, message: 'Error deleting recording' });
    }
  }

  static async ioupdateRecording(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { fileName, newFileName } = req.body;

      if (!email) {
        return res.status(401).json({ success: false, message: 'Authentication required' });
      }

      const result = await RecordingService.updateRecording(email, fileName, newFileName);
      if (result.modifiedCount === 0) {
        return res.status(404).json({ success: false, message: 'Recording not found or user does not have permission' });
      }

      res.status(200).json({ success: true, message: 'Recording updated' });
    } catch (err) {
      console.error('❌ Error updating recording:', err);
      res.status(500).json({ success: false, message: 'Error updating recording' });
    }
  }

  static async iodeleteAllRecording(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      if (!email) {
        return res.status(401).json({ success: false, message: 'Authentication required' });
      }

      await RecordingService.deleteAllRecording(email);
      res.status(200).json({ success: true, message: 'All recordings deleted' });
    } catch (err) {
      console.error('❌ Error deleting all recordings:', err);
      res.status(500).json({ success: false, message: 'Error deleting all recordings' });
    }
  }

  static async iogetRecordingByEmailAndFileName(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { fileName } = req.body;
      if (!email || !fileName) {
        return res.status(400).json({ error: "email and fileName are required" });
      }

      await RecordingService.getRecordingByEmailAndFileName(email, fileName);

      res.status(200).json({ success: true, message: 'Recordings not found' });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

}