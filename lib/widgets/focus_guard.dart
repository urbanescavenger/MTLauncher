import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Restores D-pad focus when the focus manager's primary focus is null or on
/// the root scope after (re)builds, page flips, dialog dismissal or app resume.
///
/// The launcher has no top-level FocusScope and relies on `autofocus` on leaf
/// widgets, which fires only once per mount; when the focused node is disposed
/// (e.g. the empty-state card being replaced by the populated row) focus falls
/// back to the root scope, where every key press is dead. This guard gives the
/// launcher a deterministic recovery path.
class FocusGuard extends StatefulWidget {
  final Widget child;

  /// False while the launcher body is hidden (alternative clock view) so the
  /// guard never focuses an offstage card.
  final bool enabled;

  const FocusGuard({super.key, required this.child, this.enabled = true});

  @override
  State<FocusGuard> createState() => _FocusGuardState();
}

class _FocusGuardState extends State<FocusGuard> with WidgetsBindingObserver {
  final FocusNode _bodyNode = FocusNode(canRequestFocus: false);
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The focus manager notifies listeners whenever the applied focus changes,
    // including "focus dropped to the root scope because the focused node died".
    FocusManager.instance.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleCheck);
    WidgetsBinding.instance.removeObserver(this);
    _bodyNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also fires when a dialog route is pushed/popped on top of this route.
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(FocusGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from a launched app (or re-entering the HOME launcher)
    // routinely leaves the previous focus state behind.
    if (state == AppLifecycleState.resumed) _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _recoverIfLost();
    });
  }

  void _recoverIfLost() {
    if (!mounted || !widget.enabled) return;

    // Never steal focus from a dialog/panel pushed on top of the home route.
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final FocusManager manager = FocusManager.instance;
    final FocusNode? primary = manager.primaryFocus;
    // A primary focus whose parent is null is an orphan: the widget that owned
    // it was unmounted (e.g. an app removed while its info panel was open, and
    // the route pop then re-focused the stale node). Keys reach its leftover
    // handlers but traversal is dead, so treat it as lost like the root scope.
    if (primary != null && primary != manager.rootScope && primary.parent != null) return;

    // Focus is lost: hand it to the first focusable node in the body, in tree
    // order (the first app card of the current page).
    for (final FocusNode node in _bodyNode.traversalDescendants) {
      if (node.canRequestFocus) {
        node.requestFocus();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _bodyNode,
        canRequestFocus: false,
        child: widget.child,
      );
}