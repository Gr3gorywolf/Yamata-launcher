import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';

class AppGamepadListener extends StatefulWidget {
  final Widget child;
  final FocusScopeNode? navScropeNode;
  final FocusScopeNode? contentScopeNode;

  const AppGamepadListener({
    super.key,
    required this.child,
    this.navScropeNode,
    this.contentScopeNode,
  });

  @override
  State<AppGamepadListener> createState() => _AppGamepadListenerState();
}

class _AppGamepadListenerState extends State<AppGamepadListener> {
  StreamSubscription<NormalizedGamepadEvent>? _subscription;
  final FocusNode _pageFocusNode = FocusNode();
  Timer? _directionRepeatTimer;
  TraversalDirection? _activeDirection;
  String? _activeDirectionalInputKey;

  static const double _buttonPressedThreshold = 0.5;
  static const double _axisActiveThreshold = 0.8;
  static const double _axisNeutralThreshold = 0.5;
  static const Duration _repeatInterval = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();

    _subscription = Gamepads.normalizedEvents.listen((event) {
      _handleGamepadEvent(event);
    });
  }

  void _handleTraversal(TraversalDirection direction) {
    if (TraversalDirection.left == direction) {
      final moved = FocusManager.instance.primaryFocus
              ?.focusInDirection(TraversalDirection.left) ??
          false;

      if (!moved) {
        widget.navScropeNode?.requestFocus();
      }

      return;
    }

    if (TraversalDirection.right == direction) {
      final moved = FocusManager.instance.primaryFocus
              ?.focusInDirection(TraversalDirection.right) ??
          false;

      if (!moved) {
        widget.contentScopeNode?.requestFocus();
      }

      return;
    }

    FocusManager.instance.primaryFocus?.focusInDirection(direction);
  }

  void _startDirectionalRepeat({
    required String inputKey,
    required TraversalDirection direction,
  }) {
    final isSameActiveInput =
        _activeDirectionalInputKey == inputKey && _activeDirection == direction;

    if (isSameActiveInput && _directionRepeatTimer?.isActive == true) {
      return;
    }

    _stopDirectionalRepeat();

    _activeDirectionalInputKey = inputKey;
    _activeDirection = direction;

    _handleTraversal(direction);

    _directionRepeatTimer = Timer.periodic(_repeatInterval, (_) {
      final activeDirection = _activeDirection;
      if (activeDirection == null) return;
      _handleTraversal(activeDirection);
    });
  }

  void _stopDirectionalRepeat({String? onlyForInputKey}) {
    if (onlyForInputKey != null &&
        _activeDirectionalInputKey != onlyForInputKey) {
      return;
    }

    _directionRepeatTimer?.cancel();
    _directionRepeatTimer = null;
    _activeDirection = null;
    _activeDirectionalInputKey = null;
  }

  bool _isAxisNeutral(double value) {
    return value > -_axisNeutralThreshold && value < _axisNeutralThreshold;
  }

  void _handleChangeTab(bool? next) {
    Provider.of<AppProvider>(context, listen: false).onChangeTab.add(next);
  }

  void _handleDirectionalInput({
    required String keyName,
    required double value,
  }) {
    switch (keyName) {
      case 'dpadUp':
        if (value > _buttonPressedThreshold) {
          _handleTraversal(TraversalDirection.up);
        }
        break;

      case 'dpadDown':
        if (value > _buttonPressedThreshold) {
          _handleTraversal(TraversalDirection.down);
        }
        break;

      case 'dpadLeft':
        if (value > _buttonPressedThreshold) {
          _handleTraversal(TraversalDirection.left);
        }
        break;

      case 'dpadRight':
        if (value > _buttonPressedThreshold) {
          _handleTraversal(TraversalDirection.right);
        }
        break;

      case 'leftStickX':
        if (_isAxisNeutral(value)) {
          _stopDirectionalRepeat(onlyForInputKey: keyName);
          return;
        }

        if (value > _axisActiveThreshold) {
          _startDirectionalRepeat(
            inputKey: keyName,
            direction: TraversalDirection.right,
          );
          return;
        }

        if (value < -_axisActiveThreshold) {
          _startDirectionalRepeat(
            inputKey: keyName,
            direction: TraversalDirection.left,
          );
          return;
        }
        break;

      case 'leftStickY':
        if (_isAxisNeutral(value)) {
          _stopDirectionalRepeat(onlyForInputKey: keyName);
          return;
        }

        if (value > _axisActiveThreshold) {
          _startDirectionalRepeat(
            inputKey: keyName,
            direction: TraversalDirection.up,
          );
          return;
        }

        if (value < -_axisActiveThreshold) {
          _startDirectionalRepeat(
            inputKey: keyName,
            direction: TraversalDirection.down,
          );
          return;
        }
        break;
    }
  }

  void _handleAndroidGamepadEvent(KeyEvent key) {
    print(
        "Android gamepad event: ${key.logicalKey.debugName} (${key.logicalKey.keyId})");
    const androidKeys = [
      LogicalKeyboardKey.gameButtonA,
      LogicalKeyboardKey.gameButtonB,
      LogicalKeyboardKey.gameButtonX,
      LogicalKeyboardKey.gameButtonY,
      LogicalKeyboardKey.gameButtonThumbLeft,
      LogicalKeyboardKey.gameButtonThumbRight,
      LogicalKeyboardKey.gameButtonLeft1,
      LogicalKeyboardKey.gameButtonRight1,
      LogicalKeyboardKey.gameButtonSelect,
      LogicalKeyboardKey.gameButtonStart,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ];

    if ((androidKeys.contains(key.logicalKey) ||
            key.logicalKey.debugName?.startsWith("game") == true) &&
        key is KeyDownEvent) {
      Provider.of<AppProvider>(context, listen: false).setUsingGamepad(true);
      if (key.logicalKey == LogicalKeyboardKey.gameButtonLeft1) {
        _handleChangeTab(false);
      }
      if (key.logicalKey == LogicalKeyboardKey.gameButtonRight1) {
        _handleChangeTab(true);
      }
    }
  }

  void _handleGamepadEvent(NormalizedGamepadEvent event) {
    try {
      final keyName = event.button?.name ?? event.axis?.name ?? 'unknown';
      final keyVal = event.value;

      print("Gamepad event: $keyName = $keyVal");
      Provider.of<AppProvider>(context, listen: false).setUsingGamepad(true);
      switch (keyName) {
        case 'dpadUp':
        case 'dpadDown':
        case 'dpadLeft':
        case 'dpadRight':
        case 'leftStickX':
        case 'leftStickY':
          _handleDirectionalInput(
            keyName: keyName,
            value: keyVal,
          );
          break;

        case 'a':
          if (keyVal > _buttonPressedThreshold) {
            _activateFocused();
          }
          break;

        case 'rightBumper':
          if (keyVal > _buttonPressedThreshold) {
            _handleChangeTab(true);
          }
          break;

        case 'leftBumper':
          if (keyVal > _buttonPressedThreshold) {
            _handleChangeTab(false);
          }
          break;

        case 'b':
        case 'back':
          if (keyVal > _buttonPressedThreshold) {
            Router.of(navigatorContext!).routerDelegate.popRoute();
          }
          break;
      }
    } catch (e, s) {
      debugPrint('Gamepad event error: $e');
      debugPrint('$s');
    }
  }

  void _activateFocused() {
    final focusNode = FocusManager.instance.primaryFocus;
    final context = focusNode?.context;

    if (context == null) return;

    try {
      final handled = Actions.maybeInvoke(
        context,
        const ActivateIntent(),
      );

      if (handled == null) {
        debugPrint('No ActivateAction found for focused widget');
        print(context.widget);

        if (context.widget is FocusableElement) {
          print('Focused widget is a FocusableElement, activating child');
          final fe = context.widget as FocusableElement;
          fe.activateChild();
        }

        if (context.widget is Focus) {
          print('Focused widget is a Focus, invoking enter key event');
          final fe = context.widget as Focus;

          fe.onKeyEvent?.call(
            fe.focusNode!,
            KeyDownEvent(
              logicalKey: LogicalKeyboardKey.enter,
              physicalKey: PhysicalKeyboardKey.enter,
              timeStamp: Duration(
                milliseconds: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
          );
        }
      }
    } catch (e, s) {
      debugPrint('Gamepad activate error: $e');
      debugPrint('$s');
    }
  }

  @override
  void dispose() {
    _directionRepeatTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      child: widget.child,
      focusNode: _pageFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && Platform.isAndroid) {
          _handleAndroidGamepadEvent(event);
        }
      },
    );
  }
}
