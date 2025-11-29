# Plan: Drag & Drop Terminals

## Текущая проблема

При сплите терминалов создаётся вложенное дерево:
```
[Terminal1, [Terminal2, Terminal3]]  // 3-уровневое вложение
```

Нужно:
```
[Terminal1, Terminal2, Terminal3]  // плоский список в одном контейнере
```

## Требования

### 1. Плоская структура (Flatten)
- При сплите в том же направлении → добавлять в тот же контейнер
- `[A, B]` + split B horizontal → `[A, B, C]`
- `[A, B]` + split B vertical → `[A, [B, C]]` (другое направление = вложенность ок)

### 2. Drag & Drop терминалов
- Взял терминал за заголовок → он "отцепляется"
- Его место сразу занимает сосед (колонка/ряд схлопывается)
- Визуальные drop-зоны на краях других терминалов:
  - Левый/правый край → горизонтальный сплит
  - Верхний/нижний край → вертикальный сплит
- При отпускании → терминал вставляется в новое место

### 3. Drop-зоны
```
+------------------+
|       TOP        |  ← вертикальный сплит сверху
+------+----+------+
| LEFT | ?? | RIGHT|  ← горизонтальный сплит
+------+----+------+
|      BOTTOM      |  ← вертикальный сплит снизу
+------------------+
```

## Изменения в коде

### workspace_manager.dart

```dart
// Изменить _splitNode для flatten
SplitNode _splitNode(SplitNode node, String targetId, TerminalNode newNode, bool horizontal) {
  if (node is SplitContainerNode && node.isHorizontal == horizontal) {
    // Найти позицию target и вставить после него
    final targetIndex = node.children.indexWhere((c) => c.id == targetId);
    if (targetIndex != -1) {
      final newChildren = List<SplitNode>.from(node.children);
      newChildren.insert(targetIndex + 1, newNode);
      final newRatios = _recalculateRatios(newChildren.length);
      return SplitContainerNode(
        id: node.id,
        isHorizontal: horizontal,
        children: newChildren,
        ratios: newRatios,
      );
    }
  }
  // ... остальная логика
}

// Добавить метод для перемещения терминала
void moveTerminal(String terminalId, String targetId, DropPosition position) {
  // 1. Удалить терминал из текущего места (без удаления pane)
  // 2. Вставить в новое место согласно position
}
```

### split_view.dart

```dart
// Добавить Draggable обёртку для терминалов
class DraggableTerminal extends StatefulWidget {
  // ...
}

// Добавить DragTarget для drop-зон
class TerminalDropZone extends StatelessWidget {
  final DropPosition position; // left, right, top, bottom
  // ...
}
```

### Новые классы

```dart
enum DropPosition { left, right, top, bottom }

class TerminalDragData {
  final String terminalId;
  final TerminalPane pane;
}
```

## Этапы реализации

1. [ ] Flatten: изменить логику сплита для плоского списка
2. [ ] Drag start: обёртка терминала в Draggable
3. [ ] Drop zones: визуальные зоны при перетаскивании
4. [ ] Drop handling: вставка в новое место
5. [ ] Auto-collapse: схлопывание пустых мест
6. [ ] Анимации: плавные переходы

## Feature branch

```bash
git checkout -b feature/terminal-drag-drop
```

## Ссылки

- Flutter Draggable: https://api.flutter.dev/flutter/widgets/Draggable-class.html
- DragTarget: https://api.flutter.dev/flutter/widgets/DragTarget-class.html
