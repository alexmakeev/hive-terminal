import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'settings_manager.dart';

/// App settings page
class SettingsPage extends StatefulWidget {
  final SettingsManager settings;

  const SettingsPage({
    super.key,
    required this.settings,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
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

          // Terminal Section
          _buildSectionHeader(context, 'Terminal'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Focus Zoom'),
                      Text(
                        '${(widget.settings.focusZoom * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: widget.settings.focusZoom,
                    min: 1.0,
                    max: 1.5,
                    divisions: 10,
                    label: '${(widget.settings.focusZoom * 100).round()}%',
                    onChanged: (value) {
                      widget.settings.setFocusZoom(value);
                    },
                  ),
                  Text(
                    'Terminal expansion when focused (100% = no change)',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

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
