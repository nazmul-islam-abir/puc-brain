import 'package:flutter/material.dart';

class GlowingCard extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;

  const GlowingCard({
    super.key,
    required this.child,
    required this.color,
    this.onTap,
  });

  @override
  _GlowingCardState createState() => _GlowingCardState();
}

class _GlowingCardState extends State<GlowingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withOpacity(0.8),
                widget.color.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.5),
                blurRadius: 20 * _animation.value,
                spreadRadius: 5 * _animation.value,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}