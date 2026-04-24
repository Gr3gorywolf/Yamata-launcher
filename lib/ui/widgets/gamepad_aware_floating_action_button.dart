import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_hint/gamepad_button_glyph.dart';

class GamepadAwareFloatingActionButton extends StatefulWidget {
  String title;
  IconData icon;
  Function()? onPressed;
  GamepadAwareFloatingActionButton(
      {super.key, required this.title, required this.icon, this.onPressed});

  @override
  State<GamepadAwareFloatingActionButton> createState() =>
      _GamepadAwareFloatingActionButtonState();
}

class _GamepadAwareFloatingActionButtonState
    extends State<GamepadAwareFloatingActionButton> {
  StreamSubscription<String?>? onGamepadButtonPressed;

  @override
  void initState() {
    super.initState();
    onGamepadButtonPressed = Provider.of<AppProvider>(context, listen: false)
        .onGamepadButtonPressed
        .stream
        .listen((keyName) {
      if (keyName == "y") {
        widget.onPressed?.call();
      }
    });
  }

  @override
  void dispose() {
    onGamepadButtonPressed?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, child) {
      return FloatingActionButton.extended(
        onPressed: widget.onPressed,
        icon: provider.isUsingGamepad
            ? GamepadButtonGlyph(
                hint: GamepadHint(label: "", glyph: GamepadGlyph.y),
              )
            : Icon(widget.icon),
        label: Text(widget.title),
      );
    });
  }
}
