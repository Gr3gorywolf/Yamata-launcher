import 'package:flutter/material.dart';

enum GamepadGlyph {
  a,
  b,
  x,
  y,
  dpad,
  leftStick,
  rightStick,
  lb,
  rb,
  start,
  select,
}

class GamepadButtonGlyph extends StatelessWidget {
  final GamepadHint hint;

  const GamepadButtonGlyph({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildGlyph(hint.glyph),
        const SizedBox(width: 6),
        Text(
          hint.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGlyph(GamepadGlyph glyph) {
    switch (glyph) {
      case GamepadGlyph.a:
        return _circle("A", Colors.green);
      case GamepadGlyph.b:
        return _circle("B", Colors.red);
      case GamepadGlyph.x:
        return _circle("X", Colors.blue);
      case GamepadGlyph.y:
        return _circle("Y", Colors.yellow);
      case GamepadGlyph.dpad:
        return _box("↕");
      case GamepadGlyph.leftStick:
        return _box("LS");
      case GamepadGlyph.rightStick:
        return _box("RS");
      case GamepadGlyph.lb:
        return _box("LB");
      case GamepadGlyph.rb:
        return _box("RB");
      case GamepadGlyph.start:
        return _box("≡");
      case GamepadGlyph.select:
        return _box("⧉");
    }
  }

  Widget _circle(String text, Color color) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _box(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class GamepadHint {
  final GamepadGlyph glyph;
  final String label;

  GamepadHint({
    required this.glyph,
    required this.label,
  });
}
