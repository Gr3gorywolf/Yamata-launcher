import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/app_provider.dart';

class FocusMemory {
  static String? lastFocusId;
}

class FocusableElement extends StatefulWidget {
  final dynamic child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final String? focusId;
  final FocusNode? focusNode;
  final bool preventChildrenFocus;

  const FocusableElement({
    super.key,
    required this.child,
    this.onPressed,
    this.focusId,
    this.focusNode,
    this.preventChildrenFocus = true,
    this.padding = const EdgeInsets.all(4),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  void activateChild() {
    if (onPressed != null) onPressed!();
    try {
      if (child.onTap != null) child.onTap!();
      if (child.onPressed != null) child.onTap!();
    } catch (e) {}
  }

  @override
  State<FocusableElement> createState() => _FocusableElementState();
}

class _FocusableElementState extends State<FocusableElement> {
  FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;
  bool _directionalMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    }
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _directionalMode = true;
        setState(() => _hasFocus = true);

        if (widget.focusId != null) {
          FocusMemory.lastFocusId = widget.focusId!;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 180),
            alignment: 0.35,
            curve: Curves.easeOut,
          );
        });
      } else {
        setState(() => _hasFocus = false);
      }
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _directionalMode = true;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.activateChild();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isUsingGamepad =
        context.select<AppProvider, bool>((p) => p.isUsingGamepad);

    if (!isUsingGamepad) {
      if (widget.onPressed == null) {
        return widget.child;
      }

      return GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      descendantsAreFocusable: !widget.preventChildrenFocus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      ),
    );
  }
}
