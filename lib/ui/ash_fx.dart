// Ambient ember layer — the native Flutter reimplementation of the web app's
// AshFX.vue (the decorative rising/flickering embers behind the main menu).
//
// This is the effect that tanked FPS in the WebView (CSS-animated DOM nodes +
// compositing). Here it's a single GPU-composited layer: one Ticker drives a
// CustomPainter that draws all embers per frame, wrapped in a RepaintBoundary so
// it never triggers layout/paint on the rest of the tree.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

class _Ember {
  final double left; // 0..1 of width
  final double size; // px (diameter at scale 1)
  final Color color; // includes the peak alpha
  final double op; // rise-envelope peak opacity (0.5..1)
  final double riseVh; // rise distance, % of height
  final double dur; // rise duration, s
  final double delay; // rise delay, s (negative = already in flight)
  final double sway; // horizontal wobble amplitude, px
  final double swd; // sway half-period, s
  final double swdl; // sway delay, s
  final double fld; // flicker half-period, s
  final double fldl; // flicker delay, s

  const _Ember({
    required this.left,
    required this.size,
    required this.color,
    required this.op,
    required this.riseVh,
    required this.dur,
    required this.delay,
    required this.sway,
    required this.swd,
    required this.swdl,
    required this.fld,
    required this.fldl,
  });
}

// Warm fire palette (peak alpha baked in) — mostly orange with a few hot-white
// sparks and the odd dim ash, matching AshFX.vue.
const _colors = <Color>[
  Color.fromARGB(242, 255, 138, 58),
  Color.fromARGB(242, 255, 110, 45),
  Color.fromARGB(235, 255, 168, 80),
  Color.fromARGB(230, 233, 120, 52),
];
const _hot = Color.fromARGB(250, 255, 214, 150);
const _ash = Color.fromARGB(140, 196, 188, 176);

List<_Ember> _generate(int count) {
  final rng = math.Random();
  double rnd(double a, double b) => a + rng.nextDouble() * (b - a);
  return List.generate(count, (_) {
    final roll = rng.nextDouble();
    final c = roll < 0.12
        ? _hot
        : roll < 0.20
            ? _ash
            : _colors[rng.nextInt(_colors.length)];
    return _Ember(
      left: rnd(0, 1),
      size: rnd(5, 11),
      color: c,
      op: rnd(0.5, 1),
      riseVh: rnd(60, 118),
      dur: rnd(6, 15),
      delay: -rnd(0, 15),
      sway: rnd(10, 30),
      swd: rnd(1.6, 3.4),
      swdl: -rnd(0, 3),
      fld: rnd(0.4, 1.3),
      fldl: -rnd(0, 2),
    );
  });
}

class AshFx extends StatefulWidget {
  /// Freeze the animation (e.g. when a modal is up / the view is inactive).
  final bool paused;
  final int count;

  const AshFx({super.key, this.paused = false, this.count = 18});

  @override
  State<AshFx> createState() => _AshFxState();
}

class _AshFxState extends State<AshFx> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Ember> _embers;
  final ValueNotifier<double> _t = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _embers = _generate(widget.count);
    _ticker = createTicker((elapsed) {
      _t.value = elapsed.inMicroseconds / 1e6;
    });
    if (!widget.paused) _ticker.start();
  }

  @override
  void didUpdateWidget(AshFx old) {
    super.didUpdateWidget(old);
    if (widget.paused && _ticker.isActive) {
      _ticker.stop();
    } else if (!widget.paused && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: _EmberPainter(_embers, _t),
          ),
        ),
      ),
    );
  }
}

class _EmberPainter extends CustomPainter {
  final List<_Ember> embers;
  final ValueListenable<double> time;

  _EmberPainter(this.embers, this.time) : super(repaint: time);

  static double _frac(double x) => x - x.floorToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final paint = Paint();
    for (final e in embers) {
      final p = _frac((t - e.delay) / e.dur); // 0..1 rise progress
      final scale = 1 - 0.65 * p; // 1 -> 0.35
      final risePx = e.riseVh / 100 * size.height;
      final cy = size.height + 14 - p * risePx;
      final sx = e.sway * math.sin(2 * math.pi * (t - e.swdl) / (2 * e.swd));
      final cx = e.left * size.width + sx;

      // rise opacity envelope: 0 -> op (by 8%) -> op (until 80%) -> 0
      final double env;
      if (p < 0.08) {
        env = p / 0.08 * e.op;
      } else if (p < 0.80) {
        env = e.op;
      } else {
        env = (1 - (p - 0.80) / 0.20) * e.op;
      }
      // flicker: 0.3 -> 1
      final flick = 0.3 +
          0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * (t - e.fldl) / (2 * e.fld)));

      final alpha = (env * flick * e.color.a).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final radius = e.size * scale / 2;
      if (radius <= 0) continue;
      final center = Offset(cx, cy);
      final core = e.color.withValues(alpha: alpha);
      // Soft glow: solid core to 22%, fading to transparent by 78% (closest-side).
      paint.shader = RadialGradient(
        colors: [core, core, core.withValues(alpha: 0)],
        stops: const [0.0, 0.22, 0.78],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => false; // repaint driven by `time`
}
