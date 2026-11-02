import 'dart:async';

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../core/theme/brand_colors.dart';
import '../../data/services/tutorial_service.dart';
import 'app_zoom.dart';

/// One step of a screen's guide: the tooltip's title and body.
class GuideStep {
  const GuideStep({required this.title, required this.description});
  final String title;
  final String description;
}

/// Hands a screen the showcase keys for its [ScreenGuide]. Wrap each target
/// control with [wrap] (by step index); the text and styling come from the
/// [ScreenGuide]'s `steps`.
class GuideHandle {
  const GuideHandle._(this._state);
  final _ScreenGuideState _state;

  /// Wraps [child] as showcase step [index]. Steps a screen doesn't wrap
  /// (e.g. a FAB that's hidden) are simply skipped when the guide runs.
  Widget wrap(int index, Widget child) => _state._wrap(index, child);
}

/// A one-time, per-screen showcase guide. The first time this screen is
/// opened after install it walks the user through its key controls, once,
/// tracked independently per [id] (a sidebar key, e.g. `'products'`).
///
/// Runs in its own showcaseview **scope** ([id]) so it never collides with
/// the shell's first-launch sidebar tour (the default scope). See CLAUDE.md →
/// First-Time Showcase Tour.
class ScreenGuide extends StatefulWidget {
  const ScreenGuide({
    super.key,
    required this.id,
    required this.steps,
    required this.builder,
  });

  /// Scope name and persistence id — the screen's sidebar key.
  final String id;
  final List<GuideStep> steps;
  final Widget Function(BuildContext context, GuideHandle guide) builder;

  @override
  State<ScreenGuide> createState() => _ScreenGuideState();
}

class _ScreenGuideState extends State<ScreenGuide> {
  late final List<GlobalKey> _keys =
      List.generate(widget.steps.length, (_) => GlobalKey());
  bool _registered = false;
  int _startedCount = 0;
  Timer? _pendingTimer;

  @override
  void initState() {
    super.initState();
    ShowcaseView.register(
      scope: widget.id,
      // A target that isn't mounted is skipped rather than crashing the tour.
      skipIfTargetNotPresent: true,
      onComplete: (index, _) {
        if (_startedCount > 0 && index == _startedCount - 1) {
          TutorialService.setScreenGuideShown(widget.id);
        }
      },
      onDismiss: (_) => TutorialService.setScreenGuideShown(widget.id),
    );
    _registered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleStart());
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    if (_registered) ShowcaseView.getNamed(widget.id).unregister();
    super.dispose();
  }

  void _scheduleStart() {
    if (!mounted) return;
    _pendingTimer = Timer(const Duration(milliseconds: 700), _maybeStart);
  }

  Future<void> _maybeStart([int attempt = 0]) async {
    if (!mounted) return;
    if (await TutorialService.isScreenGuideShown(widget.id)) return;
    if (!mounted) return;

    // Showcaseview positions its tooltip with an unanchored localToGlobal,
    // which is wrong under the Display-size zoom; a zoomed app isn't a fresh
    // install anyway, so mark it shown and skip (same rule as the sidebar tour).
    if (AppZoomScope.scaleOf(context) != 1.0) {
      await TutorialService.setScreenGuideShown(widget.id);
      return;
    }

    // Never overlay the shell's first-launch sidebar tour (default scope).
    // Retry briefly; if it's still running, leave it for the next open
    // (don't mark shown), so the guide is never silently lost.
    if (ShowcaseView.get().isShowcaseRunning) {
      if (attempt >= 5) return;
      _pendingTimer = Timer(
        const Duration(milliseconds: 600),
        () => _maybeStart(attempt + 1),
      );
      return;
    }

    final keys = [
      for (final k in _keys)
        if (k.currentContext != null) k,
    ];
    if (keys.isEmpty) return; // targets not built; retry on the next open
    _startedCount = keys.length;
    ShowcaseView.getNamed(widget.id).startShowCase(keys);
  }

  Widget _wrap(int index, Widget child) {
    final step = widget.steps[index];
    final cs = Theme.of(context).colorScheme;
    final brand = context.brand;
    return Showcase(
      key: _keys[index],
      scope: widget.id,
      title: step.title,
      description: step.description,
      tooltipBackgroundColor: brand.primary,
      textColor: brand.onPrimary,
      titleTextStyle: TextStyle(
        color: brand.onPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      descTextStyle: TextStyle(color: brand.onPrimary, fontSize: 13),
      tooltipBorderRadius: BorderRadius.circular(12),
      targetBorderRadius: BorderRadius.circular(12),
      targetPadding: const EdgeInsets.all(6),
      overlayColor: cs.scrim,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, GuideHandle._(this));
}
