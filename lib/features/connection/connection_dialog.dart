import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ssh_session.dart';

/// Dialog for creating a new SSH connection
class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  static Future<ConnectionConfig?> show(BuildContext context) {
    return showDialog<ConnectionConfig>(
      context: context,
      builder: (context) => const ConnectionDialog(),
    );
  }

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _startupCommandController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePassphrase = true;
  bool _useDefaultKeys = true;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _startupCommandController.dispose();
    super.dispose();
  }

  bool get _canUseDefaultKeys => Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Connection'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic fields
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'My Server',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Host *',
                          hintText: 'example.com',
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    hintText: 'root',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Authentication section
                Text(
                  'Authentication',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),

                // Default keys checkbox (Linux/macOS only)
                if (_canUseDefaultKeys)
                  CheckboxListTile(
                    value: _useDefaultKeys,
                    onChanged: (v) => setState(() => _useDefaultKeys = v ?? true),
                    title: const Text('Use default SSH keys'),
                    subtitle: const Text('~/.ssh/id_ed25519, id_rsa, id_ecdsa'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Leave empty for key auth',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Advanced section toggle
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvanced
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Advanced options',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),

                if (_showAdvanced) ...[
                  const SizedBox(height: 12),

                  // Private key
                  TextFormField(
                    controller: _privateKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Private Key (PEM)',
                      hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // Passphrase for key
                  TextFormField(
                    controller: _passphraseController,
                    decoration: InputDecoration(
                      labelText: 'Key Passphrase',
                      hintText: 'If key is encrypted',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassphrase
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassphrase = !_obscurePassphrase);
                        },
                      ),
                    ),
                    obscureText: _obscurePassphrase,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Startup command section
                  Text(
                    'Startup Command',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<AiCliCommand>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return AiCliCommand.suggestions;
                      }
                      return AiCliCommand.suggestions.where((cmd) =>
                          cmd.command
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()) ||
                          cmd.name
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (cmd) => cmd.command,
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      // Sync with our controller
                      controller.text = _startupCommandController.text;
                      controller.addListener(() {
                        _startupCommandController.text = controller.text;
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Run on connect',
                          hintText: 'claude, aider, gemini...',
                          helperText: 'Command to execute after connecting',
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => onSubmitted(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 250,
                              maxWidth: 350,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final cmd = options.elementAt(index);
                                return ListTile(
                                  title: Text(cmd.name),
                                  subtitle: Text(
                                    cmd.description,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  trailing: Text(
                                    cmd.command,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontFamily: 'monospace',
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                  onTap: () => onSelected(cmd),
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (cmd) {
                      _startupCommandController.text = cmd.command;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Connect'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final config = ConnectionConfig(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
        privateKey: _privateKeyController.text.isEmpty
            ? null
            : _privateKeyController.text,
        passphrase: _passphraseController.text.isEmpty
            ? null
            : _passphraseController.text,
        startupCommand: _startupCommandController.text.isEmpty
            ? null
            : _startupCommandController.text.trim(),
        useDefaultKeys: _canUseDefaultKeys && _useDefaultKeys,
      );
      Navigator.of(context).pop(config);
    }
  }
}
