import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        if (widget.onPressed != null) widget.onPressed!();
        try {
          if (widget.child.onTap != null) widget.child.onTap!();
          if (widget.child.onPressed != null) widget.child.onTap!();
        } catch (e) {}

        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
