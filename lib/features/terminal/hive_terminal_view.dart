import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:xterm/xterm.dart' show Terminal, TerminalController, TerminalKey;

import '../../core/hive/hive_client.dart';
import '../../core/hive/hive_terminal_service.dart';
import '../../src/generated/hive.pbgrpc.dart';
import '../connection/connection_config.dart';
import '../workspace/split_view.dart';
import '../../shared/widgets/terminal_keyboard.dart';

/// Terminal view that connects via Hive Server gRPC
class HiveTerminalView extends StatefulWidget {
  final ConnectionConfig config;
  final String? nodeId;
  final HiveClient? client;
  final VoidCallback? onClose;
  final VoidCallback? onSplitHorizontal;
  final VoidCallback? onSplitVertical;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool showControls;

  const HiveTerminalView({
    super.key,
    required this.config,
    this.nodeId,
    this.client,
    this.onClose,
    this.onSplitHorizontal,
    this.onSplitVertical,
    this.onDragStart,
    this.onDragEnd,
    this.showControls = true,
  });

  @override
  State<HiveTerminalView> createState() => _HiveTerminalViewState();
}

class _HiveTerminalViewState extends State<HiveTerminalView>
    with SingleTickerProviderStateMixin {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  SessionState _sessionState = SessionState.disconnected;
  bool _showToolbar = true;
  String? _errorMessage;

  // gRPC streaming
  HiveTerminalService? _terminalService;
  Session? _session;
  TerminalStream? _terminalStream;
  StreamSubscription<TerminalOutput>? _outputSubscription;

  // Zoom state
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  late final AnimationController _zoomAnimController;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 1.5;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _hasClient => widget.client != null && widget.client!.isConnected;

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

    // Handle terminal input - send to gRPC stream
    _terminal.onOutput = (data) {
      _sendData(data);
    };

    // Show placeholder message and attempt connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  @override
  void dispose() {
    _disconnect();
    _zoomAnimController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  void _sendData(String data) {
    if (_terminalStream != null && !_terminalStream!.isClosed) {
      _terminalStream!.sendData(data.codeUnits);
    }
  }

  Future<void> _disconnect() async {
    await _outputSubscription?.cancel();
    _outputSubscription = null;

    await _terminalStream?.close();
    _terminalStream = null;

    if (_session != null && _terminalService != null) {
      await _terminalService!.closeSession(_session!.id);
    }
    _session = null;
  }

  Future<void> _connect() async {
    // Disconnect any existing connection first
    await _disconnect();

    setState(() {
      _sessionState = SessionState.connecting;
      _errorMessage = null;
    });

    _terminal.write('Connecting to ${widget.config.host}:${widget.config.port}...\r\n');

    // Check if we have a valid client
    if (!_hasClient) {
      _terminal.write('\x1B[33mNo Hive Server connection.\x1B[0m\r\n');
      _terminal.write('\x1B[90mConfigure Hive Server in Settings to connect.\x1B[0m\r\n');
      setState(() {
        _sessionState = SessionState.disconnected;
        _errorMessage = 'No Hive Server connection';
      });
      return;
    }

    _terminalService = HiveTerminalService(client: widget.client!);

    // Create session for this connection
    _terminal.write('Creating session...\r\n');

    // Password is required for SSH authentication
    if (widget.config.password == null || widget.config.password!.isEmpty) {
      _terminal.write('\x1B[31mPassword required for SSH authentication.\x1B[0m\r\n');
      setState(() {
        _sessionState = SessionState.error;
        _errorMessage = 'Password required';
      });
      return;
    }

    _session = await _terminalService!.createSession(
      widget.config.id,
      password: widget.config.password!,
    );

    if (_session == null) {
      _terminal.write('\x1B[31mFailed to create session.\x1B[0m\r\n');
      setState(() {
        _sessionState = SessionState.error;
        _errorMessage = 'Failed to create session';
      });
      return;
    }

    _terminal.write('Session created: ${_session!.id}\r\n');

    // Attach to terminal stream
    _terminal.write('Attaching to terminal...\r\n');
    _terminalStream = _terminalService!.attach(_session!.id);

    if (_terminalStream == null) {
      _terminal.write('\x1B[31mFailed to attach to terminal.\x1B[0m\r\n');
      setState(() {
        _sessionState = SessionState.error;
        _errorMessage = 'Failed to attach to terminal';
      });
      return;
    }

    // Listen to terminal output
    _outputSubscription = _terminalStream!.output.listen(
      _handleOutput,
      onError: _handleStreamError,
      onDone: _handleStreamDone,
    );

    _terminal.write('\x1B[32mConnected!\x1B[0m\r\n\r\n');
    setState(() => _sessionState = SessionState.connected);
  }

  void _handleOutput(TerminalOutput output) {
    if (HiveTerminalService.isData(output)) {
      // Write terminal data
      _terminal.write(String.fromCharCodes(output.data));
    } else if (HiveTerminalService.isScrollback(output)) {
      // Write scrollback data (on reconnect)
      _terminal.write(String.fromCharCodes(output.scrollback));
    } else if (HiveTerminalService.isError(output)) {
      // Handle error
      final error = output.error;
      _terminal.write('\x1B[31mError: ${error.message}\x1B[0m\r\n');
      setState(() {
        _sessionState = SessionState.error;
        _errorMessage = error.message;
      });
    } else if (HiveTerminalService.isClosed(output)) {
      // Session closed by server
      final closed = output.closed;
      _terminal.write('\r\n\x1B[33mSession closed: ${closed.reason}\x1B[0m\r\n');
      setState(() {
        _sessionState = SessionState.disconnected;
        _errorMessage = closed.reason;
      });
    } else if (HiveTerminalService.isFileUploaded(output)) {
      // File upload confirmation
      final file = output.file;
      _terminal.write('\x1B[32mFile uploaded: ${file.filename}\x1B[0m\r\n');
    }
  }

  void _handleStreamError(Object error) {
    debugPrint('Terminal stream error: $error');
    _terminal.write('\r\n\x1B[31mStream error: $error\x1B[0m\r\n');
    setState(() {
      _sessionState = SessionState.error;
      _errorMessage = error.toString();
    });
  }

  void _handleStreamDone() {
    debugPrint('Terminal stream closed');
    if (_sessionState == SessionState.connected) {
      _terminal.write('\r\n\x1B[33mConnection closed.\x1B[0m\r\n');
      setState(() => _sessionState = SessionState.disconnected);
    }
  }

  /// Convert TerminalKey enum to escape sequence string
  String? _terminalKeyToSequence(TerminalKey key, {bool ctrl = false, bool alt = false}) {
    // Standard escape sequences for terminal keys
    switch (key) {
      case TerminalKey.escape:
        return '\x1B';
      case TerminalKey.tab:
        return '\t';
      case TerminalKey.enter:
        return '\r';
      case TerminalKey.backspace:
        return '\x7F';
      case TerminalKey.delete:
        return '\x1B[3~';
      case TerminalKey.insert:
        return '\x1B[2~';
      case TerminalKey.home:
        return '\x1B[H';
      case TerminalKey.end:
        return '\x1B[F';
      case TerminalKey.pageUp:
        return '\x1B[5~';
      case TerminalKey.pageDown:
        return '\x1B[6~';
      case TerminalKey.arrowUp:
        return '\x1B[A';
      case TerminalKey.arrowDown:
        return '\x1B[B';
      case TerminalKey.arrowRight:
        return '\x1B[C';
      case TerminalKey.arrowLeft:
        return '\x1B[D';
      case TerminalKey.f1:
        return '\x1BOP';
      case TerminalKey.f2:
        return '\x1BOQ';
      case TerminalKey.f3:
        return '\x1BOR';
      case TerminalKey.f4:
        return '\x1BOS';
      case TerminalKey.f5:
        return '\x1B[15~';
      case TerminalKey.f6:
        return '\x1B[17~';
      case TerminalKey.f7:
        return '\x1B[18~';
      case TerminalKey.f8:
        return '\x1B[19~';
      case TerminalKey.f9:
        return '\x1B[20~';
      case TerminalKey.f10:
        return '\x1B[21~';
      case TerminalKey.f11:
        return '\x1B[23~';
      case TerminalKey.f12:
        return '\x1B[24~';
      default:
        return null;
    }
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
                onText: (text) {
                  _sendData(text);
                },
                onKey: (key, {ctrl = false, alt = false}) {
                  // Convert TerminalKey to escape sequences
                  final data = _terminalKeyToSequence(key, ctrl: ctrl, alt: alt);
                  if (data != null) {
                    _sendData(data);
                  }
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

    final isDisconnected = _sessionState == SessionState.error ||
        _sessionState == SessionState.disconnected;

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
          // Large centered reconnect button when disconnected
          if (isDisconnected)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sessionState == SessionState.error
                            ? Icons.error_outline
                            : Icons.wifi_off,
                        size: 48,
                        color: _sessionState == SessionState.error
                            ? Colors.red
                            : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _sessionState == SessionState.error
                            ? 'Connection Error'
                            : 'Not Connected',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _connect,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
              onTap: _connect,
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
