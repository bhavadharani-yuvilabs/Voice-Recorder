import { Express } from 'express-serve-static-core';
import { verifyToken } from '../middleware/verify_token';
import { ioCheckAuth } from '../middleware/auth_middleware';
import { UserController } from '../controllers/user_controller';
import { RecordingController } from '../controllers/recording_controller';
// import { NoiseEliminationController } from '../controllers/noise_elimination_controller';


export function configureRoutes(app: Express) {

  //User routes
  app.post('/api/user/create', verifyToken, UserController.ioCreateUser);

  //Recording routes
  app.post('/api/recordings/get', ioCheckAuth, RecordingController.ioGetUserRecording);
  app.post('/api/recordings/create', ioCheckAuth, RecordingController.ioCreateRecording);
  app.post('/api/recordings/delete', ioCheckAuth, RecordingController.ioDeleteRecording);
  app.post('/api/recordings/delete_all', ioCheckAuth, RecordingController.ioDeleteAllRecording);
  app.post('/api/recordings/update', ioCheckAuth, RecordingController.ioUpdateRecordingFileName);
  app.post("/api/recordings/get_one", ioCheckAuth, RecordingController.ioGetRecordingByEmailAndRecordingId);


  //Process audio routes
  // app.post('/api/recordings/process', ioCheckAuth, NoiseEliminationController.ioProcessRecording);


  // Google Drive 
  // Prepare processed audio for Drive upload (returns processedAudio to app)
  app.post('/api/recordings/prepare_for_drive', ioCheckAuth, RecordingController.ioProcessAndPrepareForDrive);

  // Update Drive info after app upload
  app.post('/api/recordings/update_drive', ioCheckAuth, RecordingController.ioUpdateRecordingDriveInfo);

  // Increment download count after download
  app.post('/api/recordings/increment_download', ioCheckAuth, RecordingController.ioIncrementDownloadCount);
}