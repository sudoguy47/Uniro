import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/note.dart';

class FormattingSheet extends StatefulWidget {
  const FormattingSheet({
    super.key,
    required this.currentStyle,
    required this.onStyleChanged,
    required this.onAddBlock,
  });

  final NoteBlockStyle currentStyle;
  final ValueChanged<NoteBlockStyle> onStyleChanged;
  final ValueChanged<BlockType> onAddBlock;

  @override
  State<FormattingSheet> createState() => _FormattingSheetState();
}

class _FormattingSheetState extends State<FormattingSheet> {
  late NoteBlockStyle _style;

  static const List<String?> _textColors = [
    null, // Default
    '#D94F3D', // Red
    '#E8963C', // Orange
    '#4A7C59', // Green
    '#3B6EA5', // Blue
    '#8B5E9E', // Purple
    '#9E9E9E', // Gray
  ];

  static const List<String?> _highlightColors = [
    null, // None
    '#FFF176', // Soft Yellow
    '#A5D6A7', // Soft Green
    '#90CAF9', // Soft Blue
    '#F48FB1', // Soft Pink
    '#FFCC80', // Soft Orange
    '#E1BEE7', // Soft Lavender
  ];

  @override
  void initState() {
    super.initState();
    _style = widget.currentStyle;
  }

  void _updateStyle(NoteBlockStyle newStyle) {
    setState(() => _style = newStyle);
    widget.onStyleChanged(_style);
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('0xFF$clean'));
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1C1C1E);
    const cardDark = Color(0xFF2C2C2E);
    const textLight = Colors.white;
    const textMuted = Color(0xFF8E8E93);

    return Container(
      decoration: const BoxDecoration(
        color: bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Format',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textLight,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: textMuted, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 1: Font style & Alignment
          Row(
            children: [
              // Bold toggle
              _formatToggleButton(
                label: 'B',
                isSelected: _style.bold,
                isBold: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _updateStyle(_style.copyWith(bold: !_style.bold));
                },
              ),
              const SizedBox(width: 8),

              // Italic toggle
              _formatToggleButton(
                label: 'I',
                isSelected: _style.italic,
                isItalic: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _updateStyle(_style.copyWith(italic: !_style.italic));
                },
              ),
              const Spacer(),

              // Alignments
              Container(
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _alignButton(TextAlign.left, Icons.format_align_left_rounded),
                    _alignButton(TextAlign.center, Icons.format_align_center_rounded),
                    _alignButton(TextAlign.right, Icons.format_align_right_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Font size stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Size',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textLight),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, color: textLight, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (_style.fontSize > 14.0) {
                          HapticFeedback.lightImpact();
                          _updateStyle(_style.copyWith(fontSize: (_style.fontSize - 1).clamp(14.0, 24.0)));
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${_style.fontSize.toInt()} pt',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textLight,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: textLight, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (_style.fontSize < 24.0) {
                          HapticFeedback.lightImpact();
                          _updateStyle(_style.copyWith(fontSize: (_style.fontSize + 1).clamp(14.0, 24.0)));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Text Color
          const Text(
            'TEXT COLOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _textColors.map((hex) {
                final isSelected = _style.textColor == hex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _updateStyle(_style.copyWith(textColor: hex));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hex == null ? Colors.white : _parseHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: hex == null || hex == '#FFF176' ? Colors.black : Colors.white,
                          )
                        : (hex == null
                            ? const Icon(Icons.block, size: 14, color: Colors.grey)
                            : null),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Highlight Color
          const Text(
            'HIGHLIGHT COLOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _highlightColors.map((hex) {
                final isSelected = _style.highlightColor == hex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _updateStyle(_style.copyWith(highlightColor: hex));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hex == null ? cardDark : _parseHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.black)
                        : (hex == null
                            ? const Icon(Icons.block, size: 14, color: textMuted)
                            : null),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Section 5: Insert Block Type
          const Text(
            'INSERT BLOCK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _insertBlockBtn(
                  label: 'Text',
                  icon: Icons.notes_rounded,
                  type: BlockType.paragraph,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _insertBlockBtn(
                  label: 'Checklist',
                  icon: Icons.checklist_rounded,
                  type: BlockType.checklist,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _insertBlockBtn(
                  label: 'Quote',
                  icon: Icons.format_quote_rounded,
                  type: BlockType.quote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formatToggleButton({
    required String label,
    required bool isSelected,
    bool isBold = false,
    bool isItalic = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _alignButton(TextAlign align, IconData icon) {
    final isSelected = _style.alignment == align;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _updateStyle(_style.copyWith(alignment: align));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.black : const Color(0xFF8E8E93),
        ),
      ),
    );
  }

  Widget _insertBlockBtn({
    required String label,
    required IconData icon,
    required BlockType type,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF2C2C2E),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: () {
        HapticFeedback.lightImpact();
        widget.onAddBlock(type);
      },
    );
  }
}
