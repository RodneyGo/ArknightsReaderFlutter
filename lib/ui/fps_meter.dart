// Small FPS overlay, toggled by settings.debugPerf.
//
// Reads REAL engine frame timings via SchedulerBinding.addTimingsCallback, so it
// works in release builds (a plain Ticker counter would only measure how often we
// ask for frames, not how long they actually took). `max` is the worst
// total frame span in the sample window — the number that exposes jank.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FpsMeter extends StatefulWidget {
  const FpsMeter({super.key});

  @override
  State<FpsMeter> createState() => _FpsMeterState();
}

class _FpsMeterState extends State<FpsMeter> {
  final _window = Stopwatch();
  int _frames = 0;
  double _worstInWindow = 0;

  double _fps = 0;
  double _worstMs = 0;

  @override
  void initState() {
    super.initState();
    _window.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    _frames += timings.length;
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      if (ms > _worstInWindow) _worstInWindow = ms;
    }
    final elapsed = _window.elapsedMilliseconds;
    if (elapsed < 500) return;

    final fps = _frames * 1000 / elapsed;
    final worst = _worstInWindow;
    _frames = 0;
    _worstInWindow = 0;
    _window
      ..reset()
      ..start();
    if (mounted) {
      setState(() {
        _fps = fps;
        _worstMs = worst;
      });
    }
  }

  Color get _color {
    if (_fps >= 90) return const Color(0xFF7CFC9A); // high refresh
    if (_fps >= 55) return const Color(0xFFD8E86A);
    return const Color(0xFFE8836A); // dropping frames
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xB3000000),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '${_fps.toStringAsFixed(0)} fps · max ${_worstMs.toStringAsFixed(1)} ms',
          style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
