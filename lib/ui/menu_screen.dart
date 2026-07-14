// Main menu (the reading-guide landing screen). Establishes the ambient backdrop
// — a scene background image (contain + dark scrim) + the native ember layer
// (AshFx), the part that was the FPS bottleneck in the WebView. The guide content
// (episode scroller, arc rail, storyline selector) layers on top of this next.

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/image_assets.dart';
import 'ash_fx.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _backdrop;

  @override
  void initState() {
    super.initState();
    final bgs = backgroundPaths;
    if (bgs.isNotEmpty) _backdrop = bgs[Random().nextInt(bgs.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Solid base so edges/letterboxing read as the dark menu.
          const ColoredBox(color: Color(0xFF0D0D0F)),

          // Scene backdrop: a real bundled background, blurred-cover style with a
          // dark scrim. Falls back silently to the base color if it can't load.
          if (_backdrop != null)
            Image.asset(
              _backdrop!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC0D0D0F), Color(0x660D0D0F), Color(0xF00D0D0F)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // The ambient embers — native reimplementation of AshFX.vue.
          const Positioned.fill(child: AshFx()),

          // Foreground chrome (minimal for now).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    'Arknights',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFFE8C987),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Story Reader',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFB7B2A6),
                          letterSpacing: 6,
                        ),
                  ),
                  const Spacer(),
                  Center(
                    child: Text(
                      'Reading Guide',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0x99F3F0E7),
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
