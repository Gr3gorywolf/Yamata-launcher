import 'package:flutter/material.dart';

class GlobalFocusHighlight extends StatefulWidget {
  final Widget child;

  const GlobalFocusHighlight({super.key, required this.child});

  @override
  State<GlobalFocusHighlight> createState() => _GlobalFocusHighlightState();
}

class _GlobalFocusHighlightState extends State<GlobalFocusHighlight>
    with TickerProviderStateMixin {
  Rect? _rect;
  FocusNode? _currentFocus;
  FocusNode? _lastFocus;

  bool _pointerMode = false;

  late AnimationController _pulseController;
  late AnimationController _scaleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    FocusManager.instance.addListener(_onFocusChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_scaleController);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _pulseController.dispose();
    _scaleController.dispose();
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

    if (_currentFocus != _lastFocus) {
      _lastFocus = _currentFocus;
      _scaleController.forward(from: 0);
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
  // Pointer handling
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
    final color = Theme.of(context).colorScheme.primary;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _enterPointerMode(),
      onPointerSignal: (_) => _enterPointerMode(),
      onPointerHover: (_) => _enterPointerMode(),
      child: Stack(
        children: [
          widget.child,
          if (_rect != null && !_pointerMode)
            Positioned(
              left: _rect!.left - 4,
              top: _rect!.top - 4,
              width: _rect!.width + 8,
              height: _rect!.height + 8,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _pulseController,
                    _scaleController,
                  ]),
                  builder: (_, __) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _pulseAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: color,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
