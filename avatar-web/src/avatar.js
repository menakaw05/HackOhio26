// three.js controller for an Avaturn T2 avatar (or any GLB with ARKit blend shapes).
// Handles: loading, name mapping, audio-synced playback of Azure blend shape
// frames, per-channel exaggeration ("boost"), holding a pose, and X-ray mode.
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

// Order of Azure's 55 facial positions (the "3D blend shapes" table in
// Azure's viseme docs; checked name by name on 2026-10-24, all 55 match).
// The first 52 are ARKit names; the last 3 are head/eye rotations we ignore.
export const AZURE_BLENDSHAPES = [
  'eyeBlinkLeft', 'eyeLookDownLeft', 'eyeLookInLeft', 'eyeLookOutLeft', 'eyeLookUpLeft',
  'eyeSquintLeft', 'eyeWideLeft', 'eyeBlinkRight', 'eyeLookDownRight', 'eyeLookInRight',
  'eyeLookOutRight', 'eyeLookUpRight', 'eyeSquintRight', 'eyeWideRight', 'jawForward',
  'jawLeft', 'jawRight', 'jawOpen', 'mouthClose', 'mouthFunnel', 'mouthPucker', 'mouthLeft',
  'mouthRight', 'mouthSmileLeft', 'mouthSmileRight', 'mouthFrownLeft', 'mouthFrownRight',
  'mouthDimpleLeft', 'mouthDimpleRight', 'mouthStretchLeft', 'mouthStretchRight',
  'mouthRollLower', 'mouthRollUpper', 'mouthShrugLower', 'mouthShrugUpper', 'mouthPressLeft',
  'mouthPressRight', 'mouthLowerDownLeft', 'mouthLowerDownRight', 'mouthUpperUpLeft',
  'mouthUpperUpRight', 'browDownLeft', 'browDownRight', 'browInnerUp', 'browOuterUpLeft',
  'browOuterUpRight', 'cheekPuff', 'cheekSquintLeft', 'cheekSquintRight', 'noseSneerLeft',
  'noseSneerRight', 'tongueOut', 'headRoll', 'leftEyeRoll', 'rightEyeRoll',
];
const ARKIT_COUNT = 52;

// "JawOpen", "jaw_open", "jawOpen" all map to "jawopen".
const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');

// Azure viseme IDs we sharpen (see the viseme table in Azure's docs).
export const SILENCE = 0;
export const BILABIAL = 21; // p, b, m
const RAMP = 0.06; // s, eases seal/rest in and out so the face doesn't snap
// Shapes that part the lips; removed while sealing p/b/m.
const LIP_PARTING = ['mouthLowerDownLeft', 'mouthLowerDownRight', 'mouthUpperUpLeft', 'mouthUpperUpRight', 'mouthFunnel'];

// How much viseme `id` is active at time t (0-1), ramped at its edges.
// Time before the first viseme counts as silence.
function visemeWeight(visemes, id, t) {
  let w = id === SILENCE && visemes.length && t < visemes[0].time ? 1 : 0;
  for (let i = 0; i < visemes.length; i++) {
    if (visemes[i].id !== id) continue;
    const start = visemes[i].time;
    const end = visemes[i + 1]?.time ?? Infinity;
    w = Math.max(w, Math.min(1, Math.max(0, Math.min((t - start) / RAMP + 0.5, (end - t) / RAMP + 0.5))));
  }
  return w;
}

export class Avatar {
  constructor(canvas) {
    this.canvas = canvas;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    this.renderer.setPixelRatio(1); // keep the GPU free for face tracking
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(25, 1, 0.01, 100);
    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x445566, 2.2));
    const key = new THREE.DirectionalLight(0xffffff, 1.6);
    key.position.set(1, 2, 2);
    this.scene.add(key);

    this.targets = new Map(); // normalized name -> [{ mesh, index }]
    this.anim = null;         // current playback state
    this.boost = null;        // { gains: { jawOpen: 1.4 }, start, end } in seconds
    this.xray = false;
    this.frame = { x: 0, y: 0, w: 1, h: 1 }; // where the avatar is drawn, see setFrame()

    new ResizeObserver(() => this.resize()).observe(canvas);
    this.resize();
    this.renderer.setAnimationLoop(() => this.tick());
  }

  // Draw the avatar in part of the canvas: fractions (0-1) from the top left.
  // The rest stays transparent. This is how Flutter moves or shrinks the
  // avatar over the camera without animating the WebView itself.
  setFrame({ x = 0, y = 0, w = 1, h = 1 } = {}) {
    this.frame = { x, y, w, h };
    this.resize();
  }

  resize() {
    const cw = this.canvas.clientWidth || 1;
    const ch = this.canvas.clientHeight || 1;
    this.renderer.setSize(cw, ch, false);
    const { x, y, w, h } = this.frame;
    this.viewport = [x * cw, (1 - y - h) * ch, w * cw, h * ch]; // WebGL counts y from the bottom
    const aspect = (w * cw) / (h * ch);
    this.camera.aspect = aspect;
    // Tall, narrow frames: widen the view so head and shoulders still fit
    // (25° vertical is tuned for 4:3 and wider; below 3:4 the face fills it).
    const t = Math.tan(THREE.MathUtils.degToRad(12.5));
    this.camera.fov = aspect >= 0.75 ? 25 : THREE.MathUtils.radToDeg(2 * Math.atan((t * 0.75) / aspect));
    this.camera.updateProjectionMatrix();
  }

  // Load a GLB. Returns which ARKit channels the avatar is missing, so you
  // can check in seconds whether Azure's frames will map onto it.
  async load(url) {
    const gltf = await new GLTFLoader().loadAsync(url);
    if (this.root) this.scene.remove(this.root);
    this.root = gltf.scene;
    this.scene.add(this.root);

    this.targets.clear();
    this.meshes = [];
    this.root.traverse((o) => {
      if (!o.isMesh) return;
      this.meshes.push(o);
      if (!o.morphTargetDictionary) return;
      // Head, teeth and tongue are often separate meshes. Collect all of them
      // so every mesh with "jawOpen" moves together.
      for (const [name, index] of Object.entries(o.morphTargetDictionary)) {
        const k = norm(name);
        if (!this.targets.has(k)) this.targets.set(k, []);
        this.targets.get(k).push({ mesh: o, index });
      }
    });
    this.originalMaterials = this.meshes.map((m) => m.material);
    this.frameHead();

    const missing = AZURE_BLENDSHAPES.slice(0, ARKIT_COUNT).filter((n) => !this.targets.has(norm(n)));
    return { morphTargets: [...this.targets.keys()], missing };
  }

  frameHead() {
    const p = new THREE.Vector3();
    const head = this.root.getObjectByName('Head');
    if (head) {
      head.getWorldPosition(p);
    } else {
      const box = new THREE.Box3().setFromObject(this.root);
      p.set((box.min.x + box.max.x) / 2, box.max.y - 0.12, (box.min.z + box.max.z) / 2);
    }
    this.lookAt = new THREE.Vector3(p.x, p.y + 0.03, p.z);
    this.camera.position.set(p.x, p.y + 0.03, p.z + 0.8);
    this.camera.lookAt(this.lookAt);
  }

  setWeight(name, value) {
    const t = this.targets.get(norm(name));
    if (!t) return;
    for (const { mesh, index } of t) mesh.morphTargetInfluences[index] = value;
  }

  // Apply one Azure frame (55 numbers). Boost scales chosen channels inside a
  // time window, ramping over 50 ms so the face doesn't snap.
  // Azure's lip sync is soft: on p/b/m the lips never quite meet, and in pauses
  // the jaw hangs open. With the viseme timeline we seal the lips on p/b/m
  // (ARKit lips meet when mouthClose = jawOpen) and close the mouth in silence.
  applyFrame(values, t, visemes = []) {
    const b = this.boost;
    const seal = visemeWeight(visemes, BILABIAL, t);
    const rest = visemeWeight(visemes, SILENCE, t);
    const out = {};
    for (let i = 0; i < ARKIT_COUNT && i < values.length; i++) {
      const name = AZURE_BLENDSHAPES[i];
      let v = values[i];
      if (b && b.gains[name] && t >= b.start && t <= b.end) {
        const ramp = Math.max(0, Math.min(1, (t - b.start) / 0.05, (b.end - t) / 0.05));
        v *= 1 + (b.gains[name] - 1) * ramp;
      }
      if (/^(jaw|mouth)/.test(name)) v *= 1 - rest;
      out[name] = v;
    }
    for (const name of LIP_PARTING) out[name] *= 1 - seal;
    out.mouthClose += (out.jawOpen - out.mouthClose) * seal;
    out.mouthClose = Math.min(out.mouthClose, out.jawOpen); // beyond jawOpen the lips cross
    for (const [name, v] of Object.entries(out)) this.setWeight(name, Math.min(1, Math.max(0, v)));
  }

  // Play synthesized audio with its blend shape frames.
  //   boost:  { gains: { jawOpen: 1.4 }, start: 0.20, end: 0.45 }  (seconds)
  //   holdAt: seconds into the clip whose pose to hold (e.g. lips sealed for /p/)
  //   holdMs: how long to hold it
  //   holdBefore: the held sound starts the clip (the /p/ of "pah"). The face
  //     eases into its pose, holds it silently, and keeps it until the audio
  //     gets there, so the lips close once and open into the vowel. Otherwise
  //     (the /p/ of "ahp") the audio pauses on the pose when it gets there,
  //     which is the silent closure, so the sound isn't cut in two.
  play({ audio, frames, visemes = [], fps = 60, mime = 'audio/mpeg' },
    { boost = null, holdAt = null, holdMs = 500, holdBefore = false } = {}) {
    this.stop();
    this.boost = boost;
    const el = new Audio(URL.createObjectURL(new Blob([audio], { type: mime })));
    // Azure also sends a few extra viseme events at offset 0 after the real
    // ones; keep the timed ones, in order.
    visemes = visemes.filter((v) => v.time > 0).sort((a, b) => a.time - b.time);
    const before = holdAt != null && holdBefore;
    const now = performance.now();
    this.anim = {
      el, frames, visemes, fps, holdAt, holdMs, holdBefore: before,
      held: false, holding: false, previewStart: now, previewUntil: before ? now + holdMs : 0,
    };
    return new Promise((resolve, reject) => {
      el.onended = () => {
        this.anim = null;
        this.relax();
        resolve();
      };
      // browsers need a user gesture before the first play
      const start = () => this.anim?.el === el && el.play().catch(reject);
      if (before) setTimeout(start, holdMs);
      else start();
    });
  }

  stop() {
    if (this.anim) {
      this.anim.el.pause();
      this.anim = null;
    }
    this.relax();
  }

  relax() {
    for (const list of this.targets.values()) {
      for (const { mesh, index } of list) mesh.morphTargetInfluences[index] = 0;
    }
  }

  tick() {
    const a = this.anim;
    const now = performance.now();
    if (a && now < a.previewUntil) {
      // Showing the held pose before speaking, eased in over 150 ms.
      const i = Math.min(a.frames.length - 1, Math.round(a.holdAt * a.fps));
      const k = Math.min(1, (now - a.previewStart) / 150);
      if (a.frames[i]) this.applyFrame(a.frames[i].map((v) => v * k), a.holdAt, a.visemes);
    } else if (a && !a.holding) {
      const t = a.el.currentTime;
      if (a.holdAt != null && !a.holdBefore && !a.held && t >= a.holdAt) {
        a.held = true;
        a.holding = true;
        a.el.pause();
        setTimeout(() => {
          a.holding = false;
          if (this.anim === a) a.el.play();
        }, a.holdMs);
      }
      // A held first sound keeps its pose until the audio reaches it.
      const ft = a.holdBefore && t < a.holdAt ? a.holdAt : t;
      const i = Math.min(a.frames.length - 1, Math.floor(ft * a.fps));
      if (i >= 0 && a.frames[i]) this.applyFrame(a.frames[i], ft, a.visemes);
    }
    if (this.root) {
      // Turn to profile in X-ray mode so the tongue overlay lines up.
      const target = this.xray ? Math.PI / 2 : 0;
      this.root.rotation.y += (target - this.root.rotation.y) * 0.12;
    }
    this.renderer.setViewport(...this.viewport);
    this.renderer.render(this.scene, this.camera);
  }

  // See-through side view. The 2D tongue cross-section is a separate SVG layer
  // positioned over the canvas (see main.js).
  setXray(on) {
    this.xray = on;
    this.meshes.forEach((m, i) => {
      if (on) {
        const mats = Array.isArray(m.material) ? m.material : [m.material];
        const clones = mats.map((mat) => {
          const c = mat.clone();
          c.transparent = true;
          c.opacity = 0.3;
          c.depthWrite = false;
          return c;
        });
        m.material = Array.isArray(m.material) ? clones : clones[0];
      } else {
        m.material = this.originalMaterials[i];
      }
    });
  }
}

// Time (seconds) where a channel peaks inside [start, end]. Use it to pick
// holdAt, e.g. peakTime(frames, 'mouthClose', 0, 0.4) for the /p/ in "pop".
export function peakTime(frames, channel, start = 0, end = Infinity, fps = 60) {
  const ci = AZURE_BLENDSHAPES.indexOf(channel);
  let best = -1;
  let bestT = start;
  for (let i = Math.floor(start * fps); i < frames.length && i / fps <= end; i++) {
    if (frames[i] && frames[i][ci] > best) {
      best = frames[i][ci];
      bestT = i / fps;
    }
  }
  return bestT;
}
