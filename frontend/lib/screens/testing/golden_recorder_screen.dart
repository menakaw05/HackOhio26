import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../router.dart';
import '../../stage4/golden_store.dart';
import '../../stage4/phonemes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

/// Lists every phoneme with how many golden takes it has, and exports the data.
class GoldenRecorderScreen extends StatefulWidget {
  const GoldenRecorderScreen({super.key, this.store});

  /// Defaults to [GoldenStore.instance]; tests pass an in-memory store.
  final GoldenStore? store;

  @override
  State<GoldenRecorderScreen> createState() => _GoldenRecorderScreenState();
}

class _GoldenRecorderScreenState extends State<GoldenRecorderScreen> {
  late final GoldenStore _store = widget.store ?? GoldenStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all takes?'),
        content: Text('This deletes all ${_store.totalTakes} takes on this phone. '
            "Exported files aren't affected."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (ok == true) await _store.clearAll();
  }

  Future<void> _export(BuildContext buttonContext) async {
    final file = _store.file;
    if (file == null || !await file.exists()) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'mirrorU golden data',
      // required on iPad, where the share sheet is a popover
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final required = goldenPhonemes.where((p) => p.group != PhonemeGroup.rColored);
        final done = _store.completedCount(required.map((p) => p.ipa));
        return AppPage(
          title: 'Golden data recorder',
          children: [
            Text(
              'Record ${GoldenStore.takesPerPhoneme} takes of each sound on its own. '
              'Recordings are saved on this phone; export them to add to the app.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpace.l),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('$done / ${required.length} sounds done', style: AppText.section),
                  Text('${_store.totalTakes} takes recorded', style: AppText.caption),
                  const SizedBox(height: AppSpace.s),
                  ProgressBar(value: required.isEmpty ? 0 : done / required.length),
                  const SizedBox(height: AppSpace.m),
                  Builder(
                    builder: (buttonContext) => PrimaryButton(
                      label: 'Export golden data',
                      icon: Icons.ios_share_rounded,
                      onPressed: _store.totalTakes == 0 || _store.file == null
                          ? null
                          : () => _export(buttonContext),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  TextButton.icon(
                    onPressed: _store.totalTakes == 0 ? null : _confirmClear,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Delete all takes'),
                  ),
                  if (_store.file != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(_store.file!.path, style: AppText.caption, maxLines: 2),
                  ],
                ],
              ),
            ),
            for (final group in PhonemeGroup.values) ...[
              SectionHeader(title: group.label),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
                child: Column(
                  children: [
                    for (final p in goldenPhonemes.where((p) => p.group == group))
                      _PhonemeRow(phoneme: p, takes: _store.takesFor(p.ipa).length),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PhonemeRow extends StatelessWidget {
  const _PhonemeRow({required this.phoneme, required this.takes});

  final GoldenPhoneme phoneme;
  final int takes;

  @override
  Widget build(BuildContext context) {
    final complete = takes >= GoldenStore.takesPerPhoneme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
      leading: SizedBox(
        width: 64,
        child: Text('/${phoneme.ipa}/', style: AppText.section),
      ),
      title: Text('as in "${phoneme.example}"', style: AppText.bodyText),
      trailing: TagBadge(
        label: '$takes / ${GoldenStore.takesPerPhoneme}',
        color: complete ? AppColors.success : AppColors.inkSoft,
        background: complete ? AppColors.successSoft : AppColors.lakeMist,
      ),
      onTap: () => context.push(Routes.goldenPhoneme(phoneme.ipa)),
    );
  }
}
