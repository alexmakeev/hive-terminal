import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:xterm/xterm.dart' show Terminal, TerminalController;

import '../connection/mosh_session_wrapper.dart';
import '../connection/ssh_session.dart';
import '../workspace/split_view.dart';

/// Single terminal view with MOSH session
class MoshTerminalView extends StatefulWidget {
  final ConnectionConfig config;
  final String? nodeId;
  final VoidCallback? onClose;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool showControls;
  final String? sshFolderPath;

  const MoshTerminalView({
    super.key,
    required this.config,
    this.nodeId,
    this.onClose,
    this.onSplitHorizontal,
    this.onSplitVertical,
    this.onDragStart,
    this.onDragEnd,
    this.showControls = true,
    this.sshFolderPath,
  });

  @override
  State<MoshTerminalView> createState() => _MoshTerminalViewState();
}

class _MoshTerminalViewState extends State<MoshTerminalView> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  late final MoshSessionWrapper _session;
  MoshSessionState _sessionState = MoshSessionState.disconnected;
  bool _showToolbar = true;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();

    _terminal = Terminal(
      maxLines: 10000,
    );

    _terminalController = TerminalController();

    _session = MoshSessionWrapper(
      config: widget.config,
      terminal: _terminal,
      sshFolderPath: widget.sshFolderPath,
      onPassphraseRequest: _showPassphraseDialog,
      onStateChange: (state) {
        if (mounted) {
          setState(() => _sessionState = state);
        }
      },
    );

    // Connect on init
    _session.connect();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header bar
          if (widget.showControls) _buildHeader(context),

          // Terminal
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showToolbar = !_showToolbar),
              child: xterm.TerminalView(
                _terminal,
                controller: _terminalController,
                autofocus: true,
                backgroundOpacity: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();

    final headerContent = Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          // MOSH indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'MOSH',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Status indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          // Title
          Expanded(
            child: Text(
              widget.config.name,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Action buttons
          if (_sessionState == MoshSessionState.error ||
              _sessionState == MoshSessionState.disconnected)
            _ControlButton(
              icon: Icons.refresh,
              tooltip: 'Reconnect',
              onTap: () => _session.connect(),
            ),
          if (widget.onSplitHorizontal != null)
            _ControlButton(
              icon: Icons.view_column,
              tooltip: 'Split Right',
              onTap: widget.onSplitHorizontal!,
            ),
          if (widget.onSplitVertical != null)
            _ControlButton(
              icon: Icons.view_agenda,
              tooltip: 'Split Down',
              onTap: widget.onSplitVertical!,
            ),
          if (widget.onClose != null)
            _ControlButton(
              icon: Icons.close,
              tooltip: 'Close',
              onTap: widget.onClose!,
            ),
        ],
      ),
    );

    // Wrap in Draggable if nodeId is available
    if (widget.nodeId != null && !_isMobile) {
      return Draggable<TerminalDragData>(
        data: TerminalDragData(terminalId: widget.nodeId!),
        onDragStarted: widget.onDragStart,
        onDragEnd: (_) => widget.onDragEnd?.call(),
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'MOSH',
                    style: TextStyle(fontSize: 8, color: Colors.purple),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.config.name,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Container(
          height: 20,
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        ),
        child: headerContent,
      );
    }

    return headerContent;
  }

  Color _getStatusColor() {
    switch (_sessionState) {
      case MoshSessionState.connected:
        return Colors.green;
      case MoshSessionState.bootstrapping:
      case MoshSessionState.connecting:
        return Colors.orange;
      case MoshSessionState.error:
        return Colors.red;
      case MoshSessionState.disconnected:
        return Colors.grey;
    }
  }

  Future<String?> _showPassphraseDialog(String keyName) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('SSH Key Passphrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key "$keyName" is encrypted.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Passphrase',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => Navigator.of(ctx).pop(value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 14),
        ),
      ),
    );
  }
}
