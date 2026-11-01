import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedEntrance extends StatefulWidget {
  final Widget child;

  final int index;

  final Duration stagger;

  final Duration duration;

  final int maxStaggerIndex;

  final double offset;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 350),
    this.maxStaggerIndex = 12,
    this.offset = 16,
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  bool _decided = false;
  AnimationController? _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _startTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final position = Scrollable.maybeOf(context)?.position;
    final scrolled =
        position != null && position.hasPixels && position.pixels > 0;
    if (scrolled || widget.index > 3 * widget.maxStaggerIndex) return;

    final controller =
        AnimationController(vsync: this, duration: widget.duration);
    _controller = controller;
    _fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    final staggeredIndex = widget.index.clamp(0, widget.maxStaggerIndex);
    _startTimer =
        Timer(widget.stagger * staggeredIndex, () => controller.forward());
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
