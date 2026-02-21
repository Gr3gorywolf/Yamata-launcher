import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FocusableElement extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  const FocusableElement({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.all(4),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<FocusableElement> createState() => _FocusableElementState();
}

class _FocusableElementState extends State<FocusableElement> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;
  bool _directionalMode = false;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _hasFocus = true);

        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 150),
          alignment: 0.4,
        );
      } else {
        setState(() => _hasFocus = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _directionalMode = true;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onPressed?.call();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final primaryGreen = theme.colorScheme.primary;

    final showFocusStyle = _hasFocus && _directionalMode;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: showFocusStyle ? primaryGreen : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
