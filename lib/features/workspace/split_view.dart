import 'dart:io';

import 'package:flutter/material.dart';

import '../terminal/terminal_view.dart';
import 'workspace_manager.dart';

/// Renders a split node tree
class SplitView extends StatelessWidget {
  final SplitNode node;
  final void Function(String nodeId) onClose;
  final void Function(String nodeId, bool horizontal) onSplit;
  final String? sshFolderPath;

  const SplitView({
    super.key,
    required this.node,
    required this.onClose,
    required this.onSplit,
    this.sshFolderPath,
  });

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return _buildNode(node);
  }

  Widget _buildNode(SplitNode node) {
    if (node is TerminalNode) {
      return SshTerminalView(
        key: node.pane.key, // GlobalKey survives reparenting
        config: node.pane.config,
        sshFolderPath: sshFolderPath,
        onClose: () => onClose(node.id),
        onSplitHorizontal: _isDesktop ? () => onSplit(node.id, true) : null,
        onSplitVertical: _isDesktop ? () => onSplit(node.id, false) : null,
      );
    }

    if (node is SplitContainerNode) {
      return _SplitContainer(
        isHorizontal: node.isHorizontal,
        ratios: node.ratios,
        children: node.children.map(_buildNode).toList(),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Resizable split container
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
    if (widget.children.length != _ratios.length) {
      _ratios = List.from(widget.ratios);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dividerThickness = 4.0;
    final dividerColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = widget.isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
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
