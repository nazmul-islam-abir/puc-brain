import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const AnimatedBackground({super.key, required this.child, this.isDark = true});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _animations = List.generate(8, (i) {
      return Tween<double>(begin: 0, end: 2 * math.pi).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(i * 0.125, 1.0, curve: Curves.easeInOutSine),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(_animations[0].value) * 0.4,
                math.cos(_animations[1].value) * 0.4,
              ),
              radius: 1.8,
              colors: widget.isDark
                  ? const [
                      Color(0xFF0B0E1A),
                      Color(0xFF1A1F2E),
                      Color(0xFF2D3748),
                      Color(0xFF1E2436),
                    ]
                  : const [
                      Color(0xFF667EEA),
                      Color(0xFF764BA2),
                      Color(0xFF9F7AEA),
                      Color(0xFF6B46C1),
                    ],
              stops: const [0.1, 0.3, 0.6, 0.9],
            ),
          ),
          child: Stack(
            children: [
              // Floating particles with better animation
              ...List.generate(30, (i) {
                return Positioned(
                  left: MediaQuery.of(context).size.width *
                      (0.1 + 0.8 * (0.5 + 0.5 * math.sin(_animations[i % 6].value + i * 0.8))),
                  top: MediaQuery.of(context).size.height *
                      (0.1 + 0.8 * (0.5 + 0.5 * math.cos(_animations[(i + 3) % 6].value + i))),
                  child: Container(
                    width: 2 + (i % 6) * 2,
                    height: 2 + (i % 6) * 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05 + (i % 5) * 0.01),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}