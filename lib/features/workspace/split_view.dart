import 'package:flutter/material.dart';

import '../connection/ssh_session.dart';
import '../terminal/mosh_terminal_view.dart';
import '../terminal/terminal_view.dart';
import 'workspace_manager.dart';

/// Data for terminal drag
class TerminalDragData {
  final String terminalId;

  const TerminalDragData({required this.terminalId});
}

/// Renders a split node tree
class SplitView extends StatefulWidget {
  final SplitNode node;
  final void Function(String nodeId) onClose;
  final void Function(String nodeId, bool horizontal) onSplit;
  final void Function(String sourceId, String targetId, DropPosition position)? onMove;
  final String? sshFolderPath;
  final double focusZoom;

  const SplitView({
    super.key,
    required this.node,
    required this.onClose,
    required this.onSplit,
    this.onMove,
    this.sshFolderPath,
    this.focusZoom = 1.0,
  });

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  String? _draggingId;

  @override
  Widget build(BuildContext context) {
    // Build tree, filtering out the dragged node
    final filteredRoot = _draggingId != null
        ? _filterNode(widget.node, _draggingId!)
        : widget.node;

    if (filteredRoot == null) {
      // Only node is being dragged - show empty state with drop zone
      return _EmptyDropZone(
        draggingId: _draggingId!,
        onDrop: (sourceId) {
          // Will be placed back as root
        },
      );
    }

    return _buildNode(filteredRoot, null, null);
  }

  /// Filter out dragged node from tree, collapsing containers as needed
  SplitNode? _filterNode(SplitNode node, String excludeId) {
    if (node.id == excludeId) return null;

    if (node is SplitContainerNode) {
      final filtered = <SplitNode>[];
      final newRatios = <double>[];

      for (var i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final filteredChild = _filterNode(child, excludeId);
        if (filteredChild != null) {
          filtered.add(filteredChild);
          newRatios.add(node.ratios[i]);
        }
      }

      if (filtered.isEmpty) return null;
      if (filtered.length == 1) return filtered.first;

      // Normalize ratios
      final sum = newRatios.reduce((a, b) => a + b);
      final normalizedRatios = newRatios.map((r) => r / sum).toList();

      return SplitContainerNode(
        id: node.id,
        isHorizontal: node.isHorizontal,
        children: filtered,
        ratios: normalizedRatios,
      );
    }

    return node;
  }

  Widget _buildNode(SplitNode node, void Function(int)? onFocus, int? index, {bool isNested = false}) {
    if (node is TerminalNode) {
      return _DraggableTerminal(
        nodeId: node.id,
        isDragging: _draggingId == node.id,
        onDrop: widget.onMove != null
            ? (sourceId, position) => widget.onMove!(sourceId, node.id, position)
            : null,
        onFocusEnter: onFocus != null && index != null ? () => onFocus(index) : null,
        onFocusExit: onFocus != null ? () => onFocus(-1) : null,
        child: node.pane.config.protocol == ConnectionProtocol.mosh
            ? MoshTerminalView(
                key: node.pane.key,
                config: node.pane.config,
                nodeId: node.id,
                sshFolderPath: widget.sshFolderPath,
                onClose: () => widget.onClose(node.id),
                onSplitHorizontal: () => widget.onSplit(node.id, true),
                onSplitVertical: () => widget.onSplit(node.id, false),
                onDragStart: () => setState(() => _draggingId = node.id),
                onDragEnd: () => setState(() => _draggingId = null),
              )
            : SshTerminalView(
                key: node.pane.key,
                config: node.pane.config,
                nodeId: node.id,
                sshFolderPath: widget.sshFolderPath,
                onClose: () => widget.onClose(node.id),
                onSplitHorizontal: () => widget.onSplit(node.id, true),
                onSplitVertical: () => widget.onSplit(node.id, false),
                onDragStart: () => setState(() => _draggingId = node.id),
                onDragEnd: () => setState(() => _draggingId = null),
              ),
      );
    }

    if (node is SplitContainerNode) {
      return _SplitContainer(
        isHorizontal: node.isHorizontal,
        ratios: node.ratios,
        focusZoom: widget.focusZoom,
        isNested: isNested,
        childBuilder: (onChildFocus) {
          return node.children.asMap().entries.map((entry) {
            // Children of a container are nested (not full width AND not full height)
            return _buildNode(entry.value, onChildFocus, entry.key, isNested: true);
          }).toList();
        },
      );
    }

    return const SizedBox.shrink();
  }
}

/// Empty drop zone when only terminal is being dragged
class _EmptyDropZone extends StatelessWidget {
  final String draggingId;
  final void Function(String) onDrop;

  const _EmptyDropZone({
    required this.draggingId,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<TerminalDragData>(
      onAcceptWithDetails: (details) => onDrop(details.data.terminalId),
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDragOver
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: isDragOver ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'Drop here',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper for draggable terminal with drop zones
class _DraggableTerminal extends StatefulWidget {
  final String nodeId;
  final bool isDragging;
  final void Function(String sourceId, DropPosition position)? onDrop;
  final VoidCallback? onFocusEnter;
  final VoidCallback? onFocusExit;
  final Widget child;

  const _DraggableTerminal({
    required this.nodeId,
    required this.isDragging,
    this.onDrop,
    this.onFocusEnter,
    this.onFocusExit,
    required this.child,
  });

  @override
  State<_DraggableTerminal> createState() => _DraggableTerminalState();
}

class _DraggableTerminalState extends State<_DraggableTerminal> {
  DropPosition? _hoverPosition;
  Offset? _lastPointerPosition;
  final GlobalKey _key = GlobalKey();
  bool _isInCenterZone = false;

  // Edge margin where zoom won't activate (for resize handles)
  static const double _edgeMargin = 40.0;

  void _updateDropPosition() {
    if (_lastPointerPosition == null) return;

    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(_lastPointerPosition!);
    final size = box.size;

    // Calculate position relative to center
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final dx = local.dx - centerX;
    final dy = local.dy - centerY;

    // Determine zone by which axis has larger offset from center
    DropPosition pos;
    if (dx.abs() > dy.abs()) {
      pos = dx < 0 ? DropPosition.left : DropPosition.right;
    } else {
      pos = dy < 0 ? DropPosition.top : DropPosition.bottom;
    }

    if (pos != _hoverPosition) {
      setState(() => _hoverPosition = pos);
    }
  }

  void _updateCenterZone(PointerEvent event) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(event.position);
    final size = box.size;

    // Check if cursor is in center zone (not near edges)
    final inCenter = local.dx > _edgeMargin &&
        local.dx < size.width - _edgeMargin &&
        local.dy > _edgeMargin &&
        local.dy < size.height - _edgeMargin;

    if (inCenter != _isInCenterZone) {
      _isInCenterZone = inCenter;
      if (inCenter) {
        widget.onFocusEnter?.call();
      } else {
        widget.onFocusExit?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _key,
      onEnter: (_) {
        // Don't trigger focus on enter - wait for center zone check
      },
      onExit: (_) {
        if (_isInCenterZone) {
          _isInCenterZone = false;
          widget.onFocusExit?.call();
        }
      },
      onHover: (event) {
        _lastPointerPosition = event.position;
        _updateCenterZone(event);
      },
      child: DragTarget<TerminalDragData>(
        onWillAcceptWithDetails: (details) {
          return details.data.terminalId != widget.nodeId;
        },
        onAcceptWithDetails: (details) {
          if (_hoverPosition != null && widget.onDrop != null) {
            widget.onDrop!(details.data.terminalId, _hoverPosition!);
          }
          setState(() {
            _hoverPosition = null;
            _lastPointerPosition = null;
          });
        },
        onLeave: (_) => setState(() {
          _hoverPosition = null;
          _lastPointerPosition = null;
        }),
        onMove: (details) {
          // Use last pointer position from MouseRegion for accurate calculation
          _updateDropPosition();
        },
        builder: (context, candidateData, rejectedData) {
          final isDragOver = candidateData.isNotEmpty;

          return Stack(
            children: [
              widget.child,
              // Drop zone indicators
              if (isDragOver && _hoverPosition != null)
                Positioned.fill(
                  child: _DropZoneIndicator(position: _hoverPosition!),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Visual indicator for drop zone - shows the half where terminal will be inserted
class _DropZoneIndicator extends StatelessWidget {
  final DropPosition position;

  const _DropZoneIndicator({required this.position});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);
    final borderColor = Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: Align(
        alignment: _getAlignment(),
        child: FractionallySizedBox(
          widthFactor: _isHorizontal() ? 0.5 : 1.0,
          heightFactor: _isHorizontal() ? 1.0 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  bool _isHorizontal() =>
      position == DropPosition.left || position == DropPosition.right;

  Alignment _getAlignment() {
    switch (position) {
      case DropPosition.left:
        return Alignment.centerLeft;
      case DropPosition.right:
        return Alignment.centerRight;
      case DropPosition.top:
        return Alignment.topCenter;
      case DropPosition.bottom:
        return Alignment.bottomCenter;
    }
  }
}

/// Resizable split container with focus zoom
class _SplitContainer extends StatefulWidget {
  final bool isHorizontal;
  final List<double> ratios;
  final double focusZoom;
  final bool isNested; // true if this container is inside another split
  final List<Widget> Function(void Function(int) onFocus) childBuilder;

  const _SplitContainer({
    required this.isHorizontal,
    required this.ratios,
    required this.childBuilder,
    this.focusZoom = 1.0,
    this.isNested = false,
  });

  @override
  State<_SplitContainer> createState() => _SplitContainerState();
}

class _SplitContainerState extends State<_SplitContainer> {
  late List<double> _ratios;
  int _focusedIndex = -1;
  bool _mouseInZoomedOverlay = false;

  @override
  void initState() {
    super.initState();
    _ratios = List.from(widget.ratios);
  }

  @override
  void didUpdateWidget(covariant _SplitContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ratios.length != _ratios.length) {
      _ratios = List.from(widget.ratios);
      _focusedIndex = -1;
      _mouseInZoomedOverlay = false;
    }
  }

  void _onFocus(int index) {
    // Don't unfocus if mouse is still in zoomed overlay
    if (index == -1 && _mouseInZoomedOverlay) return;
    if (_focusedIndex == index) return;
    setState(() {
      _focusedIndex = index;
      if (index == -1) _mouseInZoomedOverlay = false;
    });
  }

  void _onZoomedOverlayEnter() {
    _mouseInZoomedOverlay = true;
  }

  void _onZoomedOverlayExit() {
    _mouseInZoomedOverlay = false;
    // Unfocus when leaving zoomed overlay
    setState(() {
      _focusedIndex = -1;
    });
  }

  // Check if zoom should be applied to this child
  bool _shouldZoom(int index) {
    if (widget.focusZoom <= 1.0) return false;
    if (_focusedIndex != index) return false;
    // Only zoom if nested (meaning not full width AND not full height)
    // A non-nested split means all children have full height (horizontal) or full width (vertical)
    return widget.isNested;
  }

  // Calculate alignment so zoom doesn't go beyond container bounds
  Alignment _calculateZoomAlignment(double offset, double childSize, double totalSize) {
    // How much the zoom will expand beyond original bounds
    final zoomExpand = childSize * (widget.focusZoom - 1) / 2;

    // Calculate alignment on main axis (horizontal for horizontal split)
    double mainAlign = 0.0;

    // Check if zoom would go beyond left/top edge
    if (offset - zoomExpand < 0) {
      // Align to left/top (expand only to right/bottom)
      mainAlign = -1.0;
    }
    // Check if zoom would go beyond right/bottom edge
    else if (offset + childSize + zoomExpand > totalSize) {
      // Align to right/bottom (expand only to left/top)
      mainAlign = 1.0;
    }
    // Otherwise center is fine
    else {
      mainAlign = 0.0;
    }

    // For cross axis, always align to top to avoid covering header
    // (cross axis is vertical for horizontal split, horizontal for vertical split)
    double crossAlign = -1.0; // Top/Left alignment to avoid header

    if (widget.isHorizontal) {
      return Alignment(mainAlign, crossAlign);
    } else {
      return Alignment(crossAlign, mainAlign);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dividerThickness = 2.0;
    final dividerColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
    final childWidgets = widget.childBuilder(_onFocus);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize =
            widget.isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        final dividerTotal = dividerThickness * (_ratios.length - 1);
        final availableSize = totalSize - dividerTotal;

        // Build base children (non-zoomed)
        final baseChildren = <Widget>[];
        Widget? zoomedChild;
        int? zoomedIndex;
        double? zoomedOffset;
        double? zoomedSize;
        Alignment? zoomAlignment;

        // Calculate offsets first
        final offsets = <double>[];
        double currentOffset = 0;
        for (var i = 0; i < childWidgets.length; i++) {
          offsets.add(currentOffset);
          currentOffset += availableSize * _ratios[i] + (i < childWidgets.length - 1 ? dividerThickness : 0);
        }

        for (var i = 0; i < childWidgets.length; i++) {
          final size = availableSize * _ratios[i];
          final shouldZoom = _shouldZoom(i);

          Widget child = childWidgets[i];

          if (shouldZoom) {
            // Store zoomed child for overlay rendering (z-index on top)
            zoomedIndex = i;
            zoomedOffset = offsets[i];
            zoomedSize = size;
            zoomAlignment = _calculateZoomAlignment(offsets[i], size, availableSize + dividerTotal);
            zoomedChild = _AnimatedZoomWrapper(
              scale: widget.focusZoom,
              alignment: zoomAlignment,
              onMouseEnter: _onZoomedOverlayEnter,
              onMouseExit: _onZoomedOverlayExit,
              child: child,
            );
            // Add placeholder for layout
            baseChildren.add(
              SizedBox(
                width: widget.isHorizontal ? size : null,
                height: widget.isHorizontal ? null : size,
                child: child, // Original child stays for layout
              ),
            );
          } else {
            baseChildren.add(
              SizedBox(
                width: widget.isHorizontal ? size : null,
                height: widget.isHorizontal ? null : size,
                child: child,
              ),
            );
          }

          if (i < childWidgets.length - 1) {
            baseChildren.add(
              GestureDetector(
                onPanUpdate: (details) => _onDrag(i, details, availableSize),
                child: MouseRegion(
                  cursor: widget.isHorizontal
                      ? SystemMouseCursors.resizeColumn
                      : SystemMouseCursors.resizeRow,
                  child: Container(
                    width: widget.isHorizontal ? dividerThickness : null,
                    height: widget.isHorizontal ? null : dividerThickness,
                    color: dividerColor,
                  ),
                ),
              ),
            );
          }
        }

        // Base layout
        Widget baseLayout = widget.isHorizontal
            ? Row(children: baseChildren)
            : Column(children: baseChildren);

        // If there's a zoomed child, render it on top using Stack
        if (zoomedChild != null && zoomedIndex != null && zoomedOffset != null && zoomedSize != null) {
          return Stack(
            clipBehavior: Clip.hardEdge, // Clip zoomed content to container bounds
            children: [
              baseLayout,
              // Zoomed overlay on top
              Positioned(
                left: widget.isHorizontal ? zoomedOffset : 0,
                top: widget.isHorizontal ? 0 : zoomedOffset,
                width: widget.isHorizontal ? zoomedSize : null,
                height: widget.isHorizontal ? null : zoomedSize,
                right: widget.isHorizontal ? null : 0,
                bottom: widget.isHorizontal ? 0 : null,
                child: zoomedChild,
              ),
            ],
          );
        }

        return baseLayout;
      },
    );
  }

  void _onDrag(int dividerIndex, DragUpdateDetails details, double totalSize) {
    setState(() {
      final delta = widget.isHorizontal ? details.delta.dx : details.delta.dy;
      final change = delta / totalSize;

      _ratios[dividerIndex] += change;
      _ratios[dividerIndex + 1] -= change;

      // Enforce minimum size
      const minRatio = 0.1;
      if (_ratios[dividerIndex] < minRatio) {
        _ratios[dividerIndex + 1] -= (minRatio - _ratios[dividerIndex]);
        _ratios[dividerIndex] = minRatio;
      }
      if (_ratios[dividerIndex + 1] < minRatio) {
        _ratios[dividerIndex] -= (minRatio - _ratios[dividerIndex + 1]);
        _ratios[dividerIndex + 1] = minRatio;
      }
    });
  }
}

/// Animated zoom wrapper with ease-out animation and smart alignment
class _AnimatedZoomWrapper extends StatefulWidget {
  final double scale;
  final Widget child;
  final Alignment alignment;
  final VoidCallback? onMouseEnter;
  final VoidCallback? onMouseExit;

  const _AnimatedZoomWrapper({
    required this.scale,
    required this.child,
    this.alignment = Alignment.center,
    this.onMouseEnter,
    this.onMouseExit,
  });

  @override
  State<_AnimatedZoomWrapper> createState() => _AnimatedZoomWrapperState();
}

class _AnimatedZoomWrapperState extends State<_AnimatedZoomWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.onMouseEnter != null ? (_) => widget.onMouseEnter!() : null,
      onExit: widget.onMouseExit != null ? (_) => widget.onMouseExit!() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: widget.alignment,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

