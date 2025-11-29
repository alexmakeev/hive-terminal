import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:xterm/xterm.dart' show Terminal, TerminalController;

import '../connection/ssh_session.dart';
import '../../shared/widgets/terminal_keyboard.dart';

/// Single terminal view with SSH session
class SshTerminalView extends StatefulWidget {
  final ConnectionConfig config;
  final VoidCallback? onClose;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final bool showControls;

  const SshTerminalView({
    super.key,
    required this.config,
    this.onClose,
    this.onSplitHorizontal,
    this.onSplitVertical,
    this.showControls = true,
  });

  @override
  State<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends State<SshTerminalView> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  late final SshSession _session;
  SessionState _sessionState = SessionState.disconnected;
  bool _showToolbar = true;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();

    _terminal = Terminal(
      maxLines: 10000,
    );

    _terminalController = TerminalController();

    _session = SshSession(
      config: widget.config,
      terminal: _terminal,
      onStateChange: (state) {
        if (mounted) {
          setState(() => _sessionState = state);
        }
      },
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
    return xterm.TerminalView(
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
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 32,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(width: 8),

          // Connection name
          Expanded(
            child: Text(
              widget.config.name,
              style: TextStyle(
                fontSize: 12,
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
      size: 16,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: rotated
              ? Transform.rotate(angle: 1.5708, child: iconWidget)
              : iconWidget,
        ),
      ),
    );
  }
}
