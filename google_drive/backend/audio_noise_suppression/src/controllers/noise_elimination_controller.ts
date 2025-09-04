// import { Request, Response } from "express";
// // import { RecordingModel } from "../models/recording_model";
// // import { NoiseEliminationService } from "../services/noise_elimination_service";
// // import { RecordingService } from "../services/recording_service";
// import { AudioProcessor } from "../services/noise_elimination_service";


// export class NoiseEliminationController {

//     //Process a recording (denoise it) and update DB with processed audio.
//     static async ioProcessRecording(req: any, res: Response) {
//         // console.log('🎤 Process recording endpoint hit');
//         // console.log('Request body:', req.body);
//         // console.log('Firebase user:', req.firebaseUser);

//         try {
//             const email = req.firebaseUser?.email;
//             const recordingId = req.body.recordingId;

//             if (!email || !recordingId) {
//                 return res.status(400).json({ success: false, message: "Email and recordingId are required" });
//             }

//             console.log('In noise elimination----->', recordingId);

//             // Get the recording from DB
//             // const recordingDoc = await RecordingService.getRecordingByEmailAndRecordingId(email, recordingId);

//             // if (!recordingDoc || !recordingDoc.recordings || recordingDoc.recordings.length === 0) {
//             //     return res.status(404).json({ success: false, message: "Recording not found" });
//             // }

//             // const audioData = recordingDoc.recordings[0].audioData;
//             // if (!audioData) {
//             //     return res.status(400).json({ success: false, message: "Recording has no audioData to process" });
//             // }

//             // // Run noise elimination
//             // const processedAudioBuffer = await NoiseEliminationService.process(audioData);

//             // if (processedAudioBuffer) {
//             //     // --- THE FIX ---
//             //     // Convert the Buffer to a Base64 string before sending it
//             //     const processedAudioBase64String = processedAudioBuffer.toString('base64');

//             //     // Now, pass the correctly typed string to your update function
//             //     await RecordingService.updateRecordingProcessedAudio(email, recordingId, processedAudioBase64String);
//             // }

//             // Update DB with processed audio
//             // await RecordingService.updateRecordingProcessedAudio(email, recordingId, processedAudio);


//             const audio = await AudioProcessor.processAudioWithRNNoise(email, recordingId);

//             return res.status(200).json({ success: true, message: 'Noise elimination successful' });
//         } catch (err: any) {
//             console.error("❌ Error in NoiseEliminationController.processRecording:", err);
//             if (!res.headersSent) {
//                 return res.status(500).json({
//                     success: false,
//                     message: 'Error processing recording',
//                     error: err.message,
//                 });
//             }
//         }
//     }

// }
