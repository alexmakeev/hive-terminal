import 'dart:io';

import 'package:flutter/material.dart';

import '../connection/connection_dialog.dart';
import '../connection/connection_repository.dart';
import '../connection/saved_connections_page.dart';
import '../connection/ssh_session.dart';
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
  late final PageController _pageController;
  late final ConnectionRepository _connectionRepository;

  @override
  void initState() {
    super.initState();
    _manager = WorkspaceManager();
    _pageController = PageController(initialPage: _manager.currentIndex);
    _connectionRepository = ConnectionRepository();
    _connectionRepository.load();
    _manager.addListener(_onManagerChanged);
    _connectionRepository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    _connectionRepository.removeListener(_onRepositoryChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  void _onManagerChanged() {
    setState(() {});
    // Sync page controller with manager
    if (_pageController.hasClients &&
        _pageController.page?.round() != _manager.currentIndex) {
      _pageController.animateToPage(
        _manager.currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.hive,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Hive Terminal'),
          ],
        ),
        actions: [
          // Saved connections button
          IconButton(
            icon: const Icon(Icons.bookmark),
            tooltip: 'Saved Connections',
            onPressed: _openSavedConnections,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
        ],
      ),
      body: Column(
        children: [
          // Workspace tabs (optional, for desktop)
          if (_isDesktop) _buildWorkspaceTabs(),

          // Main content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                if (index == _manager.workspaces.length) {
                  // Swiped to "add new" page
                  _manager.addWorkspace();
                } else {
                  _manager.setCurrentIndex(index);
                }
              },
              itemCount: _manager.workspaces.length + 1, // +1 for "add new" page
              itemBuilder: (context, index) {
                if (index == _manager.workspaces.length) {
                  // "Add new workspace" page
                  return _buildAddWorkspacePage();
                }
                return _buildWorkspace(_manager.workspaces[index]);
              },
            ),
          ),

          // Page indicator (for mobile)
          if (!_isDesktop && _manager.workspaces.length > 1)
            _buildPageIndicator(),
        ],
      ),
    );
  }

  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Widget _buildWorkspaceTabs() {
    return Container(
      height: 36,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
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
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        if (_manager.workspaces.length > 1)
                          InkWell(
                            onTap: () => _manager.removeWorkspace(workspace.id),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
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
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _manager.addWorkspace(),
            tooltip: 'Add Workspace',
          ),
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
        onClose: (nodeId) => _manager.closeTerminal(nodeId),
        onSplit: (nodeId, horizontal) async {
          final result = await _showConnectionChooser();
          if (result != null) {
            _manager.splitTerminal(nodeId, result, horizontal);
          }
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
              onPressed: _openSavedConnections,
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

  Widget _buildAddWorkspacePage() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_box_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'New Workspace',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe to create',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      height: 32,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _manager.workspaces.length + 1,
          (index) {
            final isLast = index == _manager.workspaces.length;
            final isSelected = index == _manager.currentIndex;

            return Container(
              width: isLast ? 16 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
              ),
              child: isLast
                  ? Icon(
                      Icons.add,
                      size: 6,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    )
                  : null,
            );
          },
        ),
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
              constraints: const BoxConstraints(maxHeight: 200),
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
