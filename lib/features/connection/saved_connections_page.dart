import 'package:flutter/material.dart';

import 'connection_dialog.dart';
import 'connection_repository.dart';
import 'connection_config.dart';

/// Page for managing saved connections
class SavedConnectionsPage extends StatefulWidget {
  final ConnectionRepository repository;
  final void Function(ConnectionConfig config)? onConnect;

  const SavedConnectionsPage({
    super.key,
    required this.repository,
    this.onConnect,
  });

  @override
  State<SavedConnectionsPage> createState() => _SavedConnectionsPageState();
}

class _SavedConnectionsPageState extends State<SavedConnectionsPage> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final connections = widget.repository.connections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Connection',
            onPressed: _addConnection,
          ),
        ],
      ),
      body: connections.isEmpty
          ? _buildEmptyState()
          : _buildConnectionsList(connections),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No saved connections',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a connection to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addConnection,
            icon: const Icon(Icons.add),
            label: const Text('Add Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsList(List<ConnectionConfig> connections) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: connections.length,
      onReorder: (oldIndex, newIndex) {
        widget.repository.reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final config = connections[index];
        return _ConnectionTile(
          key: ValueKey(config.id),
          config: config,
          index: index,
          onTap: () => _connect(config),
          onEdit: () => _editConnection(config),
          onDelete: () => _deleteConnection(config),
        );
      },
    );
  }

  Future<void> _addConnection() async {
    final result = await ConnectionDialog.show(context);
    if (result != null && result.addToFavorites) {
      await widget.repository.save(result.config);
    }
  }

  Future<void> _editConnection(ConnectionConfig config) async {
    final result = await ConnectionDialog.edit(context, config);
    if (result != null) {
      await widget.repository.save(result.config);
    }
  }

  Future<void> _deleteConnection(ConnectionConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Delete "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repository.delete(config.id);
    }
  }

  void _connect(ConnectionConfig config) {
    widget.onConnect?.call(config);
    Navigator.of(context).pop();
  }
}

class _ConnectionTile extends StatelessWidget {
  final ConnectionConfig config;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConnectionTile({
    super.key,
    required this.config,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.computer),
        title: Text(config.name),
        subtitle: Text(
          '${config.username}@${config.host}:${config.port}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.startupCommand != null)
              Tooltip(
                message: 'Auto-runs: ${config.startupCommand}',
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                Icons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
