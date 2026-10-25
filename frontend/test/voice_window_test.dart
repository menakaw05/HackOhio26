import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/voice_window.dart';

/// A 16 kHz mono WAV like the recorder's: [quietMs] of room noise, [voiceMs] of a loud tone,
/// then [quietMs] again. [padChunk] adds an extra chunk before the data, as iOS does.
/// [startClick] puts a very loud 60 ms click at the start, like the phone's recorder.
/// [bumpAtMs] adds a loud 40 ms bump there.
Uint8List _wav({
  int quietMs = 1000,
  int voiceMs = 400,
  bool padChunk = false,
  bool startClick = false,
  int? bumpAtMs,
}) {
  const rate = 16000;
  final rng = math.Random(1);
  final samples = <int>[
    for (var i = 0; i < quietMs * 16; i++) rng.nextInt(120) - 60,
    for (var i = 0; i < voiceMs * 16; i++) (6000 * math.sin(2 * math.pi * 220 * i / rate)).round(),
    for (var i = 0; i < quietMs * 16; i++) rng.nextInt(120) - 60,
  ];
  if (startClick) {
    for (var i = 0; i < 60 * 16; i++) {
      samples[i] = i.isEven ? 30000 : -30000;
    }
  }
  if (bumpAtMs != null) {
    for (var i = bumpAtMs * 16; i < (bumpAtMs + 40) * 16; i++) {
      samples[i] = i.isEven ? 9000 : -9000;
    }
  }
  final b = BytesBuilder();
  void tag(String s) => b.add(s.codeUnits);
  void u32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  tag('RIFF');
  u32(0);
  tag('WAVE');
  tag('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  if (padChunk) {
    tag('FLLR');
    u32(6);
    b.add(Uint8List(6));
  }
  tag('data');
  u32(samples.length * 2);
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(2 * i, samples[i], Endian.little);
  }
  b.add(data.buffer.asUint8List());
  return b.toBytes();
}

void main() {
  test('finds the voice between quiet stretches, padded', () {
    final wav = readPcm16Wav(_wav(padChunk: true))!;
    expect(wav.sampleRate, 16000);
    final voice = findVoice(wav.samples, wav.sampleRate)!;
    // the tone runs 1000-1400 ms; 150 ms of padding each side
    expect(voice.start.inMilliseconds, closeTo(850, 20));
    expect(voice.end.inMilliseconds, closeTo(1550, 20));
  });

  test('the start click is ignored', () {
    final wav = readPcm16Wav(_wav(startClick: true))!;
    final voice = findVoice(wav.samples, wav.sampleRate)!;
    expect(voice.start.inMilliseconds, closeTo(850, 20));
    expect(voice.end.inMilliseconds, closeTo(1550, 20));
  });

  test('a short loud bump loses to the held sound', () {
    final wav = readPcm16Wav(_wav(bumpAtMs: 2000))!;
    final voice = findVoice(wav.samples, wav.sampleRate)!;
    expect(voice.start.inMilliseconds, closeTo(850, 20));
    expect(voice.end.inMilliseconds, closeTo(1550, 20));
  });

  test('a soft voice in a quiet room is found', () {
    final wav = readPcm16Wav(_wav())!;
    final soft = Int16List.fromList([for (final s in wav.samples) s ~/ 30]);
    final voice = findVoice(soft, wav.sampleRate)!;
    expect(voice.start.inMilliseconds, closeTo(850, 20));
  });

  test('in a noisy room only the voice counts, not the noise around it', () {
    // levels like the phone's tonight: room ~150, voice peaking ~700
    final rng = math.Random(2);
    const rate = 16000;
    final samples = Int16List.fromList([
      for (var i = 0; i < 1000 * 16; i++) (rng.nextDouble() * 2 - 1) * 260 ~/ 1,
      for (var i = 0; i < 400 * 16; i++)
        (1000 * math.sin(2 * math.pi * 220 * i / rate) + (rng.nextDouble() * 2 - 1) * 260) ~/ 1,
      for (var i = 0; i < 1000 * 16; i++) (rng.nextDouble() * 2 - 1) * 260 ~/ 1,
    ]);
    final voice = findVoice(samples, rate)!;
    expect(voice.start.inMilliseconds, closeTo(850, 40));
    expect(voice.end.inMilliseconds, closeTo(1550, 40));
  });

  test('silence has no voice', () {
    final wav = readPcm16Wav(_wav(voiceMs: 0))!;
    expect(findVoice(wav.samples, wav.sampleRate), isNull);
  });

  test('not a wav', () {
    expect(readPcm16Wav(Uint8List.fromList('hello world!'.codeUnits)), isNull);
  });
}
