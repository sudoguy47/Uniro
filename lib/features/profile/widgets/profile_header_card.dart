import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/logger.dart';
import '../../../models/settings.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/ui_kit.dart';

/// Compact identity row: avatar (tap to change) + editable name.
/// Everything stays local — the caption says so in plain words.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (!context.mounted) return;
      if (image != null) {
        final app = context.read<AppState>();
        app.updateSettings(app.settings.copyWith(avatarUri: image.path));
      }
    } on PlatformException catch (e) {
      AppLog.w('avatar picker notice', e);
      if (!context.mounted) return;
      AppNotification.error(context, "Couldn't open the photo picker.");
    } catch (e) {
      AppLog.w('avatar picker notice', e);
      if (!context.mounted) return;
      AppNotification.error(context, "Couldn't open the photo picker.");
    }
  }

  void _editNameDialog(BuildContext context, UserSettings settings) {
    final controller = TextEditingController(text: settings.name);
    final c = Theme.of(context).extension<AppColors>()!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Your name',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'What should we call you?',
            filled: true,
            fillColor: c.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context
                    .read<AppState>()
                    .updateSettings(settings.copyWith(name: newName));
              }
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: TextStyle(
                    color: c.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final s = context.select((AppState app) => app.settings);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickAvatar(context),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                UserAvatar(
                  avatarUri: s.avatarUri,
                  name: s.name,
                  size: 54,
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: c.textPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.cardBg, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.camera_alt_rounded,
                        size: 10, color: c.pageBg),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _editNameDialog(context, s),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined,
                          size: 14, color: c.textTertiary),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stored on this device',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: c.textTertiary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _editNameDialog(context, s),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
