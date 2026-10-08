import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app/app_shell.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';

/// Renders uniro_splash_onboarding.html inside WebView on mobile devices
/// and provides a clean native onboarding experience on Flutter Web.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  WebViewController? _webController;
  final ImagePicker _picker = ImagePicker();
  String? _pickedAvatarPath;
  Color _currentBgColor = const Color(0xFFD5803B);

  // Web Fallback Controller State
  final PageController _webPageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _webCurrentPage = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
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
  }

  @override
  void dispose() {
    _webPageController.dispose();
    _nameController.dispose();
    super.dispose();
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
        if (_webController != null) {
          _webController!.runJavaScript('setAvatarPreview("file://$pathEscaped");');
        }
      }
    } catch (e) {
      debugPrint('Avatar pick notice: $e');
    }
  }

  Future<void> _requestNotifications() async {
    final granted =
        await NotificationService.instance.requestPermissions();
    if (mounted && _webController != null) {
      _webController!.runJavaScript('setNotifStatus($granted);');
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
    if (kIsWeb) {
      return _buildWebOnboarding(context);
    }

    return Scaffold(
      backgroundColor: _currentBgColor,
      body: WebViewWidget(controller: _webController!),
    );
  }

  Widget _buildWebOnboarding(BuildContext context) {
    final slideColors = [
      const Color(0xFFD5803B),
      const Color(0xFF3B6EA5),
      const Color(0xFF4A7C59),
      const Color(0xFF8B5E9E),
    ];

    return Scaffold(
      backgroundColor: slideColors[_webCurrentPage],
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Uniro',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _finishOnboarding(
                      name: 'Student',
                      avatarUri: null,
                      notificationsEnabled: false,
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _webPageController,
                onPageChanged: (page) {
                  setState(() => _webCurrentPage = page);
                },
                children: [
                  _buildWebSlide(
                    title: 'GET YOUR\nCAMPUS TASKS\nDONE.',
                    sub: 'Stay on top of every deadline, stress-free.',
                    icon: Icons.school_rounded,
                  ),
                  _buildWebSlide(
                    title: 'NEVER MISS\nA DEADLINE\nAGAIN.',
                    sub: 'Visual calendar keeps every due date in one place.',
                    icon: Icons.calendar_month_rounded,
                  ),
                  _buildWebNameSlide(),
                  _buildWebNotifSlide(),
                ],
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_webCurrentPage > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        _webPageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton(
                    onPressed: () {
                      if (_webCurrentPage < 3) {
                        _webPageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishOnboarding(
                          name: _nameController.text.trim(),
                          avatarUri: _pickedAvatarPath,
                          notificationsEnabled: true,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      _webCurrentPage == 3 ? 'Get Started' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSlide({
    required String title,
    required String sub,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.white),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNameSlide() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'WHAT\'S YOUR NAME?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll personalise your experience.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Enter your name…',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white24,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNotifSlide() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active_rounded,
              size: 100, color: Colors.white),
          SizedBox(height: 32),
          Text(
            'GET REMINDERS\nBEFORE IT\'S TOO LATE.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Smart alerts keep you ahead.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
