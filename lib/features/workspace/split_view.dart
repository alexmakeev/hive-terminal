import 'package:flutter/material.dart';

import '../../core/hive/hive_client.dart';
import '../connection/connection_config.dart';
import '../terminal/hive_terminal_view.dart';
import 'workspace_manager.dart';

/// Data for terminal drag
class TerminalDragData {
  final String terminalId;

  const TerminalDragData({required this.terminalId});
}

/// Renders a split node tree
class SplitView extends StatefulWidget {
  final SplitNode node;
  final HiveClient? client;
  final void Function(String nodeId) onClose;
  final void Function(String nodeId, bool horizontal) onSplit;
  final void Function(String sourceId, String targetId, DropPosition position)? onMove;

  const SplitView({
    super.key,
    required this.node,
    this.client,
    required this.onClose,
    required this.onSplit,
    this.onMove,
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

    return _buildNode(filteredRoot);
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

  Widget _buildNode(SplitNode node) {
    if (node is TerminalNode) {
      return _DraggableTerminal(
        nodeId: node.id,
        isDragging: _draggingId == node.id,
        onDrop: widget.onMove != null
            ? (sourceId, position) => widget.onMove!(sourceId, node.id, position)
            : null,
        child: HiveTerminalView(
          key: node.pane.key,
          config: node.pane.config,
          nodeId: node.id,
          client: widget.client,
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
        children: node.children.map((child) => _buildNode(child)).toList(),
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
  final Widget child;

  const _DraggableTerminal({
    required this.nodeId,
    required this.isDragging,
    this.onDrop,
    required this.child,
  });

  @override
  State<_DraggableTerminal> createState() => _DraggableTerminalState();
}

class _DraggableTerminalState extends State<_DraggableTerminal> {
  DropPosition? _hoverPosition;
  Offset? _lastPointerPosition;
  final GlobalKey _key = GlobalKey();

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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _key,
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
          _lastPointerPosition = details.offset;
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

/// Simple resizable split container using Row/Column
class _SplitContainer extends StatefulWidget {
  final bool isHorizontal;
  final List<double> ratios;
  final List<Widget> children;

  const _SplitContainer({
    required this.isHorizontal,
    required this.ratios,
    required this.children,
  });

  @override
  State<_SplitContainer> createState() => _SplitContainerState();
}

class _SplitContainerState extends State<_SplitContainer> {
  late List<double> _ratios;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    const dividerThickness = 4.0;
    final dividerColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize =
            widget.isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        final dividerTotal = dividerThickness * (_ratios.length - 1);
        final availableSize = totalSize - dividerTotal;

        final children = <Widget>[];

        for (var i = 0; i < widget.children.length; i++) {
          final size = availableSize * _ratios[i];

          children.add(
            SizedBox(
              width: widget.isHorizontal ? size : null,
              height: widget.isHorizontal ? null : size,
              child: widget.children[i],
            ),
          );

          if (i < widget.children.length - 1) {
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
