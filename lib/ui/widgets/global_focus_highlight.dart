import 'package:flutter/material.dart';

class GlobalFocusHighlight extends StatefulWidget {
  final Widget child;

  const GlobalFocusHighlight({super.key, required this.child});

  @override
  State<GlobalFocusHighlight> createState() => _GlobalFocusHighlightState();
}

class _GlobalFocusHighlightState extends State<GlobalFocusHighlight> {
  Rect? _rect;
  FocusNode? _currentFocus;

  bool _pointerMode = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  // ======================
  // Focus handling
  // ======================

  void _onFocusChange() {
    _currentFocus = FocusManager.instance.primaryFocus;

    if (_currentFocus != null) {
      _pointerMode = false;
    }

    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateRect();

      if (_currentFocus?.hasFocus == true && !_pointerMode) {
        _scheduleUpdate();
      }
    });
  }

  void _updateRect() {
    if (_pointerMode) return;

    final context = _currentFocus?.context;

    if (context == null) {
      setState(() => _rect = null);
      return;
    }

    if (context.findAncestorWidgetOfExactType<EditableText>() != null) {
      setState(() => _rect = null);
      return;
    }

    final render = context.findRenderObject();
    if (render is RenderBox && render.hasSize && render.attached) {
      final offset = render.localToGlobal(Offset.zero);
      final newRect = offset & render.size;

      if (_rect != newRect) {
        setState(() => _rect = newRect);
      }
    }
  }

  // ======================
  // Pointer handling (mouse)
  // ======================

  void _enterPointerMode() {
    if (!_pointerMode) {
      setState(() {
        _pointerMode = true;
        _rect = null;
      });
    }
  }

  // ======================
  // UI
  // ======================

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _enterPointerMode(),
      onPointerSignal: (_) => _enterPointerMode(),
      onPointerHover: (_) => _enterPointerMode(),
      child: Stack(
        children: [
          widget.child,

          // Highlight global
          if (_rect != null && !_pointerMode)
            Positioned(
              left: _rect!.left - 4,
              top: _rect!.top - 4,
              width: _rect!.width + 8,
              height: _rect!.height + 8,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
