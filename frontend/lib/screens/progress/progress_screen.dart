import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

enum _Range { week, month }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.history.isEmpty && state.soundProfile.isEmpty) {
      return AppPage(
        title: 'Progress',
        children: [
          AppCard(
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: 'No progress yet',
              message: 'Practice a few words and your progress will show up here.',
              action: SecondaryButton(
                  label: 'Take the Diagnostic', onPressed: () => context.push(Routes.diagnostic)),
            ),
          ),
        ],
      );
    }

    final days = _range == _Range.week ? 7 : 30;
    final since = DateUtils.dateOnly(DateTime.now()).subtract(Duration(days: days - 1));
    final inRange = state.historySince(since);
    final minutes = inRange.fold<int>(0, (s, d) => s + d.minutes);
    final words = inRange.fold<int>(0, (s, d) => s + d.wordsPracticed);
    final sounds = [...state.soundProfile]..sort((a, b) => a.score.compareTo(b.score));

    return AppPage(
      title: 'Progress',
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_Range>(
                segments: const [
                  ButtonSegment(value: _Range.week, label: Text('Week')),
                  ButtonSegment(value: _Range.month, label: Text('Month')),
                ],
                selected: {_range},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
            const SizedBox(width: AppSpace.m),
            const TagBadge(label: 'Sample data'),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        Row(
          children: [
            Expanded(
              child: StatTile(
                  icon: Icons.timer_rounded, value: '$minutes', label: 'minutes practiced'),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: StatTile(
                  icon: Icons.chat_bubble_rounded,
                  color: AppColors.lotus,
                  value: '$words',
                  label: 'words practiced'),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: StatTile(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.sky,
                  value: '${inRange.length}',
                  label: 'days practiced'),
            ),
          ],
        ),
        if (state.trends.isNotEmpty) ...[
          const SectionHeader(title: 'Getting better'),
          AppCard(
            child: Column(
              children: [
                for (final t in state.trends) _TrendRow(trend: t),
              ],
            ),
          ),
        ],
        if (sounds.isNotEmpty) ...[
          const SectionHeader(title: 'Every sound'),
          AppCard(child: Column(children: [for (final s in sounds) SoundBar(score: s)])),
        ],
        if (state.mastered.isNotEmpty) ...[
          const SectionHeader(title: 'Your aquarium'),
          Text('Every sound you master adds a sea friend.', style: AppText.caption),
          const SizedBox(height: AppSpace.s),
          _Aquarium(mastered: state.mastered),
        ],
        if (state.activity.isNotEmpty) ...[
          const SectionHeader(title: 'Recent activity'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.s),
            child: Column(
              children: [
                for (var i = 0; i < state.activity.length; i++) ...[
                  if (i > 0) const Divider(),
                  _ActivityRow(entry: state.activity[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final SoundTrend trend;

  @override
  Widget build(BuildContext context) {
    final level = SoundLevel.fromScore(trend.weekly.last);
    return Semantics(
      label: 'Sound ${trend.phoneme} over ${trend.weekly.length} weeks, now ${level.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
        child: Row(
          children: [
            SoundChip(phoneme: trend.phoneme, kind: level.kind),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Text('${trend.weekly.length} weeks · now ${level.label.toLowerCase()}',
                  style: AppText.caption),
            ),
            Sparkline(values: trend.weekly, color: level.kind.color),
          ],
        ),
      ),
    );
  }
}

/// A fish tank with one sea creature per mastered sound: fish swimming, every third one a
/// starfish on the sand.
class _Aquarium extends StatelessWidget {
  const _Aquarium({required this.mastered});

  final List<String> mastered;

  static const _fishColors = [AppColors.lotus, AppColors.sky, AppColors.lilyPad, AppColors.almost];

  @override
  Widget build(BuildContext context) {
    final rows = (mastered.length / 3).ceil();
    return Semantics(
      label: 'Aquarium with ${mastered.length} sea friends, for ${mastered.map((p) => '/$p/').join(', ')}',
      excludeSemantics: true,
      child: Container(
        height: 120.0 + rows * 70,
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.lakeDeep, width: 2.5),
          boxShadow: AppShadows.soft,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE9E4), Color(0xFF6CC4C0), Color(0xFF2F86C8)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return Stack(
            children: [
              // sand and bubbles
              Positioned.fill(child: CustomPaint(painter: _TankPainter())),
              for (final (i, p) in mastered.indexed)
                if (i % 3 == 2)
                  Positioned(
                    left: w * (0.12 + (i ~/ 3) * 0.3 % 0.75),
                    bottom: 8,
                    child: _Creature(phoneme: p, child: const Starfish(color: AppColors.sun, size: 46)),
                  )
                else
                  Positioned(
                    left: w * (i.isEven ? 0.08 : 0.52) + (i ~/ 3) * 18,
                    top: 18 + (i ~/ 3) * 70.0 + (i.isEven ? 0 : 26),
                    child: _Creature(
                      phoneme: p,
                      child: CustomPaint(
                        size: const Size(70, 40),
                        painter: _FishPainter(_fishColors[i % _fishColors.length], flip: i.isOdd),
                      ),
                    ),
                  ),
              if (mastered.isEmpty)
                Center(
                  child: Text('Master a sound to add your first fish!',
                      style: AppText.bodyStrong.copyWith(color: Colors.white)),
                ),
              Positioned(right: 10, top: h * 0.5, child: const OctopusBuddy(size: 64, bubbles: true)),
            ],
          );
        }),
      ),
    );
  }
}

/// A sea creature with its sound on a little tag.
class _Creature extends StatelessWidget {
  const _Creature({required this.phoneme, required this.child});

  final String phoneme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: AppRadius.pillRadius),
          child: Text('/$phoneme/', style: AppText.caption.copyWith(color: AppColors.lakeDeep)),
        ),
      ],
    );
  }
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.color, {this.flip = false});

  final Color color;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (flip) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    final body = Paint()..color = color;
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.3, h * 0.5)
          ..lineTo(0, h * 0.1)
          ..lineTo(0, h * 0.9)
          ..close(),
        body);
    canvas.drawOval(Rect.fromLTWH(w * 0.2, 0, w * 0.8, h), body);
    canvas.drawOval(Rect.fromLTWH(w * 0.45, h * 0.55, w * 0.2, h * 0.25),
        Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(Offset(w * 0.8, h * 0.4), h * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.82, h * 0.4), h * 0.07, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_FishPainter old) => old.color != color || old.flip != flip;
}

class _TankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sand = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 10) {
      sand.lineTo(x, size.height - 22 - math.sin(x / 40) * 5);
    }
    sand
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(sand, Paint()..color = const Color(0xFFF6E3B4));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.5);
    final rng = math.Random(3);
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.8), 3 + rng.nextDouble() * 6, ring);
    }
  }

  @override
  bool shouldRepaint(_TankPainter old) => false;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: Row(
        children: [
          Icon(entry.kind.icon, color: entry.kind.color),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.word, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                SourceChip(label: entry.source.label, icon: entry.source.icon),
              ],
            ),
          ),
          Text(relativeDay(entry.when), style: AppText.caption),
        ],
      ),
    );
  }
}
