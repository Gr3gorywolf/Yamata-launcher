import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/constants/keyboard_keys_constants.dart';
import 'package:yamata_launcher/services/os_service.dart';

class AppKeyboardListener extends StatefulWidget {
  final Widget child;
  final Function(bool? next)? onChangeTab;
  const AppKeyboardListener({super.key, required this.child, this.onChangeTab});

  @override
  _AppKeyboardListenerState createState() => _AppKeyboardListenerState();
}

class _AppKeyboardListenerState extends State<AppKeyboardListener> {
  final FocusNode _pageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFocusNode.requestFocus();
    });
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;

    final context = focus.context;
    if (context == null) return false;

    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _handleBack() {
    Router.of(context).routerDelegate.popRoute();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _pageFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final keyboard = HardwareKeyboard.instance;
        final isCtrlPressed = keyboard.isControlPressed;
        final key = event.logicalKey;
        final isTyping = _isTextInputFocused();

        if (BACK_KEYS.contains(key)) {
          _handleBack();
          return;
        }

        if (key == LogicalKeyboardKey.tab) {
          if (Platform.isWindows ||
              Platform.isAndroid ||
              OsService.isGenericLinuxVariant) {
            if (!isCtrlPressed) {
              return;
            }
          }
          widget.onChangeTab?.call(null);
          return;
        }
        // Gamepad support for switching tabs
        if (key == LogicalKeyboardKey.gameButtonRight1 ||
            key == LogicalKeyboardKey.gameButtonSelect) {
          widget.onChangeTab?.call(true);
          return;
        }
        if (key == LogicalKeyboardKey.gameButtonLeft1) {
          widget.onChangeTab?.call(false);
          return;
        }

        if (isTyping) {
          if (key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.arrowUp) {
            FocusManager.instance.primaryFocus?.nextFocus();
            return;
          }
        }
      },
      child: widget.child,
    );
  }
}
