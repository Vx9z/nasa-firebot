import 'dart:async';

import 'package:flutter/material.dart';

/// A self-contained intro splash: a green typewriter on pure black that types
/// "Firebot by Jellyfire", pauses, deletes it, then fades out to reveal the app.
/// It runs on top of the app while it loads and has no dependency on the rest
/// of the site — its only job is to make first load feel clean.
class IntroSplash extends StatefulWidget {
  final VoidCallback onFinished;
  const IntroSplash({super.key, required this.onFinished});

  @override
  State<IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<IntroSplash>
    with SingleTickerProviderStateMixin {
  static const String _full = 'Firebot by Jellyfire';
  static const String _first = 'Firebot by';
  static const Color _green = Color(0xFF00FF00);

  // Typewriter phases.
  static const int _typeFirst = 0;
  static const int _pauseAfterBy = 1;
  static const int _typeLast = 2;
  static const int _pauseFull = 3;
  static const int _delete = 4;
  static const int _done = 5;

  late final AnimationController _fade;
  Timer? _tick;
  Timer? _blink;
  String _text = '';
  int _phase = _typeFirst;
  bool _cursorOn = true;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    );
    _blink = Timer.periodic(const Duration(milliseconds: 480), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
    _advance();
  }

  void _advance() {
    final Duration delay;
    switch (_phase) {
      case _typeFirst:
      case _typeLast:
        delay = const Duration(milliseconds: 78);
        break;
      case _pauseAfterBy:
        delay = const Duration(milliseconds: 460);
        break;
      case _pauseFull:
        delay = const Duration(milliseconds: 560);
        break;
      case _delete:
        delay = const Duration(milliseconds: 34);
        break;
      default:
        return;
    }
    _tick = Timer(delay, _step);
  }

  void _step() {
    if (!mounted) return;
    setState(() {
      switch (_phase) {
        case _typeFirst:
          if (_text.length < _first.length) {
            _text = _first.substring(0, _text.length + 1);
          } else {
            _phase = _pauseAfterBy;
          }
          break;
        case _pauseAfterBy:
          _phase = _typeLast;
          break;
        case _typeLast:
          if (_text.length < _full.length) {
            _text = _full.substring(0, _text.length + 1);
          } else {
            _phase = _pauseFull;
          }
          break;
        case _pauseFull:
          _phase = _delete;
          break;
        case _delete:
          if (_text.isNotEmpty) {
            _text = _text.substring(0, _text.length - 1);
          } else {
            _phase = _done;
          }
          break;
      }
    });
    if (_phase == _done) {
      _finish();
    } else {
      _advance();
    }
  }

  void _finish() {
    _tick?.cancel();
    _blink?.cancel();
    _fade.reverse().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _blink?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _text + (_cursorOn ? '█' : ''),
                style: const TextStyle(
                  fontFamily: 'ShareTechMono',
                  fontSize: 44,
                  letterSpacing: 3,
                  color: _green,
                  height: 1.2,
                  shadows: [Shadow(color: _green, blurRadius: 16)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
