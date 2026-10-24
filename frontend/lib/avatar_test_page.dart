// Avatar test screen: front camera at the back, the avatar page on top
// (transparent, touches pass through), and controls to make it speak.
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'avatar_view.dart';

const _presets = ['krupa', 'menaka'];
const _bilabial = 21; // Azure viseme id for p, b, m

class AvatarTestPage extends StatefulWidget {
  const AvatarTestPage({super.key});

  @override
  State<AvatarTestPage> createState() => _AvatarTestPageState();
}

class _AvatarTestPageState extends State<AvatarTestPage> {
  final TextEditingController _wordController =
      TextEditingController(text: 'pop');
  // New key per preset, so switching reloads the page with the other avatar.
  GlobalKey<AvatarViewState> _avatarKey = GlobalKey();
  CameraController? _camera;
  String _preset = _presets.first;
  bool _holdOnP = false;
  bool _xray = false;
  final List<String> _events = [];

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front);
      final camera =
          CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await camera.initialize();
      if (!mounted) return;
      setState(() => _camera = camera);
    } catch (e) {
      _addEvent('camera error: $e');
    }
  }

  void _addEvent(String line) {
    setState(() {
      _events.insert(0, line);
      if (_events.length > 4) _events.removeLast();
    });
  }

  void _onAvatarMessage(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    switch (m['event']) {
      case 'ready':
        _addEvent('ready, missing ${(m['missing'] as List).length} channels');
      case 'error':
        _addEvent('error: ${m['message']}');
      default:
        _addEvent('${m['event']} ${m['text'] ?? ''}');
    }
  }

  void _say() {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;
    _avatarKey.currentState?.say(word, opts: {
      if (_holdOnP) 'holdViseme': _bilabial,
      if (_holdOnP) 'holdMs': 800,
    });
  }

  void _setPreset(String preset) {
    setState(() {
      _preset = preset;
      _xray = false;
      _avatarKey = GlobalKey();
    });
  }

  Widget _panel(Widget child) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Avatar test')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera -> avatar (touches pass through) -> controls.
          if (camera != null)
            Center(child: CameraPreview(camera))
          else
            const Center(child: CircularProgressIndicator()),
          IgnorePointer(
            child: AvatarView(
              key: _avatarKey,
              url: '$avatarBaseUrl/?embed=1&avatar=$_preset',
              onMessage: _onAvatarMessage,
            ),
          ),
          if (_events.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _panel(Text(_events.join('\n'))),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: _panel(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _wordController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Word or chunk',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                          onSubmitted: (_) => _say(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _say, child: const Text('Say')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text(p),
                          selected: _preset == p,
                          onSelected: (_) => _setPreset(p),
                        ),
                      FilterChip(
                        label: const Text('Hold on p/b/m'),
                        selected: _holdOnP,
                        onSelected: (v) => setState(() => _holdOnP = v),
                      ),
                      FilterChip(
                        label: const Text('X-ray'),
                        selected: _xray,
                        onSelected: (v) {
                          setState(() => _xray = v);
                          _avatarKey.currentState?.setXray(v);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
