import { Express } from 'express-serve-static-core';
import { verifyToken } from '../middleware/verify_token';
import { ioCheckAuth } from '../middleware/auth_middleware';
import { UserController } from '../controllers/user_controller';
import { RecordingController } from '../controllers/recording_controller';


export function configureRoutes(app: Express) {

  //User routes
  app.post('/api/user/create', verifyToken, UserController.ioCreateUser);

  // Recording routes
  app.post('/api/recordings/get', ioCheckAuth, RecordingController.iogetUserRecording);
  app.post('/api/recordings/create', ioCheckAuth, RecordingController.iocreateRecording);
  app.post('/api/recordings/delete', ioCheckAuth, RecordingController.iodeleteRecording);
  app.post('/api/recordings/delete_all', ioCheckAuth, RecordingController.iodeleteAllRecording);
  app.post('/api/recordings/update', ioCheckAuth, RecordingController.ioupdateRecording);
  app.post("/api/recordings/get_one", ioCheckAuth, RecordingController.iogetRecordingByEmailAndFileName);
}