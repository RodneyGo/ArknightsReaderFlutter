// Main menu (the reading-guide landing screen). This first slice establishes the
// ambient backdrop — a dark scene gradient + the native ember layer (AshFx) —
// which is the part that was the FPS bottleneck in the WebView. The guide content
// (episode scroller, arc rail, storyline selector) layers on top of this next,
// once the asset pipeline for banner/background images is ported.

import 'package:flutter/material.dart';

import 'ash_fx.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder scene backdrop (a per-episode image lands with the asset
          // pipeline). Ground-hugging warm glow at the bottom, like the menu art.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1.15),
                radius: 1.3,
                colors: [Color(0xFF2A1B12), Color(0xFF121013), Color(0xFF0D0D0F)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // The ambient embers — the native reimplementation of AshFX.vue.
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
