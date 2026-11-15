part of '../builder/reorderable_animated_builder.dart';

class ReorderableAnimatedContent extends StatefulWidget {
  final int index;
  final ItemTransitionData transitionData;
  final Widget child;
  final Function()? updateItemPosition;
  final CapturedThemes? capturedThemes;

  const ReorderableAnimatedContent({
    super.key,
    required this.index,
    required this.transitionData,
    required this.child,
    this.updateItemPosition,
    required this.capturedThemes,
  });

  @override
  State<ReorderableAnimatedContent> createState() => ReorderableAnimatedContentState();
}

class ReorderableAnimatedContentState extends State<ReorderableAnimatedContent> with SingleTickerProviderStateMixin {
  late ReorderableAnimatedBuilderState listState;

  Offset _targetOffset = Offset.zero;
  Offset _currentOffset = Offset.zero;
  Offset _velocity = Offset.zero;
  Ticker? _springTicker;
  Duration? _lastSpringElapsed;

  bool _dragging = false;

  bool get dragging => _dragging;

  set dragging(bool dragging) {
    if (mounted) {
      setState(() {
        _dragging = dragging;
      });
    }
  }

  Size _dragSize = Size.zero;

  set dragSize(Size itemSize) {
    if (mounted) {
      setState(() {
        _dragSize = itemSize;
      });
    }
  }

  int get index => widget.index;
  bool visible = true;

  @override
  void initState() {
    listState = ReorderableAnimatedBuilder.of(context);
    listState.registerItem(this);
    visible = widget.transitionData.visible;

    _updateItemPosition();

    Future.delayed(kAnimationDuration).then((value) {
      visible = true;
      rebuild();
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ReorderableAnimatedContent oldWidget) {
    if (oldWidget.index != widget.index) {
      listState.unregisterItem(oldWidget.index, this);
      listState.registerItem(this);
    }
    if (oldWidget.index != widget.index && !_dragging) {
      // Reset this flag to false after the drag is completed and items are reordered
      listState._isDragging = false;
      _updateAnimationTranslation();
    } else {
      _updateItemPosition();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _updateAnimationTranslation() {
    if (widget.transitionData.animate) {
      final Offset offsetDiff = (widget.transitionData.startOffset + _currentOffset) - widget.transitionData.endOffset;
      if (offsetDiff.dx != 0 || offsetDiff.dy != 0) {
        _currentOffset = offsetDiff;
        _targetOffset = Offset.zero;
        _ensureSpringRunning(onSettled: widget.updateItemPosition);
      }
    }
  }

  VoidCallback? _onSpringSettled;

  void _ensureSpringRunning({VoidCallback? onSettled}) {
    if (onSettled != null) {
      _onSpringSettled = onSettled;
    }
    _springTicker ??= createTicker(_onSpringTick);
    if (!_springTicker!.isActive) {
      _lastSpringElapsed = null;
      _springTicker!.start();
    }
  }

  void _stopSpring() {
    _springTicker?.stop();
    _lastSpringElapsed = null;
    _onSpringSettled = null;
  }

  void _onSpringTick(Duration elapsed) {
    final Duration? prev = _lastSpringElapsed;
    _lastSpringElapsed = elapsed;
    final double rawDt = prev == null ? (1.0 / 60.0) : (elapsed - prev).inMicroseconds / 1000000.0;
    final double dt = rawDt.clamp(0.0, 0.032);

    // Critically damped 2D spring preserves momentum on mid-flight target
    // changes and settles smoothly without linear start/stop jerks.
    const double stiffness = 380.0;
    const double damping = 39.0;
    const int subSteps = 2;
    final double subDt = dt / subSteps;
    for (int i = 0; i < subSteps; i++) {
      final Offset displacement = _currentOffset - _targetOffset;
      final Offset accel = (-displacement * stiffness) - (_velocity * damping);
      _velocity += accel * subDt;
      _currentOffset += _velocity * subDt;
    }

    if ((_currentOffset - _targetOffset).distanceSquared < 0.04 && _velocity.distanceSquared < 4.0) {
      _currentOffset = _targetOffset;
      _velocity = Offset.zero;
      final VoidCallback? callback = _onSpringSettled;
      _stopSpring();
      callback?.call();
    }
    rebuild();
  }

  Offset get offset => _currentOffset;

  void updateForGap(bool animate) {
    if (!mounted) return;
    final Offset newTargetOffset = listState.calculateNextDragOffset(index);
    if (newTargetOffset == _targetOffset) return;
    _targetOffset = newTargetOffset;

    if (animate) {
      _ensureSpringRunning();
    } else {
      _stopSpring();
      _currentOffset = _targetOffset;
      _velocity = Offset.zero;
      rebuild();
    }
  }

  void _updateItemPosition() {
    if (mounted) {
      widget.updateItemPosition?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    listState.registerItem(this);
    return Visibility(
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      visible: visible && !_dragging,
      child: Transform.translate(
        offset: offset,
        child: !_dragging ? widget.child : SizedBox.fromSize(size: _dragSize),
      ),
    );
  }

  void resetGap() {
    _stopSpring();
    _currentOffset = Offset.zero;
    _targetOffset = Offset.zero;
    _velocity = Offset.zero;
    rebuild();
  }

  Rect targetGeometryNonOffset() {
    final RenderBox itemRenderBox = context.findRenderObject()! as RenderBox;
    final Offset itemPosition = itemRenderBox.localToGlobal(Offset.zero);
    return itemPosition & itemRenderBox.size;
  }

  Rect targetGeometry() {
    final RenderBox itemRenderBox = context.findRenderObject()! as RenderBox;
    final Offset itemPosition = itemRenderBox.localToGlobal(Offset.zero) + _targetOffset;
    return itemPosition & itemRenderBox.size;
  }

  void rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    listState.unregisterItem(index, this);
    _springTicker?.dispose();
    _springTicker = null;
    super.dispose();
  }

  @override
  void deactivate() {
    listState.unregisterItem(index, this);
    super.deactivate();
  }
}
