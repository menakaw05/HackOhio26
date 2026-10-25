import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/router.dart';
import 'package:frontend/stage4/golden_store.dart';
import 'package:frontend/stage4/mouth_features.dart';
import 'package:frontend/stage4/phonemes.dart';
import 'screens_test.dart' show pumpAt;

/// A simple synthetic face: eyes 100px apart, mouth below, chin at the bottom.
Map<String, List<Pt>> face({double scale = 1, double gap = 10, double width = 60}) {
  List<Pt> line(double x0, double x1, double y) =>
      [for (var i = 0; i <= 4; i++) (x: (x0 + (x1 - x0) * i / 4) * scale, y: y * scale)];
  final half = width / 2;
  return {
    'leftEye': [(x: 50 * scale, y: 100 * scale)],
    'rightEye': [(x: 150 * scale, y: 100 * scale)],
    'noseBottom': [(x: 100 * scale, y: 160 * scale)],
    'upperLipTop': line(100 - half, 100 + half, 190),
    'upperLipBottom': line(100 - half, 100 + half, 200),
    'lowerLipTop': line(100 - half, 100 + half, 200 + gap),
    'lowerLipBottom': line(100 - half, 100 + half, 210 + gap),
    'face': [(x: 20 * scale, y: 120 * scale), (x: 100 * scale, y: 280 * scale), (x: 180 * scale, y: 120 * scale)],
  };
}

MouthFrame frame(int t) => MouthFrame(t: t, features: [0.1, 0.2, 0.6, 1.2, 0.33], contours: const {
      'upperLipTop': [1, 2, 3, 4],
    });

void main() {
  group('mouth features', () {
    test('do not depend on distance from the camera', () {
      final near = mouthFeatures(face(scale: 2))!;
      final far = mouthFeatures(face())!;
      for (var i = 0; i < featureNames.length; i++) {
        expect(near[i], closeTo(far[i], 1e-9), reason: featureNames[i]);
      }
    });

    test('closed lips have no gap; wider mouth is wider and less round', () {
      final closed = mouthFeatures(face(gap: 0))!;
      expect(closed[0], 0);
      final wide = mouthFeatures(face(width: 80))!;
      final narrow = mouthFeatures(face(width: 40))!;
      expect(wide[2], greaterThan(narrow[2]));
      expect(wide[4], lessThan(narrow[4]));
      // jaw: nose (y 160) to chin (y 280) over eye distance 100
      expect(closed[3], closeTo(1.2, 1e-9));
    });

    test('missing contours give no features', () {
      expect(mouthFeatures(face()..remove('leftEye')), isNull);
    });
  });

  group('golden store', () {
    test('counts complete phonemes and deletes takes', () async {
      final store = GoldenStore();
      for (var i = 0; i < GoldenStore.takesPerPhoneme; i++) {
        await store.addTake('u', [frame(0), frame(66)]);
      }
      await store.addTake('p', [frame(0)]);
      expect(store.completedCount(['u', 'p']), 1);
      expect(store.totalTakes, 6);
      await store.deleteTake('u', store.takesFor('u').first.id);
      expect(store.completedCount(['u']), 0);
    });

    test('saves to and reloads from a file', () async {
      final dir = await Directory.systemTemp.createTemp('golden');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/golden_data.json');

      final store = GoldenStore(file: file);
      await store.load();
      await store.addTake('ɑɹ', [frame(0), frame(50)]);

      final reloaded = GoldenStore(file: file);
      await reloaded.load();
      final take = reloaded.takesFor('ɑɹ').single;
      expect(take.frames.length, 2);
      expect(take.durationMs, 50);
      expect(take.frames.first.features, [0.1, 0.2, 0.6, 1.2, 0.33]);
      expect(take.frames.first.contours['upperLipTop'], [1, 2, 3, 4]);
    });
  });

  test('phoneme list is the 47 Azure symbols with no duplicates', () {
    final symbols = goldenPhonemes.map((p) => p.ipa).toList();
    expect(symbols.length, 47);
    expect(symbols.toSet().length, 47);
    expect(symbols, containsAll(['ɹ', 'g', 'ɚ', 'ɝ', 'ɑɹ', 'aɪɹ']));
    expect(symbols, isNot(contains('r')));
    expect(symbols, isNot(contains('ɡ'))); // IPA script g; Azure uses ASCII g
  });

  testWidgets('recorder lists sounds and opens a sound with a non-ASCII symbol', (tester) async {
    // sync file calls: real async IO never completes inside a widget test's fake clock
    final dir = Directory.systemTemp.createTempSync('golden');
    addTearDown(() => dir.deleteSync(recursive: true));
    // keep the shared store off path_provider in tests
    GoldenStore.instance.file = File('${dir.path}/golden_data.json');

    await pumpAt(tester, Routes.goldenRecorder);
    expect(find.text('0 / 41 sounds done'), findsOneWidget);
    expect(find.text('/p/'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('/ɑɹ/'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('/ɑɹ/'));
    // no camera in tests: step past the camera lookup timeout instead of settling
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Say just the sound, as in "car".'), findsOneWidget);
    expect(find.text('No camera available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
