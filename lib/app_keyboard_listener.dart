import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/keyboard_keys_constants.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/services/os_service.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_handler.dart';

class AppKeyboardListener extends StatefulWidget {
  final Widget child;
  final Function(bool? next)? onChangeTab;

  const AppKeyboardListener({
    super.key,
    required this.child,
    this.onChangeTab,
  });

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
    Router.of(navigatorContext!).routerDelegate.popRoute();
  }

  // 🔥 LOG GLOBAL
  void _handleSetUsingKeyboardAndMouse(String type, [dynamic data]) {
    Provider.of<AppProvider>(context, listen: false).setUsingGamepad(false);
  }

  void _handleSetUsingGamepad(String type, [dynamic data]) {
    Provider.of<AppProvider>(context, listen: false).setUsingGamepad(true);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _handleSetUsingKeyboardAndMouse('pointerDown', event.kind);
      },
      onPointerMove: (event) {
        _handleSetUsingKeyboardAndMouse('pointerMove', event.kind);
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _handleSetUsingKeyboardAndMouse('scroll', event.scrollDelta);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,

        // 📱 TAP (touch / mouse click)
        onTap: () => _handleSetUsingKeyboardAndMouse('tap'),

        onPanStart: (_) => _handleSetUsingKeyboardAndMouse('panStart'),
        onPanUpdate: (_) => _handleSetUsingKeyboardAndMouse('panUpdate'),
        onPanEnd: (_) => _handleSetUsingKeyboardAndMouse('panEnd'),

        child: KeyboardListener(
          focusNode: _pageFocusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (Platform.isAndroid &&
                  AndroidGamepadKeys.contains(event.logicalKey)) {
                _handleSetUsingGamepad('keyDown', event.logicalKey.keyLabel);
              } else {
                _handleSetUsingKeyboardAndMouse(
                    'keyDown', event.logicalKey.keyLabel);
              }
            }

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
                if (!isCtrlPressed) return;
              }
              widget.onChangeTab?.call(null);
              return;
            }

            if (isTyping) {
              if (key == LogicalKeyboardKey.arrowDown) {
                FocusManager.instance.primaryFocus?.nextFocus();
                return;
              }
              if (key == LogicalKeyboardKey.arrowUp) {
                FocusManager.instance.primaryFocus?.previousFocus();
                return;
              }
            }
          },
          child: widget.child,
        ),
      ),
    );
  }
}
