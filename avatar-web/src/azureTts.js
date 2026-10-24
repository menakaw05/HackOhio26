// Azure TTS in the browser, returning audio plus the 55-value blend shape
// frames (60 fps) and viseme timings. Uses a short-lived token from your
// backend so the subscription key never ships to the browser.
import * as sdk from 'microsoft-cognitiveservices-speech-sdk';

let cached = null; // { config, expires }

export async function getSpeechConfig(tokenUrl = '/api/speech-token') {
  if (cached && Date.now() < cached.expires) return cached.config;
  const res = await fetch(tokenUrl);
  if (!res.ok) throw new Error(`token request failed: ${res.status}`);
  const { token, region } = await res.json();
  const config = sdk.SpeechConfig.fromAuthorizationToken(token, region);
  config.speechSynthesisOutputFormat = sdk.SpeechSynthesisOutputFormat.Audio24Khz48KBitRateMonoMp3;
  cached = { config, expires: Date.now() + 9 * 60 * 1000 }; // tokens last 10 minutes
  return config;
}

const escapeXml = (s) =>
  s.replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' })[c]);

// text: a word or chunk ("pop", "po", "pah").
// voice: en-US-AnaNeural is Azure's child voice; check it supports blend shapes.
// rate: slower speech for demonstrations; the blend shapes slow down with it.
export function synthesize(text, config, { voice = 'en-US-AnaNeural', rate = '-30%' } = {}) {
  const ssml = `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
    xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="en-US">
    <voice name="${voice}">
      <mstts:viseme type="FacialExpression"/>
      <prosody rate="${rate}">${escapeXml(text)}</prosody>
    </voice>
  </speak>`;

  return new Promise((resolve, reject) => {
    // null audio config: return the audio in memory instead of playing it.
    const synth = new sdk.SpeechSynthesizer(config, null);
    const frames = [];
    const visemes = [];

    synth.visemeReceived = (_s, e) => {
      visemes.push({ id: e.visemeId, time: e.audioOffset / 1e7 }); // 100-ns ticks -> s
      if (!e.animation) return;
      const chunk = JSON.parse(e.animation); // { FrameIndex, BlendShapes: [[55], ...] }
      chunk.BlendShapes.forEach((f, i) => {
        frames[chunk.FrameIndex + i] = f;
      });
    };

    synth.speakSsmlAsync(
      ssml,
      (result) => {
        synth.close();
        if (result.reason !== sdk.ResultReason.SynthesizingAudioCompleted) {
          reject(new Error(result.errorDetails || 'synthesis failed'));
          return;
        }
        // Fill any gaps between chunks with the previous frame.
        for (let i = 0; i < frames.length; i++) {
          if (!frames[i]) frames[i] = frames[i - 1] || new Array(55).fill(0);
        }
        resolve({ audio: result.audioData, frames, visemes, fps: 60, mime: 'audio/mpeg' });
      },
      (err) => {
        synth.close();
        reject(new Error(err));
      },
    );
  });
}
