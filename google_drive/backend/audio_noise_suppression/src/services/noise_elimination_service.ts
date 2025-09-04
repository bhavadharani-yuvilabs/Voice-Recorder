import path from 'path';
const fs = require('fs').promises; // Use promises for async file operations
import ffmpeg from 'fluent-ffmpeg';
import { WithImplicitCoercion } from 'buffer';
import { RecordingModel } from '../models/recording_model';

export class AudioProcessor {
    // WAV file parsing function
    static parseWavHeader(buffer: any) {
        const view = new DataView(buffer);

        if (view.getUint32(0, true) !== 0x46464952) {
            throw new Error('Invalid WAV file: missing RIFF header');
        }

        const sampleRate = view.getUint32(24, true);
        const numChannels = view.getUint16(22, true);
        const bitsPerSample = view.getUint16(34, true);

        let offset = 12;
        while (offset < buffer.byteLength - 8) {
            const chunkId = view.getUint32(offset, true);
            const chunkSize = view.getUint32(offset + 4, true);

            if (chunkId === 0x61746164) {
                return {
                    sampleRate,
                    numChannels,
                    bitsPerSample,
                    dataOffset: offset + 8,
                    dataSize: chunkSize
                };
            }
            offset += 8 + chunkSize;
        }

        throw new Error('Invalid WAV file: data chunk not found');
    }

    static convertToFloat32(buffer: any, header: { sampleRate?: number; numChannels?: number; bitsPerSample: any; dataOffset: any; dataSize: any; }) {
        const { dataOffset, dataSize, bitsPerSample } = header;

        if (bitsPerSample === 16) {
            const samples = new Int16Array(buffer, dataOffset, dataSize / 2);
            const float32 = new Float32Array(samples.length);
            for (let i = 0; i < samples.length; i++) {
                float32[i] = samples[i] / 32768;
            }
            return float32;
        } else {
            throw new Error(`Unsupported bit depth: ${bitsPerSample}`);
        }
    }

    static convertFromFloat32(samples: string | any[] | Float32Array<ArrayBuffer>, header: { sampleRate: any; numChannels: any; bitsPerSample: any; dataOffset?: number; dataSize?: number; }) {
        const { sampleRate, numChannels, bitsPerSample } = header;
        const bytesPerSample = bitsPerSample / 8;
        const dataSize = samples.length * bytesPerSample;

        const buffer = new ArrayBuffer(44 + dataSize);
        const view = new DataView(buffer);

        // WAV header
        view.setUint32(0, 0x46464952, true); // "RIFF"
        view.setUint32(4, 36 + dataSize, true);
        view.setUint32(8, 0x45564157, true); // "WAVE"
        view.setUint32(12, 0x20746d66, true); // "fmt "
        view.setUint32(16, 16, true);
        view.setUint16(20, 1, true); // PCM
        view.setUint16(22, numChannels, true);
        view.setUint32(24, sampleRate, true);
        view.setUint32(28, sampleRate * numChannels * bytesPerSample, true);
        view.setUint16(32, numChannels * bytesPerSample, true);
        view.setUint16(34, bitsPerSample, true);
        view.setUint32(36, 0x61746164, true); // "data"
        view.setUint32(40, dataSize, true);

        const int16Array = new Int16Array(buffer, 44, samples.length);
        for (let i = 0; i < samples.length; i++) {
            int16Array[i] = Math.max(-32768, Math.min(32767, samples[i] * 32768));
        }

        return buffer;
    }

    // Helper method to convert AAC to WAV using fluent-ffmpeg
    static async convertAACtoWAV(inputBase64: WithImplicitCoercion<string>) {
        const tempInputPath = path.join(__dirname, `temp_input_${Date.now()}.aac`);
        const tempOutputPath = path.join(__dirname, `temp_output_${Date.now()}.wav`);

        try {
            // Write base64 to temporary AAC file
            const inputBuffer = Buffer.from(inputBase64, 'base64');
            await fs.writeFile(tempInputPath, inputBuffer);

            // Convert AAC to WAV (mono, 16-bit, 48kHz for RNNoise)
            await new Promise((resolve, reject) => {
                ffmpeg(tempInputPath)
                    .audioChannels(1) // Mono
                    .audioBitrate('128k')
                    .audioFrequency(48000) // 48kHz for RNNoise
                    .format('wav')
                    .outputOptions('-c:a pcm_s16le') // 16-bit PCM
                    .output(tempOutputPath)
                    .on('end', resolve)
                    .on('error', reject)
                    .run();
            });

            // Read the converted WAV file
            const wavBuffer = await fs.readFile(tempOutputPath);
            return wavBuffer.buffer; // Return ArrayBuffer
        } finally {
            // Clean up temporary files
            await fs.unlink(tempInputPath).catch(() => { });
            await fs.unlink(tempOutputPath).catch(() => { });
        }
    }

    // Helper method to convert WAV to AAC using fluent-ffmpeg
    static async convertWAVtoAAC(inputBuffer: ArrayBuffer) {
        const tempInputPath = path.join(__dirname, `temp_wav_${Date.now()}.wav`);
        const tempOutputPath = path.join(__dirname, `temp_aac_${Date.now()}.aac`);

        try {
            // Write WAV buffer to temporary file
            await fs.writeFile(tempInputPath, Buffer.from(inputBuffer));

            // Convert WAV to AAC
            await new Promise((resolve, reject) => {
                ffmpeg(tempInputPath)
                    .audioBitrate('128k')
                    .audioCodec('aac') // Explicitly set AAC codec
                    .format('mp4') // Use mp4 container for AAC
                    .output(tempOutputPath)
                    .on('end', resolve)
                    .on('error', reject)
                    .run();
            });

            // Read the converted AAC file and convert to base64
            const aacBuffer = await fs.readFile(tempOutputPath);
            return aacBuffer.toString('base64');
        } finally {
            // Clean up temporary files
            await fs.unlink(tempInputPath).catch(() => { });
            await fs.unlink(tempOutputPath).catch(() => { });
        }
    }

    static async processAudioWithRNNoise(email: string, recordingId: string) {
        console.log('Processing audio with RNNoise for user:', email, 'Recording ID:', recordingId);

        try {
            // // Load the WASM module
            // console.log('Loading RNNoise WASM module...');
            // const wasmModulePath = `file://${path.resolve(__dirname, 'node_modules/@timephy/rnnoise-wasm/dist/generated/rnnoise-sync.js')}`;
            // const processorPath = `file://${path.resolve(__dirname, 'node_modules/@timephy/rnnoise-wasm/dist/RnnoiseProcessor.js')}`;

            // Load the WASM module
            console.log('Loading RNNoise WASM module...');
            const rootDir = process.cwd(); // Resolves to /app in Docker
            const wasmModulePath = path.join(rootDir, 'node_modules', '@timephy', 'rnnoise-wasm', 'dist', 'generated', 'rnnoise-sync.js');
            const processorPath = path.join(rootDir, 'node_modules', '@timephy', 'rnnoise-wasm', 'dist', 'RnnoiseProcessor.js');

            // Debug: Verify paths exist
            try {
                await fs.access(wasmModulePath);
                console.log('WASM module path exists:', wasmModulePath);
            } catch (e) {
                throw new Error(`WASM module not found at ${wasmModulePath}. Check installation and path.`);
            }
            try {
                await fs.access(processorPath);
                console.log('Processor path exists:', processorPath);
            } catch (e) {
                throw new Error(`Processor not found at ${processorPath}. Check installation and path.`);
            }

            // Set up global environment for WASM
            global.self = global as any;
            global.atob = require('util').TextDecoder ?
                (str) => Buffer.from(str, 'base64').toString('binary') :
                (str) => Buffer.from(str, 'base64').toString();

            // Load the WASM module using dynamic import with file URL
            const { default: createRNNoiseModule } = await import(wasmModulePath);
            const wasmModule = await createRNNoiseModule();

            console.log('WASM module loaded, creating RnnoiseProcessor...');

            // Load RnnoiseProcessor class using dynamic import with file URL
            const { default: RnnoiseProcessor } = await import(processorPath);
            const processor = new RnnoiseProcessor(wasmModule);

            console.log('RnnoiseProcessor created successfully');
            console.log(`Required sample length: ${processor.getSampleLength()}`);
            console.log(`Required PCM frequency: ${processor.getRequiredPCMFrequency()}`);

            // Load audio data from MongoDB
            console.log('Fetching audio data from MongoDB...');
            const audioDataBase64 = await RecordingModel.dbGetAudioDataByEmailAndRecordingId(email, recordingId);
            if (!audioDataBase64) {
                throw new Error('No audio data found for the given email and recording ID');
            }

            // Check if audio is WAV format
            let inputBuffer;
            try {
                inputBuffer = Buffer.from(audioDataBase64, 'base64').buffer;
                this.parseWavHeader(inputBuffer); // Try parsing to confirm WAV
                console.log('Audio is in WAV format');
            } catch (error) {
                console.log('Audio is not in WAV format, assuming AAC and converting to WAV...');
                inputBuffer = await this.convertAACtoWAV(audioDataBase64);
            }

            const header = this.parseWavHeader(inputBuffer);

            console.log(`Audio info - Sample rate: ${header.sampleRate}Hz, Channels: ${header.numChannels}, Bits: ${header.bitsPerSample}`);

            if (header.numChannels !== 1) {
                throw new Error('Only mono audio is supported');
            }

            if (header.sampleRate !== 48000) {
                console.warn('RNNoise works best with 48kHz audio, but proceeding with current sample rate');
            }

            // Convert to float32
            const audioData = this.convertToFloat32(inputBuffer, header);
            console.log(`Audio length: ${audioData.length} samples (${(audioData.length / header.sampleRate).toFixed(2)} seconds)`);

            // Process with RNNoise
            console.log('Processing with RNNoise...');
            const frameSize = 480; // RNNoise requires exactly 480 samples
            const numFrames = Math.floor(audioData.length / frameSize);
            const processedData = new Float32Array(numFrames * frameSize);

            let totalVAD = 0;
            let frameCount = 0;

            for (let i = 0; i < numFrames; i++) {
                const frameStart = i * frameSize;
                const frame = audioData.slice(frameStart, frameStart + frameSize);

                // Process frame through RNNoise (modifies frame in-place)
                const vadScore = processor.processAudioFrame(frame, true); // true = denoise
                totalVAD += vadScore;
                frameCount++;

                // Copy processed frame to output
                processedData.set(frame, frameStart);
            }

            console.log(`Average VAD score: ${(totalVAD / frameCount).toFixed(3)} (higher = more voice detected)`);

            // Convert processed audio back to WAV buffer
            const rnnOutputBuffer = this.convertFromFloat32(processedData, header);

            // Convert WAV to AAC
            console.log('Converting processed WAV to AAC...');
            const processedAudioBase64 = await this.convertWAVtoAAC(rnnOutputBuffer);

            // Update MongoDB with processed audio
            console.log('Updating processed audio in MongoDB...');
            await RecordingModel.dbUpdateRecordingProcessedAudio(email, recordingId, processedAudioBase64);
            console.log('Processed audio saved to MongoDB successfully');

            // Calculate metrics
            const originalRMS = Math.sqrt(audioData.reduce((sum, sample) => sum + sample * sample, 0) / audioData.length);
            const rnnoiseRMS = Math.sqrt(processedData.reduce((sum, sample) => sum + sample * sample, 0) / processedData.length);

            console.log('\n=== RESULTS ===');
            console.log(`Original RMS: ${originalRMS.toFixed(4)}`);
            console.log(`RNNoise RMS: ${rnnoiseRMS.toFixed(4)} (${((originalRMS - rnnoiseRMS) / originalRMS * 100).toFixed(1)}% reduction)`);

            // // Cleanup
            // processor.destroy();
            // console.log('\nRNNoise processor destroyed. Processing completed successfully!');

            try {
                console.log('Attempting to destroy RNNoise processor...');
                processor.destroy();
                console.log('RNNoise processor destroyed successfully');
            } catch (destroyError) {
                console.warn('Failed to destroy RNNoise processor:', destroyError.message);
            }

            return processedAudioBase64;

        } catch (error) {
            console.error('Error processing audio with RNNoise:', error.message);
            console.error('Stack trace:', error.stack);
            throw error; // Rethrow to allow caller to handle
        }
    }
}

// Example usage
// AudioProcessor.processAudioWithRNNoise('user@example.com', 'recording123').catch(console.error);