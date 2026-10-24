import { AvaturnSDK } from '@avaturn/sdk';
import { Avatar, BILABIAL, peakTime } from './avatar.js';
import { getSpeechConfig, synthesize } from './azureTts.js';
import { FaceTracker } from './faceTracker.js';
import { MirrorCheck } from './mirror.js';

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
window.say = async (text, opts = {}) => {
  try {
    const config = await getSpeechConfig();
    const clip = await synthesize(text, config, opts.tts);
    if (opts.holdViseme != null) {
      const v = clip.visemes.find((x) => x.id === opts.holdViseme && x.time > 0);
      if (v) opts = { ...opts, holdAt: v.time + 0.08 };
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

// 4. Camera mirror with face tracking, compared live with the coach
// (see mirror.js). Copy me: the coach says the word, then the kid copies it.
const mirror = new MirrorCheck($('mirror'), avatar);
$('startCam').onclick = async () => {
  try {
    await tracker.init($('cam'));
    tracker.start((f) => mirror.kidFrame(f));
  } catch (e) {
    log(`Camera error: ${e.message}`);
  }
};
$('copyMe').onclick = async () => {
  if (!tracker.running) {
    log('Start the camera first.');
    return;
  }
  try {
    const word = $('word').value;
    const clip = await synthesize(word, await getSpeechConfig());
    await mirror.copyMe(word, () => avatar.play(clip));
  } catch (e) {
    log(`Copy me error: ${e.message}`);
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
