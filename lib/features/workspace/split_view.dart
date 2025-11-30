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
    return _buildNode(widget.node, null, null);
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

          // Determine drop zone based on position
          final relX = local.dx / size.width;
          final relY = local.dy / size.height;

          DropPosition? pos;
          if (relX < 0.25) {
            pos = DropPosition.left;
          } else if (relX > 0.75) {
            pos = DropPosition.right;
          } else if (relY < 0.25) {
            pos = DropPosition.top;
          } else if (relY > 0.75) {
            pos = DropPosition.bottom;
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

/// Visual indicator for drop zone
class _DropZoneIndicator extends StatelessWidget {
  final DropPosition position;

  const _DropZoneIndicator({required this.position});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: position == DropPosition.left
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            right: position == DropPosition.right
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            top: position == DropPosition.top
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            bottom: position == DropPosition.bottom
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
          ),
        ),
        child: FractionallySizedBox(
          alignment: _getAlignment(),
          widthFactor: _isHorizontal() ? 0.5 : 1.0,
          heightFactor: _isHorizontal() ? 1.0 : 0.5,
          child: Container(color: color),
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

class _SplitContainerState extends State<_SplitContainer>
    with SingleTickerProviderStateMixin {
  late List<double> _baseRatios;
  late List<double> _displayRatios;
  int _focusedIndex = -1;
  late AnimationController _animController;
  List<double>? _targetRatios;

  @override
  void initState() {
    super.initState();
    _baseRatios = List.from(widget.ratios);
    _displayRatios = List.from(widget.ratios);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animController.addListener(_onAnimUpdate);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SplitContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ratios.length != _baseRatios.length) {
      _baseRatios = List.from(widget.ratios);
      _displayRatios = List.from(widget.ratios);
      _focusedIndex = -1;
    }
  }

  void _onFocus(int index) {
    if (_focusedIndex == index) return;
    _focusedIndex = index;
    _animateToFocus();
  }

  void _animateToFocus() {
    // Calculate target ratios based on focus
    _targetRatios = _calculateFocusRatios();
    _animController.forward(from: 0);
  }

  List<double> _calculateFocusRatios() {
    // If no focus or only one child, return base ratios
    if (_focusedIndex < 0 || _baseRatios.length <= 1) {
      return List.from(_baseRatios);
    }

    // If focus zoom is 1.0, no expansion needed
    if (widget.focusZoom <= 1.0) {
      return List.from(_baseRatios);
    }

    final result = List<double>.from(_baseRatios);
    final focusedRatio = _baseRatios[_focusedIndex];

    // Calculate how much to expand (limited by available space)
    final maxExpansion = focusedRatio * (widget.focusZoom - 1.0);
    final availableFromOthers = 1.0 - focusedRatio;
    final actualExpansion = maxExpansion.clamp(0.0, availableFromOthers * 0.5);

    // Distribute the reduction among other panels
    final otherCount = _baseRatios.length - 1;
    if (otherCount > 0) {
      final reductionPerOther = actualExpansion / otherCount;
      for (var i = 0; i < result.length; i++) {
        if (i == _focusedIndex) {
          result[i] = focusedRatio + actualExpansion;
        } else {
          result[i] = _baseRatios[i] - reductionPerOther;
        }
      }
    }

    // Ensure minimum ratios
    const minRatio = 0.1;
    for (var i = 0; i < result.length; i++) {
      if (result[i] < minRatio) result[i] = minRatio;
    }

    // Normalize to sum to 1.0
    final sum = result.reduce((a, b) => a + b);
    for (var i = 0; i < result.length; i++) {
      result[i] /= sum;
    }

    return result;
  }

  void _onAnimUpdate() {
    if (_targetRatios == null) return;
    setState(() {
      final t = Curves.easeOut.transform(_animController.value);
      for (var i = 0; i < _displayRatios.length; i++) {
        _displayRatios[i] = _displayRatios[i] +
            (_targetRatios![i] - _displayRatios[i]) * t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dividerThickness = 2.0;
    final dividerColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
    final childWidgets = widget.childBuilder(_onFocus);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = widget.isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final dividerTotal = dividerThickness * (_displayRatios.length - 1);
        final availableSize = totalSize - dividerTotal;

        final children = <Widget>[];
        for (var i = 0; i < childWidgets.length; i++) {
          final size = availableSize * _displayRatios[i];

          children.add(
            SizedBox(
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

      _baseRatios[dividerIndex] += change;
      _baseRatios[dividerIndex + 1] -= change;
      _displayRatios[dividerIndex] += change;
      _displayRatios[dividerIndex + 1] -= change;

      // Enforce minimum size
      const minRatio = 0.1;
      if (_baseRatios[dividerIndex] < minRatio) {
        _baseRatios[dividerIndex + 1] -= (minRatio - _baseRatios[dividerIndex]);
        _baseRatios[dividerIndex] = minRatio;
        _displayRatios[dividerIndex + 1] -= (minRatio - _displayRatios[dividerIndex]);
        _displayRatios[dividerIndex] = minRatio;
      }
      if (_baseRatios[dividerIndex + 1] < minRatio) {
        _baseRatios[dividerIndex] -= (minRatio - _baseRatios[dividerIndex + 1]);
        _baseRatios[dividerIndex + 1] = minRatio;
        _displayRatios[dividerIndex] -= (minRatio - _displayRatios[dividerIndex + 1]);
        _displayRatios[dividerIndex + 1] = minRatio;
      }
    });
  }
}
