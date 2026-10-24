// Mirror check: the coach (avatar) and the kid (webcam) side by side on one
// clock (performance.now()). Both faces use ARKit names, so jawOpen means the
// same thing on each. Live meters while the camera runs, and a "copy me" test:
// the avatar says the word, then the kid gets a few seconds to copy it, and the
// two mouth curves are compared on one timeline.
const COPY_MS = 2500;
const KID_CLOSED = 0.015; // inner-lip gap / face height below this = lips together
const COACH_CLOSED = 0.02; // jawOpen - mouthClose below this = lips together

// Kid's lip gap from MediaPipe's 478 landmarks: inner lips (13, 14) over
// face height (10 forehead, 152 chin), so it doesn't depend on camera distance.
function kidLipGap(lm) {
  const d = (a, b) => Math.hypot(lm[a].x - lm[b].x, lm[a].y - lm[b].y);
  return d(13, 14) / d(10, 152);
}

// Peak opening, and whether the lips came back together after it
// (e.g. the final /p/ of "pop"). Lips closed before speaking don't count.
function summarize(samples, closedBelow) {
  const peak = Math.max(0, ...samples.map((s) => s.jaw));
  const opened = samples.findIndex((s) => s.jaw > peak * 0.5);
  const closedAfter = peak > 0.05 && opened >= 0 && samples.slice(opened).some((s) => s.gap < closedBelow);
  return { peak, closedAfter };
}

export class MirrorCheck {
  constructor(el, avatar) {
    this.avatar = avatar;
    this.kid = null; // latest webcam frame: { jaw, gap }
    this.phase = null; // 'coach' | 'kid' while a copy test runs
    this.coachSamples = [];
    this.kidSamples = [];
    this.counts = { kid: 0, render: 0 };

    el.innerHTML = `
      <div class="meters">
        <span></span><span class="who coach">Coach</span><span class="who you">You</span>
        <span>Mouth open</span><div class="bar coach"><i></i></div><div class="bar you"><i></i></div>
        <span>Lips together</span><span class="lips coach">-</span><span class="lips you">-</span>
      </div>
      <canvas class="chart" height="140"></canvas>
      <p class="result">Start the camera, then press Copy me.</p>
      <p class="fps"></p>`;
    this.el = el;
    this.bars = el.querySelectorAll('.bar i');
    this.lips = el.querySelectorAll('.lips');
    this.chart = el.querySelector('.chart');
    this.result = el.querySelector('.result');
    this.fps = el.querySelector('.fps');

    setInterval(() => this.showFps(), 1000);
    const loop = () => {
      this.update();
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  // Called by the face tracker for every webcam frame.
  kidFrame(f) {
    this.kid = { jaw: f.blend.jawOpen ?? 0, gap: kidLipGap(f.landmarks) };
    this.counts.kid++;
    if (this.phase === 'kid') this.kidSamples.push({ t: performance.now(), ...this.kid });
  }

  update() {
    this.counts.render++;
    const jaw = this.avatar.getWeight('jawOpen');
    const coach = { jaw, gap: jaw - this.avatar.getWeight('mouthClose') };
    if (this.phase === 'coach') this.coachSamples.push({ t: performance.now(), ...coach });
    this.bars[0].style.width = `${Math.min(100, coach.jaw * 100)}%`;
    this.lips[0].textContent = coach.gap < COACH_CLOSED ? 'yes' : 'no';
    if (this.kid) {
      this.bars[1].style.width = `${Math.min(100, this.kid.jaw * 100)}%`;
      this.lips[1].textContent = this.kid.gap < KID_CLOSED ? 'yes' : 'no';
    }
  }

  showFps() {
    this.fps.textContent = `Camera tracking ${this.counts.kid} fps · avatar ${this.counts.render} fps`;
    this.counts = { kid: 0, render: 0 };
  }

  // play: starts the avatar speaking and resolves when it finishes.
  async copyMe(word, play) {
    this.coachSamples = [];
    this.kidSamples = [];
    this.result.textContent = `Watch the coach say "${word}"...`;
    const start = performance.now();
    this.phase = 'coach';
    await play();
    this.phase = 'kid';
    const turn = performance.now();
    this.result.textContent = `Your turn! Say "${word}".`;
    await new Promise((r) => setTimeout(r, COPY_MS));
    this.phase = null;

    const coach = summarize(this.coachSamples, COACH_CLOSED);
    const you = summarize(this.kidSamples, KID_CLOSED);
    const pct = coach.peak > 0 ? Math.round((you.peak / coach.peak) * 100) : 0;
    const yn = (b) => (b ? 'yes' : 'no');
    this.result.textContent =
      `Mouth open: coach ${coach.peak.toFixed(2)}, you ${you.peak.toFixed(2)} (${pct}% of the coach). ` +
      `Lips back together after opening: coach ${yn(coach.closedAfter)}, you ${yn(you.closedAfter)}.`;
    this.draw(start, turn, performance.now());
  }

  // Both jawOpen curves on one time axis: coach while demonstrating, kid after.
  draw(start, turn, end) {
    const c = this.chart;
    const w = (c.width = c.clientWidth);
    const h = c.height;
    const css = getComputedStyle(this.el);
    const g = c.getContext('2d');
    const x = (t) => ((t - start) / (end - start)) * w;
    const y = (v) => h - 18 - v * (h - 28);
    g.clearRect(0, 0, w, h);
    g.fillStyle = css.getPropertyValue('--you-soft');
    g.fillRect(x(turn), 0, w - x(turn), h - 18);
    g.fillStyle = css.getPropertyValue('--muted');
    g.font = '11px system-ui, sans-serif';
    g.fillText('coach demonstrates', 4, h - 4);
    g.fillText('your turn', x(turn) + 4, h - 4);
    g.fillText('jawOpen 1.0', 4, 12);
    for (const [samples, color] of [[this.coachSamples, '--coach'], [this.kidSamples, '--you']]) {
      g.strokeStyle = css.getPropertyValue(color);
      g.lineWidth = 2;
      g.beginPath();
      samples.forEach((s, i) => (i ? g.lineTo(x(s.t), y(s.jaw)) : g.moveTo(x(s.t), y(s.jaw))));
      g.stroke();
    }
  }
}
