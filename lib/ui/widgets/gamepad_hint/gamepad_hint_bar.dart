import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_hint/gamepad_button_glyph.dart';

class GamepadHintBar extends StatelessWidget {
  final List<GamepadHint> hints;

  const GamepadHintBar({
    super.key,
    required this.hints,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: hints
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GamepadButtonGlyph(hint: h),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
