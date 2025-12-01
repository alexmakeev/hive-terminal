import 'package:flutter/material.dart';

import '../connection/connection_dialog.dart';
import '../connection/connection_repository.dart';
import '../connection/saved_connections_page.dart';
import '../connection/ssh_session.dart';
import '../settings/settings_manager.dart';
import '../settings/settings_page.dart';
import 'split_view.dart';
import 'workspace_manager.dart';

/// Main page with workspace management and terminal display
class WorkspacePage extends StatefulWidget {
  final VoidCallback? onCheckForUpdates;
  final VoidCallback? onShowAbout;

  const WorkspacePage({
    super.key,
    this.onCheckForUpdates,
    this.onShowAbout,
  });

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final WorkspaceManager _manager;
  late final ConnectionRepository _connectionRepository;
  late final SettingsManager _settings;

  @override
  void initState() {
    super.initState();
    _manager = WorkspaceManager();
    _connectionRepository = ConnectionRepository();
    _settings = SettingsManager();
    _connectionRepository.load();
    _settings.load();
    _manager.addListener(_onManagerChanged);
    _connectionRepository.addListener(_onRepositoryChanged);
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    _connectionRepository.removeListener(_onRepositoryChanged);
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Combined header bar with logo, workspaces, and actions
            _buildHeaderBar(),

            // Main content - IndexedStack keeps all workspaces alive
            Expanded(
              child: IndexedStack(
                index: _manager.currentIndex,
                children: [
                  for (final workspace in _manager.workspaces)
                    _buildWorkspace(workspace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      height: 36,
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          // Logo and title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hive,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Hive Terminal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 20,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),

          // Workspace tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _manager.workspaces.length,
              itemBuilder: (context, index) {
                final workspace = _manager.workspaces[index];
                final isSelected = index == _manager.currentIndex;

                return GestureDetector(
                  onTap: () => _manager.setCurrentIndex(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Text(
                          workspace.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (_manager.workspaces.length > 1)
                          InkWell(
                            onTap: () => _manager.removeWorkspace(workspace.id),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Add workspace button
          _HeaderIconButton(
            icon: Icons.add,
            tooltip: 'Add Workspace',
            onPressed: () => _manager.addWorkspace(),
          ),

          // Divider
          Container(
            width: 1,
            height: 20,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),

          // Action buttons
          _HeaderIconButton(
            icon: Icons.bookmark,
            tooltip: 'Saved Connections',
            onPressed: _openSavedConnections,
          ),
          _HeaderIconButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              switch (value) {
                case 'check_updates':
                  widget.onCheckForUpdates?.call();
                  break;
                case 'about':
                  widget.onShowAbout?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'check_updates',
                child: ListTile(
                  leading: Icon(Icons.system_update),
                  title: Text('Check for updates'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildWorkspace(Workspace workspace) {
    if (workspace.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: SplitView(
        node: workspace.root!,
        sshFolderPath: _settings.sshFolderPath,
        focusZoom: _settings.focusZoom,
        onClose: (nodeId) => _manager.closeTerminal(nodeId),
        onSplit: (nodeId, horizontal) async {
          final result = await _showConnectionChooser();
          if (result != null) {
            _manager.splitTerminal(nodeId, result, horizontal);
          }
        },
        onMove: (sourceId, targetId, position) {
          _manager.moveTerminal(sourceId, targetId, position);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final hasSavedConnections = _connectionRepository.connections.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big plus button
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              key: const Key('add_terminal_button'),
              onTap: _addNewTerminal,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add Terminal',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to an SSH server',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          if (hasSavedConnections) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                // Show bottom sheet same as split workflow
                final config = await _showConnectionChooser();
                if (config != null) {
                  _manager.addTerminal(config);
                }
              },
              icon: const Icon(Icons.bookmark),
              label: Text(
                '${_connectionRepository.connections.length} saved connection(s)',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(settings: _settings),
      ),
    );
  }

  void _openSavedConnections() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SavedConnectionsPage(
          repository: _connectionRepository,
          onConnect: (config) {
            _manager.addTerminal(config);
          },
        ),
      ),
    );
  }

  /// Show connection chooser - quick picks from saved or new connection
  Future<ConnectionConfig?> _showConnectionChooser() async {
    final savedConnections = _connectionRepository.connections;

    // If no saved connections, go directly to new connection dialog
    if (savedConnections.isEmpty) {
      return _showNewConnectionDialog();
    }

    // Show bottom sheet with quick picks
    final result = await showModalBottomSheet<ConnectionConfig?>(
      context: context,
      builder: (context) => _ConnectionChooserSheet(
        savedConnections: savedConnections,
        onNewConnection: () async {
          Navigator.of(context).pop();
          final config = await _showNewConnectionDialog();
          return config;
        },
      ),
    );

    return result;
  }

  Future<ConnectionConfig?> _showNewConnectionDialog() async {
    final result = await ConnectionDialog.show(context);
    if (result != null) {
      if (result.addToFavorites) {
        await _connectionRepository.save(result.config);
      }
      return result.config;
    }
    return null;
  }

  Future<void> _addNewTerminal() async {
    final config = await _showConnectionChooser();
    if (config != null) {
      _manager.addTerminal(config);
    }
  }
}

/// Bottom sheet for quick connection selection
class _ConnectionChooserSheet extends StatelessWidget {
  final List<ConnectionConfig> savedConnections;
  final Future<ConnectionConfig?> Function() onNewConnection;

  const _ConnectionChooserSheet({
    required this.savedConnections,
    required this.onNewConnection,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Connect',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // Saved connections
          if (savedConnections.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              // Show ~4.5 items (each ~68px) to hint that scrolling is available
              constraints: const BoxConstraints(maxHeight: 310),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: savedConnections.length,
                itemBuilder: (context, index) {
                  final config = savedConnections[index];
                  return ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(config.name),
                    subtitle: Text(
                      '${config.username}@${config.host}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: config.startupCommand != null
                        ? Icon(
                            Icons.play_circle_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(config),
                  );
                },
              ),
            ),
          ],
          const Divider(height: 1),
          // New connection option
          ListTile(
            leading: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('New Connection'),
            onTap: () async {
              final config = await onNewConnection();
              if (context.mounted && config != null) {
                Navigator.of(context).pop(config);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Compact icon button for header bar
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
