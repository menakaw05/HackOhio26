import { AvaturnSDK } from '@avaturn/sdk';
import { Avatar, BILABIAL, peakTime } from './avatar.js';
import { getSpeechConfig, synthesize } from './azureTts.js';
import { FaceTracker } from './faceTracker.js';

// Your Avaturn project subdomain from developer.avaturn.me ("demo" works for testing).
const AVATURN_SUBDOMAIN = 'voice';

const $ = (id) => document.getElementById(id);
const log = (msg) => { $('log').textContent = `${msg}\n${$('log').textContent}`.slice(0, 4000); };

// ?embed=1 -> avatar only, transparent background, for a Flutter WebView overlay.
// ?avatar=menaka -> which bundled preset in public/avatars/ to load.
// ?frame=x,y,w,h -> where to draw the avatar (fractions from the top left);
//   embed mode defaults to the lower right so the camera stays visible.
//   Flutter can also call window.avatar.setFrame({x, y, w, h}) at any time.
const params = new URLSearchParams(location.search);
const embed = params.has('embed');
if (embed) document.body.classList.add('embed');
const avatarUrl = `/avatars/${params.get('avatar') ?? 'krupa'}.glb`;

const avatar = new Avatar($('avatar'));
const tracker = new FaceTracker();
if (params.has('frame')) {
  const [x, y, w, h] = params.get('frame').split(',').map(Number);
  avatar.setFrame({ x, y, w, h });
} else if (embed) {
  avatar.setFrame({ x: 0.5, y: 0.45, w: 0.48, h: 0.36 });
}

// Bridge for Flutter (webview_flutter). Flutter calls window.say(text, opts)
// and listens on a JavaScript channel named "AvatarBridge".
// opts.holdViseme: freeze on the first viseme with this id (21 = p/b/m), since
// Flutter can't know the timing before the speech is synthesized.
const notify = (m) => window.AvatarBridge?.postMessage(JSON.stringify(m));
window.avatar = avatar;

// Synthesized clips by text + voice options. A repeated demonstration starts
// right away, and window.prepare(text, tts) fetches one ahead of time (e.g.
// while the app is still speaking a tip).
const clips = new Map();
const clipFor = (text, tts) => {
  const key = JSON.stringify([text, tts ?? null]);
  if (!clips.has(key)) {
    const pending = getSpeechConfig().then((config) => synthesize(text, config, tts));
    pending.catch(() => clips.delete(key));
    clips.set(key, pending);
  }
  return clips.get(key);
};
window.prepare = (text, tts) => clipFor(text, tts).then(() => true, () => false);

// Say several things back to back, e.g. a tip and then the sound, without a
// round trip to the app in between. items: [[text, opts], ...]
window.sayAll = async (items) => {
  for (const [text, opts] of items) await window.say(text, opts ?? {});
};

window.say = async (text, opts = {}) => {
  try {
    const clip = await clipFor(text, opts.tts);
    if (opts.holdViseme != null) {
      // Hold just inside the sound; if it's the first sound, show it first.
      const sounds = clip.visemes.filter((x) => x.time > 0 && x.id !== 0);
      const v = sounds.find((x) => x.id === opts.holdViseme);
      // (early in the sound, before the jaw starts moving toward the next one)
      if (v) opts = { ...opts, holdAt: v.time + 0.03, holdBefore: v === sounds[0] };
    }
    notify({ event: 'started', text, duration: clip.frames.length / clip.fps });
    await avatar.play(clip, opts);
    notify({ event: 'finished', text });
  } catch (e) {
    notify({ event: 'error', message: e.message });
    log(`say() error: ${e.message}`);
  }
};

// 1. Load a bundled T2 avatar preset.
avatar.load(avatarUrl).then(({ missing }) => {
  log(missing.length ? `Missing ARKit channels: ${missing.join(', ')}` : 'All 52 ARKit channels found.');
  notify({ event: 'ready', missing });
}).catch((e) => {
  log(`Could not load ${avatarUrl}: ${e.message}`);
  notify({ event: 'error', message: `avatar load failed: ${e.message}` });
});

// 2. Say a word or chunk, optionally exaggerating one movement and holding the key pose.
$('say').onclick = async () => {
  try {
    const config = await getSpeechConfig();
    const clip = await synthesize($('word').value, config);
    const duration = clip.frames.length / clip.fps;
    const opts = {};
    if ($('boost').checked) {
      // Exaggerate lip closure for the whole clip. In the real flow, set
      // start/end from the target phoneme's viseme timing instead.
      opts.boost = { gains: { mouthClose: 1.5, mouthPressLeft: 1.5, mouthPressRight: 1.5 }, start: 0, end: duration };
      // Hold on the first p/b/m once the lips are sealed (the raw mouthClose
      // peak falls between the vowel and the /p/, with the lips still apart).
      const bilabial = clip.visemes.find((v) => v.id === BILABIAL && v.time > 0);
      opts.holdAt = bilabial ? bilabial.time + 0.08 : peakTime(clip.frames, 'mouthClose', 0, duration);
      opts.holdMs = 600;
    }
    log(`Playing "${$('word').value}": ${clip.frames.length} frames, ${clip.visemes.length} visemes`);
    await avatar.play(clip, opts);
  } catch (e) {
    log(`TTS error: ${e.message}`);
  }
};

// 3. X-ray: turn the avatar side-on, make it see-through, show the tongue layer.
$('xray').onchange = (e) => {
  avatar.setXray(e.target.checked);
  $('tongue').style.display = e.target.checked ? 'block' : 'none';
};

// 4. Camera mirror with face tracking. Logs the kid's jawOpen so you can
// compare it with the avatar's target value for the same sound.
$('startCam').onclick = async () => {
  try {
    await tracker.init($('cam'));
    let n = 0;
    tracker.start((f) => {
      if (++n % 30 === 0) log(`kid jawOpen ${f.blend.jawOpen?.toFixed(2)}  mouthFunnel ${f.blend.mouthFunnel?.toFixed(2)}`);
    });
  } catch (e) {
    log(`Camera error: ${e.message}`);
  }
};

// 5. Optional: Avaturn's creator (official SDK) for making the bundled presets.
// On export we load the GLB into the scene and show a "Save avatar.glb" link;
// move the saved file to public/avatars/<name>.glb and open the page with ?avatar=<name>.
const creator = new AvaturnSDK();
creator.on('export', async ({ url, urlType, avatarSupportsFaceAnimations }) => {
  $('creator').style.display = 'none';
  log(`Exported (${urlType}). Face animations: ${avatarSupportsFaceAnimations ? 'yes (T2)' : 'no (T1, the face will not move)'}`);
  try {
    // Fetch once into a blob: works for both data and http URLs, and the
    // download attribute only works on same-origin links like blob: ones.
    const blob = await (await fetch(url)).blob();
    $('saveGlb').href = URL.createObjectURL(blob);
    $('saveGlb').hidden = false;
    const { missing } = await avatar.load($('saveGlb').href);
    log(missing.length ? `New avatar is missing: ${missing.join(', ')} (is it T1?)` : 'New avatar loaded with all ARKit channels.');
  } catch (e) {
    log(`Avatar export error: ${e.message}`);
  }
});

$('create').onclick = async () => {
  $('creator').style.display = 'block';
  try {
    await creator.init($('creator'), { url: `https://${AVATURN_SUBDOMAIN}.avaturn.dev` });
  } catch (e) {
    log(`Avaturn error: ${e.message}`);
  }
};
