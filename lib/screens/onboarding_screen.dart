import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app/app_shell.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';

/// Renders uniro_splash_onboarding.html inside WebView edge-to-edge,
/// capturing real user inputs (name, avatar photo file, notification permission)
/// and dynamically synchronizing status bar overlay colors per slide.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final WebViewController _webController;
  final ImagePicker _picker = ImagePicker();
  String? _pickedAvatarPath;
  Color _currentBgColor = const Color(0xFFD5803B);

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFD5803B))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      )
      ..loadFlutterAsset('uniro_splash_onboarding.html');
  }

  Future<void> _handleJavaScriptMessage(String rawMessage) async {
    try {
      final json = jsonDecode(rawMessage) as Map<String, dynamic>;
      final action = json['action'] as String?;

      if (action == 'slideChange') {
        final colorHex = json['color'] as String?;
        if (colorHex != null && mounted) {
          final colorVal = int.parse(colorHex.replaceFirst('#', '0xFF'));
          setState(() {
            _currentBgColor = Color(colorVal);
          });
          SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ));
        }
      } else if (action == 'pickAvatar') {
        await _pickAvatar();
      } else if (action == 'requestNotifications') {
        await _requestNotifications();
      } else if (action == 'finish') {
        final name = json['name'] as String? ?? 'Student';
        final notificationsEnabled =
            json['notificationsEnabled'] as bool? ?? false;
        await _finishOnboarding(
          name: name,
          avatarUri: _pickedAvatarPath,
          notificationsEnabled: notificationsEnabled,
        );
      }
    } catch (e) {
      debugPrint('JS channel message notice: $e');
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        _pickedAvatarPath = image.path;
        final pathEscaped = image.path.replaceAll(r'\', r'\\');
        _webController.runJavaScript('setAvatarPreview("file://$pathEscaped");');
      }
    } catch (e) {
      debugPrint('Avatar pick notice: $e');
    }
  }

  Future<void> _requestNotifications() async {
    final granted =
        await NotificationService.instance.requestPermissions();
    if (mounted) {
      _webController.runJavaScript('setNotifStatus($granted);');
    }
  }

  Future<void> _finishOnboarding({
    required String name,
    required String? avatarUri,
    required bool notificationsEnabled,
  }) async {
    final app = context.read<AppState>();

    // 1. Update settings with real inputs
    app.updateSettings(
      app.settings.copyWith(
        name: name.isNotEmpty ? name : 'Student',
        avatarUri: avatarUri,
        notificationsEnabled: notificationsEnabled,
      ),
    );

    // 2. Mark onboarding done
    LocalStore.instance.setOnboardingDone(true);

    if (!mounted) return;

    // 3. Navigate directly to AppShell
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, anim, secAnim) => const AppShell(),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentBgColor,
      body: WebViewWidget(controller: _webController),
    );
  }
}
