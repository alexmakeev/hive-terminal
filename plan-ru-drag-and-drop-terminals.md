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

### 2. Focus Zoom (Увеличение при фокусе)
- При наведении/фокусе терминал увеличивается на ~30%
- Соседние терминалы пропорционально уменьшаются
- **Никогда не выходит за пределы окна** — ограничен constraints
- Плавная анимация (200-300ms)
- При потере фокуса — возврат к исходным пропорциям

```
До фокуса:           После фокуса на B:
+-----+-----+        +---+-------+
|  A  |  B  |   →    | A |   B   |
+-----+-----+        +---+-------+
 50%   50%            35%   65%
```

### 3. Компактный UI
- **Тонкие разделители**: 2px вместо 4px между терминалами
- **Тонкие заголовки**: 16px вместо 32px (в 2 раза меньше)
- Кнопки в заголовке уменьшить пропорционально
- Минималистичный вид — больше места для контента

### 4. Pinch-to-Zoom (Размер шрифта)
- **Pinch out** (пальцы врозь) → увеличить шрифт
- **Pinch in** (щипок) → уменьшить шрифт
- Каждый терминал может иметь свой размер шрифта
- Сохранять размер шрифта для каждого соединения
- Диапазон: 8px - 24px (по умолчанию 14px)
- Плавное изменение с визуальным фидбеком

```
Жест:          Результат:
  \/           fontSize -= 1
  /\           fontSize += 1
```

### 5. Drag & Drop терминалов
- Взял терминал за заголовок → он "отцепляется"
- Его место сразу занимает сосед (колонка/ряд схлопывается)
- Визуальные drop-зоны на краях других терминалов:
  - Левый/правый край → горизонтальный сплит
  - Верхний/нижний край → вертикальный сплит
- При отпускании → терминал вставляется в новое место

### 6. Drop-зоны
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

### Phase 1: Компактный UI (быстро)
1. [ ] Тонкие разделители: 4px → 2px
2. [ ] Тонкие заголовки: 32px → 16px
3. [ ] Уменьшить кнопки в заголовке
4. [ ] Исправить двойную иконку drag на странице избранного

### Phase 2: Pinch-to-Zoom
5. [ ] GestureDetector с onScaleUpdate для pinch
6. [ ] Динамический fontSize в TerminalStyle
7. [ ] Сохранение размера шрифта в SharedPreferences
8. [ ] Визуальный индикатор текущего размера

### Phase 3: Focus Zoom
9. [ ] Отслеживание фокуса/hover для каждого терминала
10. [ ] Анимированное изменение ratios при фокусе (+30%)
11. [ ] Ограничение: не выходить за пределы окна (min/max ratios)

### Phase 4: Flatten структуры
12. [ ] Изменить логику сплита для плоского списка

### Phase 5: Drag & Drop
13. [ ] Drag start: обёртка терминала в Draggable
14. [ ] Drop zones: визуальные зоны при перетаскивании
15. [ ] Drop handling: вставка в новое место
16. [ ] Auto-collapse: схлопывание пустых мест
17. [ ] Анимации: плавные переходы

## Feature branch

```bash
git checkout -b feature/terminal-drag-drop
```

## Ссылки

- Flutter Draggable: https://api.flutter.dev/flutter/widgets/Draggable-class.html
- DragTarget: https://api.flutter.dev/flutter/widgets/DragTarget-class.html
