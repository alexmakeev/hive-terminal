import 'package:flutter_test/flutter_test.dart';
import 'package:hive_terminal/features/connection/ssh_session.dart';
import 'package:hive_terminal/features/workspace/workspace_manager.dart';

void main() {
  group('WorkspaceManager', () {
    late WorkspaceManager manager;

    setUp(() {
      manager = WorkspaceManager();
    });

    test('starts with one empty workspace', () {
      expect(manager.workspaces.length, 1);
      expect(manager.currentIndex, 0);
      expect(manager.currentWorkspace, isNotNull);
      expect(manager.currentWorkspace!.isEmpty, isTrue);
    });

    test('addWorkspace creates new workspace and switches to it', () {
      final workspace = manager.addWorkspace();
      expect(manager.workspaces.length, 2);
      expect(manager.currentIndex, 1);
      expect(manager.currentWorkspace, workspace);
      expect(workspace.name, 'Workspace 2');
    });

    test('setCurrentIndex switches workspace', () {
      manager.addWorkspace();
      manager.addWorkspace();
      expect(manager.currentIndex, 2);

      manager.setCurrentIndex(0);
      expect(manager.currentIndex, 0);
    });

    test('setCurrentIndex ignores invalid index', () {
      manager.setCurrentIndex(-1);
      expect(manager.currentIndex, 0);

      manager.setCurrentIndex(100);
      expect(manager.currentIndex, 0);
    });

    test('removeWorkspace removes workspace', () {
      manager.addWorkspace();
      final firstId = manager.workspaces.first.id;

      manager.removeWorkspace(firstId);
      expect(manager.workspaces.length, 1);
    });

    test('removeWorkspace creates new if all removed', () {
      final id = manager.workspaces.first.id;
      manager.removeWorkspace(id);

      expect(manager.workspaces.length, 1);
      expect(manager.workspaces.first.id, isNot(id));
    });

    test('addTerminal adds terminal to current workspace', () {
      final config = ConnectionConfig(
        id: 'test-id',
        name: 'Test Server',
        host: 'localhost',
        username: 'user',
      );

      manager.addTerminal(config);

      expect(manager.currentWorkspace!.isEmpty, isFalse);
      expect(manager.currentWorkspace!.root, isA<TerminalNode>());
    });

    test('addTerminal creates split when workspace has terminal', () {
      final config1 = ConnectionConfig(
        id: 'test-1',
        name: 'Server 1',
        host: 'localhost',
        username: 'user',
      );
      final config2 = ConnectionConfig(
        id: 'test-2',
        name: 'Server 2',
        host: 'localhost',
        username: 'user',
      );

      manager.addTerminal(config1);
      manager.addTerminal(config2);

      expect(manager.currentWorkspace!.root, isA<SplitContainerNode>());
      final container = manager.currentWorkspace!.root as SplitContainerNode;
      expect(container.children.length, 2);
      expect(container.isHorizontal, isTrue);
    });

    test('closeTerminal removes terminal', () {
      final config = ConnectionConfig(
        id: 'test-id',
        name: 'Test',
        host: 'localhost',
        username: 'user',
      );

      manager.addTerminal(config);
      final nodeId = manager.currentWorkspace!.root!.id;

      manager.closeTerminal(nodeId);
      expect(manager.currentWorkspace!.isEmpty, isTrue);
    });
  });

  group('Workspace', () {
    test('isEmpty returns true when no root', () {
      final workspace = Workspace(name: 'Test');
      expect(workspace.isEmpty, isTrue);
    });

    test('isEmpty returns false when has root', () {
      final config = ConnectionConfig(
        id: 'test',
        name: 'Test',
        host: 'localhost',
        username: 'user',
      );
      final pane = TerminalPane(config: config);
      final node = TerminalNode(pane: pane);

      final workspace = Workspace(name: 'Test', root: node);
      expect(workspace.isEmpty, isFalse);
    });
  });

  group('ConnectionConfig', () {
    test('toJson and fromJson roundtrip', () {
      final config = ConnectionConfig(
        id: 'test-id',
        name: 'My Server',
        host: 'example.com',
        port: 2222,
        username: 'admin',
      );

      final json = config.toJson();
      final restored = ConnectionConfig.fromJson(json);

      expect(restored.id, config.id);
      expect(restored.name, config.name);
      expect(restored.host, config.host);
      expect(restored.port, config.port);
      expect(restored.username, config.username);
    });

    test('fromJson uses default port 22', () {
      final json = {
        'id': 'test',
        'name': 'Server',
        'host': 'localhost',
        'username': 'user',
      };

      final config = ConnectionConfig.fromJson(json);
      expect(config.port, 22);
    });
  });

  group('SplitContainerNode', () {
    test('creates equal ratios by default', () {
      final config = ConnectionConfig(
        id: 'test',
        name: 'Test',
        host: 'localhost',
        username: 'user',
      );
      final pane1 = TerminalPane(config: config);
      final pane2 = TerminalPane(config: config);
      final node1 = TerminalNode(pane: pane1);
      final node2 = TerminalNode(pane: pane2);

      final container = SplitContainerNode(
        isHorizontal: true,
        children: [node1, node2],
      );

      expect(container.ratios.length, 2);
      expect(container.ratios[0], 0.5);
      expect(container.ratios[1], 0.5);
    });
  });

  group('Flatten split structure (Phase 5)', () {
    late WorkspaceManager manager;
    late ConnectionConfig config1;
    late ConnectionConfig config2;
    late ConnectionConfig config3;

    setUp(() {
      manager = WorkspaceManager();
      config1 = ConnectionConfig(id: 't1', name: 'S1', host: 'h1', username: 'u');
      config2 = ConnectionConfig(id: 't2', name: 'S2', host: 'h2', username: 'u');
      config3 = ConnectionConfig(id: 't3', name: 'S3', host: 'h3', username: 'u');
    });

    test('split same direction flattens to single container', () {
      // Add first two terminals (creates horizontal split)
      manager.addTerminal(config1);
      manager.addTerminal(config2);

      // Get the second terminal's id
      final container = manager.currentWorkspace!.root as SplitContainerNode;
      final secondNodeId = container.children[1].id;

      // Split second terminal horizontally (same direction)
      manager.splitTerminal(secondNodeId, config3, true);

      // Should flatten: [A, B, C] not [A, [B, C]]
      final newRoot = manager.currentWorkspace!.root as SplitContainerNode;
      expect(newRoot.children.length, 3);
      expect(newRoot.isHorizontal, isTrue);
    });

    test('split different direction creates nested container', () {
      // Add first two terminals (creates horizontal split)
      manager.addTerminal(config1);
      manager.addTerminal(config2);

      final container = manager.currentWorkspace!.root as SplitContainerNode;
      final secondNodeId = container.children[1].id;

      // Split second terminal vertically (different direction)
      manager.splitTerminal(secondNodeId, config3, false);

      // Should nest: [A, [B, C]]
      final newRoot = manager.currentWorkspace!.root as SplitContainerNode;
      expect(newRoot.children.length, 2);
      expect(newRoot.children[1], isA<SplitContainerNode>());

      final nested = newRoot.children[1] as SplitContainerNode;
      expect(nested.isHorizontal, isFalse);
      expect(nested.children.length, 2);
    });
  });

  group('Move terminal (Phase 6)', () {
    late WorkspaceManager manager;
    late ConnectionConfig config1;
    late ConnectionConfig config2;
    late ConnectionConfig config3;

    setUp(() {
      manager = WorkspaceManager();
      config1 = ConnectionConfig(id: 't1', name: 'S1', host: 'h1', username: 'u');
      config2 = ConnectionConfig(id: 't2', name: 'S2', host: 'h2', username: 'u');
      config3 = ConnectionConfig(id: 't3', name: 'S3', host: 'h3', username: 'u');
    });

    test('move terminal to left of another', () {
      manager.addTerminal(config1);
      manager.addTerminal(config2);

      final container = manager.currentWorkspace!.root as SplitContainerNode;
      final firstId = container.children[0].id;
      final secondId = container.children[1].id;

      // Move second to left of first
      manager.moveTerminal(secondId, firstId, DropPosition.left);

      // Order should be reversed
      final newRoot = manager.currentWorkspace!.root as SplitContainerNode;
      expect(newRoot.children.length, 2);
      // Second terminal should now be first
      expect((newRoot.children[0] as TerminalNode).pane.config.name, 'S2');
      expect((newRoot.children[1] as TerminalNode).pane.config.name, 'S1');
    });

    test('move terminal to bottom creates vertical split', () {
      manager.addTerminal(config1);
      manager.addTerminal(config2);

      final container = manager.currentWorkspace!.root as SplitContainerNode;
      final firstId = container.children[0].id;
      final secondId = container.children[1].id;

      // Move second to bottom of first (creates vertical split)
      manager.moveTerminal(secondId, firstId, DropPosition.bottom);

      // Root should now be a vertical split with first and second stacked
      final newRoot = manager.currentWorkspace!.root as SplitContainerNode;
      expect(newRoot.isHorizontal, isFalse);
      expect(newRoot.children.length, 2);
    });

    test('move terminal to same position keeps structure', () {
      manager.addTerminal(config1);
      manager.addTerminal(config2);

      final container = manager.currentWorkspace!.root as SplitContainerNode;
      final firstId = container.children[0].id;
      final secondId = container.children[1].id;

      // Move second to right of first (same position)
      manager.moveTerminal(secondId, firstId, DropPosition.right);

      // Should still have two terminals
      final newRoot = manager.currentWorkspace!.root as SplitContainerNode;
      expect(newRoot.children.length, 2);
    });
  });
}
