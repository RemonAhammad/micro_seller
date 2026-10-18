import 'dart:async';

import 'package:flutter/material.dart';

/// Fades + slides a child upward on mount. Use with `index` for staggered
/// list/grid entrances:
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (_, i) => AnimatedEntrance(
///     index: i,
///     child: MyCard(...),
///   ),
/// )
/// ```
///
/// Tuned for POS feel: short total duration, small offset. Only a list's
/// first screenful animates: an item mounted while its [Scrollable] is
/// scrolled away from the top, or with an index past `3 * maxStaggerIndex`,
/// shows its child immediately — so a fling never reveals blank, still-waiting
/// rows. That choice is made once, when the item mounts.
class AnimatedEntrance extends StatefulWidget {
  final Widget child;

  /// Item index in a list/grid. Used to stagger the animation start.
  final int index;

  /// Per-item stagger delay. Default 40ms feels snappy without dragging.
  final Duration stagger;

  /// Animation duration. Default 350ms.
  final Duration duration;

  /// Maximum index to stagger. Items beyond this all share the cap delay,
  /// so a list of 500 doesn't take 20 seconds to fully appear.
  final int maxStaggerIndex;

  /// Vertical offset to slide from, in logical pixels. Default 16.
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

  // Not initState: the scroll position is an inherited lookup.
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
      begin: Offset(0, widget.offset / 100), // FractionalOffset; 16/100 ~ 16% of own height
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
