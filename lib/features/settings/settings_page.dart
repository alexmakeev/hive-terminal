import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/hive/hive_server_service.dart';
import 'settings_manager.dart';

/// App settings page
class SettingsPage extends StatefulWidget {
  final SettingsManager settings;
  final HiveServerService hiveServer;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.hiveServer,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isConnecting = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
    widget.hiveServer.addListener(_onSettingsChanged);
    _loadServerConfig();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    widget.hiveServer.removeListener(_onSettingsChanged);
    _hostController.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _loadServerConfig() {
    _hostController.text = widget.hiveServer.serverHost ?? '';
    _portController.text = widget.hiveServer.serverPort?.toString() ?? '50051';
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hive Server Section
          _buildSectionHeader(context, 'Hive Server'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection status
                  Row(
                    children: [
                      Icon(
                        widget.hiveServer.isConnected
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: widget.hiveServer.isConnected
                            ? Colors.green
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.hiveServer.isConnected
                            ? 'Connected'
                            : 'Not connected',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.hiveServer.isConnected
                              ? Colors.green
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (widget.hiveServer.hasApiKey) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.key,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.hiveServer.username != null
                              ? widget.hiveServer.username!
                              : 'API key set',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Host input
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Server Host',
                      hintText: 'localhost or server.example.com',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    enabled: !widget.hiveServer.isConnected,
                  ),
                  const SizedBox(height: 12),

                  // Port input
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '50051',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !widget.hiveServer.isConnected,
                  ),
                  const SizedBox(height: 12),

                  // API Key input
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Enter your API key',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureApiKey,
                  ),
                  const SizedBox(height: 16),

                  // Connect/Disconnect button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isConnecting ? null : _toggleConnection,
                          icon: _isConnecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  widget.hiveServer.isConnected
                                      ? Icons.cloud_off
                                      : Icons.cloud_upload,
                                ),
                          label: Text(
                            widget.hiveServer.isConnected
                                ? 'Disconnect'
                                : 'Connect',
                          ),
                        ),
                      ),
                      if (widget.hiveServer.hasApiKey) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _clearApiKey,
                          icon: const Icon(Icons.key_off),
                          tooltip: 'Clear API key',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // SSH Folder Section
          if (Platform.isMacOS || Platform.isLinux) ...[
            _buildSectionHeader(context, 'SSH Keys'),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.folder_open,
                  color: widget.settings.hasAccess ? null : Colors.orange,
                ),
                title: const Text('SSH Folder'),
                subtitle: Text(
                  widget.settings.sshFolderPath ?? 'Not selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.settings.hasAccess
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                        : Colors.orange,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _selectSshFolder,
                  child: Text(widget.settings.hasAccess ? 'Change' : 'Select'),
                ),
              ),
            ),
            if (!widget.settings.hasAccess)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Select your ~/.ssh folder to enable key-based authentication',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],

          // About Section
          _buildSectionHeader(context, 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.hive),
                  title: const Text('Hive Terminal'),
                  subtitle: const Text('SSH client with AI integration'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _toggleConnection() async {
    if (widget.hiveServer.isConnected) {
      await widget.hiveServer.disconnect();
      return;
    }

    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (host.isEmpty) {
      _showError('Please enter server host');
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      _showError('Please enter valid port number');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      // Save config
      await widget.hiveServer.setServerConfig(host, port);

      // Save API key if provided
      if (apiKey.isNotEmpty) {
        await widget.hiveServer.setApiKey(apiKey);
        _apiKeyController.clear();
      }

      // Connect
      await widget.hiveServer.connect();

      if (mounted) {
        final username = widget.hiveServer.username;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              username != null
                  ? 'Welcome, $username!'
                  : 'Connected to Hive Server',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to connect: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _clearApiKey() async {
    await widget.hiveServer.clearApiKey();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key cleared')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _selectSshFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select SSH Keys Folder',
      initialDirectory: _getDefaultSshPath(),
    );

    if (result != null) {
      await widget.settings.setSshFolderPath(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SSH folder set: $result'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String? _getDefaultSshPath() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      return '$home/.ssh';
    }
    return null;
  }
}
