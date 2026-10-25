import 'package:flutter/material.dart';

import '../data/mock/demo_seed.dart';
import '../theme/app_theme.dart';
import '../word_pictures.dart';

/// The word's picture from eLEXir on a white sticker card. Shows the word's emoji while the
/// picture loads, or if there isn't one.
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
    final fallback = emoji == null
        ? const SizedBox.shrink()
        : SizedBox.square(
            dimension: size,
            child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.7))),
          );
    return Semantics(
      label: 'Picture of ${widget.word}',
      excludeSemantics: true,
      child: FutureBuilder<String?>(
        future: _url,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null) return fallback;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.lakeDeep, width: 2.5),
              boxShadow: AppShadows.soft,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              url,
              // the originals are 1024px; decode at the size shown
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              frameBuilder: (context, child, frame, _) => frame == null ? Center(child: fallback) : child,
              errorBuilder: (context, error, stack) => Center(child: fallback),
            ),
          );
        },
      ),
    );
  }
}
