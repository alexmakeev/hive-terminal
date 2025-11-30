import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:xterm/xterm.dart' show Terminal, TerminalController;

import '../connection/ssh_session.dart';
import '../workspace/split_view.dart';
import '../../shared/widgets/terminal_keyboard.dart';

/// Single terminal view with SSH session
class SshTerminalView extends StatefulWidget {
  final ConnectionConfig config;
  final String? nodeId;
  final VoidCallback? onClose;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool showControls;
  final String? sshFolderPath;

  const SshTerminalView({
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
  State<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends State<SshTerminalView>
    with SingleTickerProviderStateMixin {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  late final SshSession _session;
  SessionState _sessionState = SessionState.disconnected;
  bool _showToolbar = true;

  // Zoom state
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  late final AnimationController _zoomAnimController;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 1.5;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _terminal = Terminal(
      maxLines: 10000,
    );

    _terminalController = TerminalController();

    _session = SshSession(
      config: widget.config,
      terminal: _terminal,
      sshFolderPath: widget.sshFolderPath,
      onStateChange: (state) {
        if (mounted) {
          setState(() => _sessionState = state);
        }
      },
      onPassphraseRequest: _showPassphraseDialog,
    );

    // Connect on init
    _session.connect();

    // Handle terminal input
    _terminal.onOutput = (data) {
      _session.write(data);
    };
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    _session.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            // Header bar (desktop only, or when showing controls)
            if (widget.showControls) _buildHeader(theme),

            // Terminal
            Expanded(
              child: _buildTerminalWidget(),
            ),

            // Extra keyboard (mobile only)
            if (_isMobile && _showToolbar)
              TerminalKeyboard(
                onText: (text) => _session.write(text),
                onKey: (key, {ctrl = false, alt = false}) {
                  _session.sendKey(key, ctrl: ctrl, alt: alt);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalWidget() {
    final terminalView = xterm.TerminalView(
      _terminal,
      controller: _terminalController,
      theme: const xterm.TerminalTheme(
        cursor: Color(0xFFFFB74D),
        selection: Color(0x80FFB74D),
        foreground: Color(0xFFE0E0E0),
        background: Color(0xFF1A1208),
        black: Color(0xFF000000),
        white: Color(0xFFFFFFFF),
        red: Color(0xFFFF5252),
        green: Color(0xFF69F0AE),
        yellow: Color(0xFFFFD740),
        blue: Color(0xFF448AFF),
        magenta: Color(0xFFE040FB),
        cyan: Color(0xFF18FFFF),
        brightBlack: Color(0xFF616161),
        brightRed: Color(0xFFFF8A80),
        brightGreen: Color(0xFFB9F6CA),
        brightYellow: Color(0xFFFFFF8D),
        brightBlue: Color(0xFF82B1FF),
        brightMagenta: Color(0xFFEA80FC),
        brightCyan: Color(0xFF84FFFF),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFFFB74D),
        searchHitBackgroundCurrent: Color(0xFFFF9800),
        searchHitForeground: Color(0xFF000000),
      ),
      textStyle: const xterm.TerminalStyle(
        fontSize: 14,
        fontFamily: 'monospace',
      ),
      padding: const EdgeInsets.all(8),
      autofocus: true,
      hardwareKeyboardOnly: !_isMobile,
    );

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onDoubleTap: _resetZoom,
      child: Stack(
        children: [
          ClipRect(
            child: Transform.scale(
              scale: _zoom,
              child: terminalView,
            ),
          ),
          // Zoom indicator (show only when zoomed)
          if (_zoom != 1.0)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(_zoom * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _resetZoom() {
    if (_zoom != 1.0) {
      _animateZoomTo(1.0);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _zoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Optional: snap to 1.0 if close
    if ((_zoom - 1.0).abs() < 0.1) {
      _animateZoomTo(1.0);
    }
  }

  void _animateZoomTo(double target) {
    final startZoom = _zoom;
    _zoomAnimController.reset();
    _zoomAnimController.addListener(() {
      setState(() {
        _zoom = startZoom + (_zoomAnimController.value * (target - startZoom));
      });
    });
    _zoomAnimController.forward();
  }

  Widget _buildHeader(ThemeData theme) {
    final headerContent = Container(
      height: 20,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Drag handle (desktop only)
          if (!_isMobile && widget.nodeId != null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.drag_indicator, size: 12, color: Colors.grey),
            ),

          // Status indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(width: 4),

          // Connection name
          Expanded(
            child: Text(
              widget.config.name,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Desktop controls
          if (!_isMobile) ...[
            // Split horizontal (panels side by side - icon shows vertical line)
            if (widget.onSplitHorizontal != null)
              _ControlButton(
                icon: Icons.splitscreen,
                tooltip: 'Split Horizontal',
                onTap: widget.onSplitHorizontal!,
                rotated: true,
              ),
            // Split vertical (panels stacked - icon shows horizontal line)
            if (widget.onSplitVertical != null)
              _ControlButton(
                icon: Icons.splitscreen,
                tooltip: 'Split Vertical',
                onTap: widget.onSplitVertical!,
              ),
          ],

          // Toggle mobile toolbar
          if (_isMobile)
            _ControlButton(
              icon: _showToolbar ? Icons.keyboard_hide : Icons.keyboard,
              tooltip: 'Toggle Keyboard',
              onTap: () => setState(() => _showToolbar = !_showToolbar),
            ),

          // Reconnect button
          if (_sessionState == SessionState.error ||
              _sessionState == SessionState.disconnected)
            _ControlButton(
              icon: Icons.refresh,
              tooltip: 'Reconnect',
              onTap: () => _session.connect(),
            ),

          // Close button
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
                const Icon(Icons.terminal, size: 14),
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
      case SessionState.connected:
        return Colors.green;
      case SessionState.connecting:
        return Colors.orange;
      case SessionState.error:
        return Colors.red;
      case SessionState.disconnected:
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
          title: Text('SSH Key Passphrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key "$keyName" is encrypted.',
                style: TextStyle(fontSize: 14),
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
  final bool rotated;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.rotated = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 12,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: rotated
              ? Transform.rotate(angle: 1.5708, child: iconWidget)
              : iconWidget,
        ),
      ),
    );
  }
}
