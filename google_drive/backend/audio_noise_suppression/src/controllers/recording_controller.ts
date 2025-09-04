import { Request, Response } from 'express';
import { RecordingService } from '../services/recording_service';
import { IRecording, RecordingModel } from '../models/recording_model';
import { AudioProcessor } from '../services/noise_elimination_service';
// const { AudioProcessor } = require('../noise_elimination');

export class RecordingController {

  static async ioGetUserRecording(req: any, res: Response) {
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

  static async ioCreateRecording(req: any, res: Response) {
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

  static async ioDeleteRecording(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { recordingId } = req.body;

      if (!email) return res.status(401).json({ success: false, message: 'Authentication required' });
      if (!recordingId) return res.status(401).json({ success: false, message: 'Authentication required' });

      const result = await RecordingService.deleteRecording(email, recordingId);
      if (result.modifiedCount === 0) {
        return res.status(404).json({ success: false, message: 'Recording not found or user does not have permission' });
      }

      res.status(200).json({ success: true, message: 'Recording deleted' });
    } catch (err) {
      console.error('❌ Error deleting recording:', err);
      res.status(500).json({ success: false, message: 'Error deleting recording' });
    }
  }

  static async ioUpdateRecordingFileName(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { recordingId, newFileName } = req.body;

      if (!email) {
        return res.status(401).json({ success: false, message: 'Authentication required' });
      }

      const result = await RecordingService.updateRecordingFileName(email, recordingId, newFileName);
      if (result.modifiedCount === 0) {
        return res.status(404).json({ success: false, message: 'Recording not found or user does not have permission' });
      }

      res.status(200).json({ success: true, message: 'Recording updated' });
    } catch (err) {
      console.error('❌ Error updating recording:', err);
      res.status(500).json({ success: false, message: 'Error updating recording' });
    }
  }

  static async ioDeleteAllRecording(req: any, res: Response) {
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

  static async ioGetRecordingByEmailAndRecordingId(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { recordingId } = req.body;
      if (!email || !recordingId) {
        return res.status(400).json({ error: "email and recordingId are required" });
      }

      // Audio noise elimination (wait for processing to complete)
      // await AudioProcessor.processAudioWithRNNoise(email, recordingId);

      const recording = await RecordingService.getRecordingByEmailAndRecordingId(email, recordingId);
      if (!recording) {
        return res.status(404).json({ success: false, message: 'Recording not found' });
      }

      res.status(200).json(recording);
    } catch (error: any) {
      console.error('❌ Error in ioGetRecordingByEmailAndRecordingId:', error.message);
      res.status(500).json({ error: error.message });
    }
  }

  // ADD these new methods to your existing RecordingController class:
  static async ioUpdateRecordingDriveInfo(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { recordingId, driveFileId, status } = req.body;

      if (!email || !recordingId || !driveFileId) {
        return res.status(400).json({ success: false, message: 'Missing required fields' });
      }

      const result = await RecordingService.updateRecordingDriveFileId(email, recordingId, driveFileId, status);
      if (result.modifiedCount === 0) {
        return res.status(404).json({ success: false, message: 'Recording not found' });
      }

      res.status(200).json({ success: true, message: 'Recording updated with Drive info' });
    } catch (err) {
      console.error('❌ Error updating recording Drive info:', err);
      res.status(500).json({ success: false, message: 'Error updating recording' });
    }
  }

  static async ioProcessAndPrepareForDrive(req: any, res: Response) {
    try {
      const { recordingId } = req.body;
      const email = req.firebaseUser?.email;

      if (!email || !recordingId) {
        return res.status(400).json({ error: "email and recordingId are required" });
      }

      // Update status to processing
      await RecordingService.updateRecordingStatus(email, recordingId, 'processing');

      // Get audio data for processing
      const audioData = await RecordingService.getAudioDataByEmailAndRecordingId(email, recordingId);
      if (!audioData) {
        return res.status(404).json({ error: 'Recording not found or no audio data' });
      }

      // TODO: Uncomment when you implement noise cancellation
      const processedAudio = await AudioProcessor.processAudioWithRNNoise(email, recordingId);
      if(!processedAudio){
        console.log('--------null processed audio');
        // processedAudio = audioData;

      }

      // For now, use original audio as processed (remove this when implementing noise cancellation)
      // const processedAudio = audioData;

      // Update with processed audio
      // await RecordingService.updateRecordingProcessedAudio(email, recordingId, processedAudio);
      await RecordingService.updateRecordingStatus(email, recordingId, 'processed');

      // Get the updated recording info
      const recording = await RecordingService.getRecordingByEmailAndRecordingId(email, recordingId);

      res.status(200).json({
        success: true,
        processedAudio: processedAudio,
        recordingId: recordingId,
        metadata: recording?.recordings?.[0] || {}
      });

    } catch (error: any) {
      console.error('❌ Error in ioProcessAndPrepareForDrive:', error.message);
      res.status(500).json({ error: error.message });
    }
  }

  static async ioIncrementDownloadCount(req: any, res: Response) {
    try {
      const email = req.firebaseUser?.email;
      const { recordingId } = req.body;

      if (!email || !recordingId) {
        return res.status(400).json({ success: false, message: 'Missing required fields' });
      }

      const result = await RecordingService.incrementDownloadCount(email, recordingId);
      if (result.modifiedCount === 0) {
        return res.status(404).json({ success: false, message: 'Recording not found' });
      }

      res.status(200).json({ success: true, message: 'Download count incremented' });
    } catch (err) {
      console.error('❌ Error incrementing download count:', err);
      res.status(500).json({ success: false, message: 'Error incrementing download count' });
    }
  }

}