import 'dart:io';

import 'package:flutter/material.dart';

import '../connection/connection_dialog.dart';
import 'split_view.dart';
import 'workspace_manager.dart';

/// Main page with workspace management and terminal display
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final WorkspaceManager _manager;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _manager = WorkspaceManager();
    _pageController = PageController(initialPage: _manager.currentIndex);
    _manager.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    _pageController.dispose();
    super.dispose();
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
          final config = await ConnectionDialog.show(context);
          if (config != null) {
            _manager.splitTerminal(nodeId, config, horizontal);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

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

  Future<void> _addNewTerminal() async {
    final config = await ConnectionDialog.show(context);
    if (config != null) {
      _manager.addTerminal(config);
    }
  }
}
