// Webcam face tracking in the browser with MediaPipe Face Landmarker.
// Each result has a timestamp (ms since start()), 478 landmarks, and the same
// 52 ARKit blend shape names the avatar uses, so you can compare the kid's
// jawOpen directly with the avatar's jawOpen, or drive a "mirror" avatar.
import { FaceLandmarker, FilesetResolver } from '@mediapipe/tasks-vision';

const WASM = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm';
const MODEL =
  'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task';

export class FaceTracker {
  async init(video) {
    this.video = video;
    const files = await FilesetResolver.forVisionTasks(WASM);
    this.landmarker = await FaceLandmarker.createFromOptions(files, {
      baseOptions: { modelAssetPath: MODEL, delegate: 'GPU' },
      runningMode: 'VIDEO',
      numFaces: 1,
      outputFaceBlendshapes: true,
    });
    const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false });
    video.srcObject = stream;
    await video.play();
  }

  // Start a recording window. Pass the same t0 you use when you start the
  // microphone, so Azure's phoneme offsets line up with these frames.
  start(onFrame, t0 = performance.now()) {
    this.t0 = t0;
    this.frames = [];
    this.running = true;
    const loop = () => {
      if (!this.running) return;
      const now = performance.now();
      const r = this.landmarker.detectForVideo(this.video, now);
      if (r.faceLandmarks.length) {
        const blend = {};
        for (const c of r.faceBlendshapes[0].categories) blend[c.categoryName] = c.score;
        const frame = { t: now - this.t0, landmarks: r.faceLandmarks[0], blend };
        this.frames.push(frame);
        onFrame?.(frame);
      }
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  stop() {
    this.running = false;
    return this.frames;
  }

  // Frames inside one phoneme's window, from Azure's offset and duration (ms).
  window(startMs, durationMs, marginMs = 40) {
    return this.frames.filter((f) => f.t >= startMs - marginMs && f.t <= startMs + durationMs + marginMs);
  }
}
