// Avatar page (avatar-web, embed mode) in a WebView that Flutter can make speak.
//
//   final avatarKey = GlobalKey<AvatarViewState>();
//   AvatarView(key: avatarKey, url: 'http://192.168.1.20:5173/?embed=1',
//              onMessage: (m) => debugPrint(m));
//   avatarKey.currentState?.say('pop', opts: {'holdViseme': 21});
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// avatar-web dev server (`npm run dev:lan`) on the laptop, same Wi-Fi:
///   flutter run --dart-define=AVATAR_URL=http://192.168.x.x:5173
const String avatarBaseUrl = String.fromEnvironment(
  'AVATAR_URL',
  defaultValue: 'http://localhost:5173',
);

class AvatarView extends StatefulWidget {
  const AvatarView({super.key, required this.url, this.onMessage});

  final String url;
  final void Function(String message)? onMessage; // {"event":"ready"|"started"|"finished"|"error",...}

  @override
  State<AvatarView> createState() => AvatarViewState();
}

class AvatarViewState extends State<AvatarView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    // iOS: allow inline audio/video without a tap, so Flutter can trigger speech.
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }

    controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'AvatarBridge',
        onMessageReceived: (m) => widget.onMessage?.call(m.message),
      )
      ..loadRequest(Uri.parse(widget.url));

    // Android: same, allow audio without a tap.
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Make the avatar say a word or chunk. opts are passed to avatar.play():
  /// boost {gains, start, end}, holdAt (s), holdMs, tts {voice, rate}.
  Future<void> say(String text, {Map<String, dynamic>? opts}) {
    return controller.runJavaScript(
      'window.say(${jsonEncode(text)}, ${jsonEncode(opts ?? {})});',
    );
  }

  Future<void> setXray(bool on) =>
      controller.runJavaScript('window.avatar.setXray(${on ? 'true' : 'false'});');

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: controller);
}
