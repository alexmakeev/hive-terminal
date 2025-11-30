import 'dart:io';

import 'package:flutter/material.dart';

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

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

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

  Widget _buildNode(SplitNode node, void Function(int)? onFocus, int? index) {
    if (node is TerminalNode) {
      return _DraggableTerminal(
        nodeId: node.id,
        isDragging: _draggingId == node.id,
        onDragStart: () => setState(() => _draggingId = node.id),
        onDragEnd: () => setState(() => _draggingId = null),
        onDrop: widget.onMove != null
            ? (sourceId, position) => widget.onMove!(sourceId, node.id, position)
            : null,
        onFocusEnter: onFocus != null && index != null ? () => onFocus(index) : null,
        onFocusExit: onFocus != null ? () => onFocus(-1) : null,
        child: SshTerminalView(
          key: node.pane.key,
          config: node.pane.config,
          nodeId: node.id,
          sshFolderPath: widget.sshFolderPath,
          onClose: () => widget.onClose(node.id),
          onSplitHorizontal: _isDesktop ? () => widget.onSplit(node.id, true) : null,
          onSplitVertical: _isDesktop ? () => widget.onSplit(node.id, false) : null,
        ),
      );
    }

    if (node is SplitContainerNode) {
      return _SplitContainer(
        isHorizontal: node.isHorizontal,
        ratios: node.ratios,
        focusZoom: widget.focusZoom,
        childBuilder: (onChildFocus) {
          return node.children.asMap().entries.map((entry) {
            return _buildNode(entry.value, onChildFocus, entry.key);
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
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final void Function(String sourceId, DropPosition position)? onDrop;
  final VoidCallback? onFocusEnter;
  final VoidCallback? onFocusExit;
  final Widget child;

  const _DraggableTerminal({
    required this.nodeId,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragEnd,
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.onFocusEnter != null ? (_) => widget.onFocusEnter!() : null,
      onExit: widget.onFocusExit != null ? (_) => widget.onFocusExit!() : null,
      child: DragTarget<TerminalDragData>(
        onWillAcceptWithDetails: (details) {
          return details.data.terminalId != widget.nodeId;
        },
        onAcceptWithDetails: (details) {
          if (_hoverPosition != null && widget.onDrop != null) {
            widget.onDrop!(details.data.terminalId, _hoverPosition!);
          }
          setState(() => _hoverPosition = null);
        },
        onLeave: (_) => setState(() => _hoverPosition = null),
        onMove: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.offset);
          final size = box.size;

          // Calculate position relative to center
          final centerX = size.width / 2;
          final centerY = size.height / 2;
          final dx = local.dx - centerX;
          final dy = local.dy - centerY;

          // Determine zone by which axis has larger offset from center
          // This ensures any position maps to exactly one zone
          DropPosition pos;
          if (dx.abs() > dy.abs()) {
            // Horizontal dominant - left or right
            pos = dx < 0 ? DropPosition.left : DropPosition.right;
          } else {
            // Vertical dominant - top or bottom
            pos = dy < 0 ? DropPosition.top : DropPosition.bottom;
          }

          if (pos != _hoverPosition) {
            setState(() => _hoverPosition = pos);
          }
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

/// Resizable split container with focus zoom overlay
class _SplitContainer extends StatefulWidget {
  final bool isHorizontal;
  final List<double> ratios;
  final double focusZoom;
  final List<Widget> Function(void Function(int) onFocus) childBuilder;

  const _SplitContainer({
    required this.isHorizontal,
    required this.ratios,
    required this.childBuilder,
    this.focusZoom = 1.0,
  });

  @override
  State<_SplitContainer> createState() => _SplitContainerState();
}

class _SplitContainerState extends State<_SplitContainer> {
  late List<double> _ratios;
  int _focusedIndex = -1;
  final List<GlobalKey> _childKeys = [];
  OverlayEntry? _zoomOverlay;

  @override
  void initState() {
    super.initState();
    _ratios = List.from(widget.ratios);
    _initKeys();
  }

  void _initKeys() {
    _childKeys.clear();
    for (var i = 0; i < widget.ratios.length; i++) {
      _childKeys.add(GlobalKey());
    }
  }

  @override
  void dispose() {
    _removeZoomOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SplitContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ratios.length != _ratios.length) {
      _ratios = List.from(widget.ratios);
      _focusedIndex = -1;
      _removeZoomOverlay();
      _initKeys();
    }
  }

  void _onFocus(int index) {
    if (_focusedIndex == index) return;

    _removeZoomOverlay();
    _focusedIndex = index;

    // Only show zoom overlay if zoom is enabled and there are multiple children
    // and the child doesn't have full width/height (ratio < 1.0)
    if (index >= 0 &&
        widget.focusZoom > 1.0 &&
        _ratios.length > 1 &&
        _ratios[index] < 0.99) {
      _showZoomOverlay(index);
    }
  }

  void _removeZoomOverlay() {
    _zoomOverlay?.remove();
    _zoomOverlay = null;
  }

  void _showZoomOverlay(int index) {
    final key = _childKeys[index];
    final context = key.currentContext;
    if (context == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    // Get the child widget to show in overlay
    final childWidgets = widget.childBuilder((_) {});
    if (index >= childWidgets.length) return;

    _zoomOverlay = OverlayEntry(
      builder: (context) => _ZoomOverlay(
        position: position,
        size: size,
        scale: widget.focusZoom,
        child: childWidgets[index],
      ),
    );

    Overlay.of(this.context).insert(_zoomOverlay!);
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

        final children = <Widget>[];
        for (var i = 0; i < childWidgets.length; i++) {
          final size = availableSize * _ratios[i];

          children.add(
            SizedBox(
              key: _childKeys[i],
              width: widget.isHorizontal ? size : null,
              height: widget.isHorizontal ? null : size,
              child: childWidgets[i],
            ),
          );

          if (i < childWidgets.length - 1) {
            children.add(
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

        return widget.isHorizontal
            ? Row(children: children)
            : Column(children: children);
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

/// Zoom overlay that shows scaled terminal above other content
class _ZoomOverlay extends StatefulWidget {
  final Offset position;
  final Size size;
  final double scale;
  final Widget child;

  const _ZoomOverlay({
    required this.position,
    required this.size,
    required this.scale,
    required this.child,
  });

  @override
  State<_ZoomOverlay> createState() => _ZoomOverlayState();
}

class _ZoomOverlayState extends State<_ZoomOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
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
    // Calculate center position
    final centerX = widget.position.dx + widget.size.width / 2;
    final centerY = widget.position.dy + widget.size.height / 2;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        final scale = _scaleAnimation.value;
        final scaledWidth = widget.size.width * scale;
        final scaledHeight = widget.size.height * scale;

        return Positioned(
          left: centerX - scaledWidth / 2,
          top: centerY - scaledHeight / 2,
          width: scaledWidth,
          height: scaledHeight,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
