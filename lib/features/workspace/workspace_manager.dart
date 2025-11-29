import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../connection/ssh_session.dart';

/// Represents a single terminal pane in a workspace
class TerminalPane {
  final String id;
  final ConnectionConfig config;
  final GlobalKey key;

  TerminalPane({
    String? id,
    required this.config,
  })  : id = id ?? const Uuid().v4(),
        key = GlobalKey();
}

/// Represents a split node (either a terminal or a container with children)
abstract class SplitNode {
  String get id;
}

class TerminalNode extends SplitNode {
  @override
  final String id;
  final TerminalPane pane;

  TerminalNode({required this.pane}) : id = pane.id;
}

class SplitContainerNode extends SplitNode {
  @override
  final String id;
  final bool isHorizontal;
  final List<SplitNode> children;
  final List<double> ratios;

  SplitContainerNode({
    String? id,
    required this.isHorizontal,
    required this.children,
    List<double>? ratios,
  })  : id = id ?? const Uuid().v4(),
        ratios = ratios ?? List.filled(children.length, 1.0 / children.length);
}

/// A single workspace that can contain multiple split terminals
class Workspace {
  final String id;
  final String name;
  SplitNode? root;

  Workspace({
    String? id,
    required this.name,
    this.root,
  }) : id = id ?? const Uuid().v4();

  bool get isEmpty => root == null;
}

/// Manages all workspaces
class WorkspaceManager extends ChangeNotifier {
  final List<Workspace> _workspaces = [];
  int _currentIndex = 0;

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  int get currentIndex => _currentIndex;
  Workspace? get currentWorkspace =>
      _workspaces.isNotEmpty ? _workspaces[_currentIndex] : null;

  WorkspaceManager() {
    // Start with one empty workspace
    _workspaces.add(Workspace(name: 'Workspace 1'));
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _workspaces.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  Workspace addWorkspace() {
    final workspace = Workspace(name: 'Workspace ${_workspaces.length + 1}');
    _workspaces.add(workspace);
    _currentIndex = _workspaces.length - 1;
    notifyListeners();
    return workspace;
  }

  void removeWorkspace(String id) {
    final index = _workspaces.indexWhere((w) => w.id == id);
    if (index == -1) return;

    _workspaces.removeAt(index);
    if (_currentIndex >= _workspaces.length) {
      _currentIndex = _workspaces.length - 1;
    }
    if (_workspaces.isEmpty) {
      addWorkspace();
    }
    notifyListeners();
  }

  void addTerminal(ConnectionConfig config) {
    if (currentWorkspace == null) return;

    final pane = TerminalPane(config: config);
    final node = TerminalNode(pane: pane);

    if (currentWorkspace!.root == null) {
      currentWorkspace!.root = node;
    } else {
      // Replace root with a horizontal split
      currentWorkspace!.root = SplitContainerNode(
        isHorizontal: true,
        children: [currentWorkspace!.root!, node],
      );
    }
    notifyListeners();
  }

  void splitTerminal(String nodeId, ConnectionConfig config, bool horizontal) {
    if (currentWorkspace?.root == null) return;

    final newPane = TerminalPane(config: config);
    final newNode = TerminalNode(pane: newPane);

    currentWorkspace!.root = _splitNode(
      currentWorkspace!.root!,
      nodeId,
      newNode,
      horizontal,
    );
    notifyListeners();
  }

  SplitNode _splitNode(
    SplitNode node,
    String targetId,
    TerminalNode newNode,
    bool horizontal,
  ) {
    if (node.id == targetId) {
      return SplitContainerNode(
        isHorizontal: horizontal,
        children: [node, newNode],
      );
    }

    if (node is SplitContainerNode) {
      return SplitContainerNode(
        id: node.id,
        isHorizontal: node.isHorizontal,
        children: node.children
            .map((child) => _splitNode(child, targetId, newNode, horizontal))
            .toList(),
        ratios: node.ratios,
      );
    }

    return node;
  }

  void closeTerminal(String nodeId) {
    if (currentWorkspace?.root == null) return;

    if (currentWorkspace!.root!.id == nodeId) {
      currentWorkspace!.root = null;
      notifyListeners();
      return;
    }

    currentWorkspace!.root = _removeNode(currentWorkspace!.root!, nodeId);
    notifyListeners();
  }

  SplitNode? _removeNode(SplitNode node, String targetId) {
    if (node is SplitContainerNode) {
      final newChildren = <SplitNode>[];
      for (final child in node.children) {
        if (child.id == targetId) {
          continue; // Skip removed node
        }
        final result = _removeNode(child, targetId);
        if (result != null) {
          newChildren.add(result);
        }
      }

      if (newChildren.isEmpty) {
        return null;
      }
      if (newChildren.length == 1) {
        return newChildren.first;
      }
      return SplitContainerNode(
        id: node.id,
        isHorizontal: node.isHorizontal,
        children: newChildren,
      );
    }

    return node;
  }
}
