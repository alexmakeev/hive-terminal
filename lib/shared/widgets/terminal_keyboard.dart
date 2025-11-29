import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Extra keys toolbar for mobile devices
/// Shows keys that are missing from standard mobile keyboards
class TerminalKeyboard extends StatefulWidget {
  final void Function(String text) onText;
  final void Function(TerminalKey key, {bool ctrl, bool alt}) onKey;

  const TerminalKeyboard({
    super.key,
    required this.onText,
    required this.onKey,
  });

  @override
  State<TerminalKeyboard> createState() => _TerminalKeyboardState();
}

class _TerminalKeyboardState extends State<TerminalKeyboard> {
  bool _ctrlPressed = false;
  bool _altPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = theme.colorScheme.surfaceContainerHighest;
    final activeColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      height: 44,
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          // Modifier keys
          _ModifierKey(
            label: 'Ctrl',
            isActive: _ctrlPressed,
            onTap: () => setState(() => _ctrlPressed = !_ctrlPressed),
            activeColor: activeColor,
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _ModifierKey(
            label: 'Alt',
            isActive: _altPressed,
            onTap: () => setState(() => _altPressed = !_altPressed),
            activeColor: activeColor,
            buttonColor: buttonColor,
            textColor: textColor,
          ),

          const VerticalDivider(width: 1),

          // Function keys
          _KeyButton(
            label: 'Esc',
            onTap: () => _sendKey(TerminalKey.escape),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            label: 'Tab',
            onTap: () => _sendKey(TerminalKey.tab),
            buttonColor: buttonColor,
            textColor: textColor,
          ),

          const VerticalDivider(width: 1),

          // Arrow keys
          _KeyButton(
            icon: Icons.keyboard_arrow_up,
            onTap: () => _sendKey(TerminalKey.arrowUp),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            icon: Icons.keyboard_arrow_down,
            onTap: () => _sendKey(TerminalKey.arrowDown),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            icon: Icons.keyboard_arrow_left,
            onTap: () => _sendKey(TerminalKey.arrowLeft),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            icon: Icons.keyboard_arrow_right,
            onTap: () => _sendKey(TerminalKey.arrowRight),
            buttonColor: buttonColor,
            textColor: textColor,
          ),

          const VerticalDivider(width: 1),

          // Common shortcuts
          _KeyButton(
            label: '/',
            onTap: () => widget.onText('/'),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            label: '-',
            onTap: () => widget.onText('-'),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            label: '|',
            onTap: () => widget.onText('|'),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          _KeyButton(
            label: '~',
            onTap: () => widget.onText('~'),
            buttonColor: buttonColor,
            textColor: textColor,
          ),

          const Spacer(),

          // Ctrl+C shortcut
          _KeyButton(
            label: '^C',
            onTap: () => widget.onText('\x03'),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
          // Ctrl+D shortcut
          _KeyButton(
            label: '^D',
            onTap: () => widget.onText('\x04'),
            buttonColor: buttonColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  void _sendKey(TerminalKey key) {
    widget.onKey(key, ctrl: _ctrlPressed, alt: _altPressed);
    // Reset modifiers after use
    if (_ctrlPressed || _altPressed) {
      setState(() {
        _ctrlPressed = false;
        _altPressed = false;
      });
    }
  }
}

class _ModifierKey extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color buttonColor;
  final Color textColor;

  const _ModifierKey({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.buttonColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : buttonColor,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color buttonColor;
  final Color textColor;

  const _KeyButton({
    this.label,
    this.icon,
    required this.onTap,
    required this.buttonColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(minWidth: 36),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 18, color: textColor)
            : Text(
                label ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}
