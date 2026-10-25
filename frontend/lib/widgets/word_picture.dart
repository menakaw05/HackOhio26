import 'package:flutter/material.dart';

import '../data/mock/demo_seed.dart';
import '../theme/app_theme.dart';
import '../word_pictures.dart';

/// The word's picture in a bubble, like the sound bubbles. The pictures come transparent and
/// centered from the backend; the word's emoji shows while one loads, or if there isn't one.
class WordPicture extends StatefulWidget {
  const WordPicture({super.key, required this.word, this.size = 120});

  final String word;
  final double size;

  @override
  State<WordPicture> createState() => _WordPictureState();
}

class _WordPictureState extends State<WordPicture> {
  late Future<String?> _url = WordPictures.urlFor(widget.word);

  @override
  void didUpdateWidget(WordPicture old) {
    super.didUpdateWidget(old);
    if (old.word != widget.word) _url = WordPictures.urlFor(widget.word);
  }

  @override
  Widget build(BuildContext context) {
    final emoji = pictureFor(widget.word);
    final size = widget.size;
    final inner = size * 0.76;
    final fallback = emoji == null
        ? const SizedBox.shrink()
        : Text(emoji, style: TextStyle(fontSize: inner * 0.7));
    return Semantics(
      label: 'Picture of ${widget.word}',
      excludeSemantics: true,
      child: FutureBuilder<String?>(
        future: _url,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null && emoji == null) return const SizedBox.shrink();
          return _Bubble(
            size: size,
            child: url == null
                ? fallback
                : Image.network(
                    url,
                    width: inner,
                    height: inner,
                    // the pictures are 512px; decode at the size shown
                    cacheWidth: (inner * MediaQuery.devicePixelRatioOf(context)).round(),
                    frameBuilder: (context, child, frame, _) => frame == null ? fallback : child,
                    errorBuilder: (context, error, stack) => fallback,
                  ),
          );
        },
      ),
    );
  }
}

/// A round aqua bubble with a rim and a shine, the picture centered in it.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.lakeMist,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lake.withValues(alpha: 0.55), width: 2.5),
            ),
          ),
          child,
          // a bubble's shine
          Positioned(
            left: size * 0.16,
            top: size * 0.12,
            child: Transform.rotate(
              angle: -0.6,
              child: Container(
                width: size * 0.16,
                height: size * 0.08,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: AppRadius.pillRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
