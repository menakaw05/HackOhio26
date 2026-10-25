import 'dart:math' as math;
import 'dart:typed_data';

/// When the child was speaking during a sound attempt, from the loudness of the recording.
/// The lip check judges only the camera frames from then: the resting mouth before and after
/// the sound looks like a right "cat" to the A model and would outvote a wrong "cut".
/// The audio never leaves the phone.
class VoiceWindow {
  const VoiceWindow(this.start, this.end);

  /// From the start of the recording.
  final Duration start;
  final Duration end;
}

/// Quieter than this (RMS of 16-bit samples, about -50 dBFS) counts as silence.
const minVoiceRms = 100.0;

/// A voice peaks at least this many times louder than the room (the quietest fifth of the
/// recording). On the phone tonight the room was ~150-190 and a voice ~650-1300.
const voiceOverRoom = 3.0;

/// Speaking is louder than this many times the room (and than a quarter of the peak).
const speechOverRoom = 2.0;

/// The 16-bit mono samples of a WAV file and its sample rate, or null if it isn't one.
({Int16List samples, int sampleRate})? readPcm16Wav(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final data = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;

  int? sampleRate;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = tag(at);
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      final format = data.getUint16(body, Endian.little);
      final channels = data.getUint16(body + 2, Endian.little);
      final bits = data.getUint16(body + 14, Endian.little);
      if (format != 1 || channels != 1 || bits != 16) return null;
      sampleRate = data.getUint32(body + 4, Endian.little);
    } else if (id == 'data' && sampleRate != null) {
      // a header that was never finalized has a size of 0: read to the end
      final end = size == 0 ? bytes.length : math.min(body + size, bytes.length);
      final samples = Int16List((end - body) ~/ 2);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = data.getInt16(body + 2 * i, Endian.little);
      }
      return (samples: samples, sampleRate: sampleRate);
    }
    at = body + size + (size & 1);
  }
  return null;
}

/// The recorder starts with a click on the phone, often the loudest thing in the recording.
const skipStart = Duration(milliseconds: 200);

/// The loudest stretch of 20 ms steps louder than a quarter of the loudest step and twice the
/// room (pauses of up to 200 ms joined), padded by [pad] for the lips moving before and after
/// the voice. A short click or bump loses to a held sound. Null if it's all quiet.
VoiceWindow? findVoice(
  Int16List samples,
  int sampleRate, {
  Duration pad = const Duration(milliseconds: 150),
}) {
  const stepMs = 20, maxGap = 10;
  final step = sampleRate * stepMs ~/ 1000;
  final rms = <double>[];
  for (var i = 0; i + step <= samples.length; i += step) {
    var sum = 0.0;
    for (var j = i; j < i + step; j++) {
      sum += samples[j] * samples[j].toDouble();
    }
    rms.add(rms.length * stepMs < skipStart.inMilliseconds ? 0 : math.sqrt(sum / step));
  }
  if (rms.isEmpty) return null;
  final peak = rms.reduce(math.max);
  final heard = [...rms.where((r) => r > 0)]..sort();
  final room = heard.isEmpty ? 0.0 : heard[heard.length ~/ 5];
  print('voice levels: peak ${peak.round()}, room ${room.round()}');
  if (peak < math.max(minVoiceRms, room * voiceOverRoom)) return null;
  final speech = math.max(peak / 4, room * speechOverRoom);

  // loud stretches as (first step, last step, energy)
  final stretches = <(int, int, double)>[];
  for (var i = 0; i < rms.length; i++) {
    if (rms[i] < speech) continue;
    final e = rms[i] * rms[i];
    if (stretches.isNotEmpty && i - stretches.last.$2 <= maxGap) {
      final (first, _, energy) = stretches.removeLast();
      stretches.add((first, i, energy + e));
    } else {
      stretches.add((i, i, e));
    }
  }
  final (from, to, _) = stretches.reduce((a, b) => b.$3 > a.$3 ? b : a);
  final start = Duration(milliseconds: from * stepMs) - pad;
  return VoiceWindow(
    start < Duration.zero ? Duration.zero : start,
    Duration(milliseconds: (to + 1) * stepMs) + pad,
  );
}
