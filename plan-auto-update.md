# Plan: Auto-Update System

## Текущее состояние

- Проверка обновлений через GitHub API ✅
- Скачивание через nightly.link ✅ (исправлено: run ID вместо latest)
- Ручное скачивание и установка ❌

## Цель

После скачивания обновления:
1. Заменить текущее приложение новой версией
2. Показать "Перезапустите приложение"
3. После перезапуска — новая версия работает

---

## Платформо-специфичные решения

### macOS

**Вариант 1: Sparkle Framework** (рекомендуется)
- Стандартный механизм обновлений для macOS
- Поддерживает DMG, ZIP, pkg
- Автоматическая верификация подписи
- Требует: подпись приложения (code signing)

```dart
// Интеграция через MethodChannel
final sparkle = MethodChannel('com.hiveterminal/sparkle');
await sparkle.invokeMethod('checkForUpdates');
```

**Вариант 2: Ручная замена**
```bash
# 1. Скачать новую версию
curl -L "$downloadUrl" -o /tmp/update.zip

# 2. Распаковать
unzip /tmp/update.zip -d /tmp/HiveTerminal.app

# 3. Заменить (приложение должно быть закрыто)
rm -rf "/Applications/Hive Terminal.app"
mv /tmp/HiveTerminal.app "/Applications/Hive Terminal.app"

# 4. Запустить новую версию
open "/Applications/Hive Terminal.app"
```

**Проблема**: приложение не может заменить само себя пока работает.

**Решение**: Helper tool
```
1. Основное приложение скачивает update.zip
2. Распаковывает в ~/Library/Caches/HiveTerminal/pending-update/
3. Запускает helper: /path/to/updater-helper
4. Завершает себя
5. Helper ждёт завершения, копирует файлы, запускает новую версию
```

---

### Windows

**Вариант 1: MSIX Auto-Update**
- Если распространяем через Microsoft Store или как MSIX
- Встроенный механизм обновлений Windows

**Вариант 2: Squirrel.Windows** (рекомендуется для non-Store)
- Популярный фреймворк (используется Electron apps)
- Создаёт Setup.exe и поддерживает delta-updates

**Вариант 3: Ручная замена**
```batch
:: updater.bat
@echo off
timeout /t 2 /nobreak
xcopy /E /Y "%TEMP%\HiveTerminal\*" "%PROGRAMFILES%\HiveTerminal\"
start "" "%PROGRAMFILES%\HiveTerminal\hive_terminal.exe"
```

---

### Linux

**Вариант 1: AppImage + AppImageUpdate**
- AppImage поддерживает встроенный механизм обновлений
- Требует: zsync файл на сервере

```dart
// Проверка и обновление
Process.run('appimageupdatetool', [appImagePath]);
```

**Вариант 2: Flatpak**
- Если распространяем через Flathub
- `flatpak update com.hiveterminal.HiveTerminal`

**Вариант 3: Ручная замена**
```bash
#!/bin/bash
# 1. Скачать
wget "$downloadUrl" -O /tmp/HiveTerminal.AppImage

# 2. Сделать исполняемым
chmod +x /tmp/HiveTerminal.AppImage

# 3. Заменить
mv /tmp/HiveTerminal.AppImage ~/Applications/HiveTerminal.AppImage

# 4. Запустить
~/Applications/HiveTerminal.AppImage &
```

---

### iOS

- Только через App Store
- Никакого self-update (Apple policy)
- Можно показывать "Доступно обновление в App Store"

---

### Android

**Вариант 1: Play Store**
- In-app updates API
- Immediate update (блокирующий) или Flexible (фоновый)

```dart
// play_store_in_app_update package
final updateInfo = await InAppUpdate.checkForUpdate();
if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
  await InAppUpdate.performImmediateUpdate();
}
```

**Вариант 2: Direct APK** (для sideload)
```dart
// 1. Скачать APK
final file = await downloadFile(apkUrl, '/storage/emulated/0/Download/update.apk');

// 2. Открыть установщик
await OpenFile.open(file.path);
```

Требует: `REQUEST_INSTALL_PACKAGES` permission

---

## Архитектура решения

### UpdateManager (кроссплатформенный)

```dart
abstract class PlatformUpdater {
  Future<bool> canAutoUpdate();
  Future<void> downloadAndInstall(String url);
  Future<void> restartApp();
}

class MacOSUpdater implements PlatformUpdater {
  @override
  Future<bool> canAutoUpdate() async => true;

  @override
  Future<void> downloadAndInstall(String url) async {
    // 1. Download to temp
    // 2. Extract
    // 3. Launch helper
    // 4. Exit
  }
}

class WindowsUpdater implements PlatformUpdater { ... }
class LinuxUpdater implements PlatformUpdater { ... }
class AndroidUpdater implements PlatformUpdater { ... }
class IOSUpdater implements PlatformUpdater {
  @override
  Future<bool> canAutoUpdate() async => false; // Always false
}
```

### Helper Tool (native)

Для macOS/Windows/Linux нужен отдельный бинарник:

```
updater-helper [--wait-pid PID] [--source PATH] [--target PATH] [--launch PATH]
```

1. Ждёт завершения процесса с PID
2. Копирует source → target
3. Запускает приложение

**Сборка helper:**
- macOS: Swift или Objective-C (можно Go)
- Windows: C# или Go
- Linux: Go или Rust (статическая линковка)

---

## UI Flow

```
┌─────────────────────────────────────────┐
│ Update Available: v1.2.3                │
│                                         │
│ • Fixed SSH key loading                 │
│ • Added drag & drop terminals           │
│                                         │
│ [Skip]  [Remind Later]  [Update Now]    │
└─────────────────────────────────────────┘
          ↓ Update Now
┌─────────────────────────────────────────┐
│ Downloading update...                   │
│ ████████████░░░░░░░░ 60%               │
│                                         │
│ [Cancel]                                │
└─────────────────────────────────────────┘
          ↓ Complete
┌─────────────────────────────────────────┐
│ Update ready!                           │
│                                         │
│ Restart to apply the update.            │
│                                         │
│ [Restart Later]  [Restart Now]          │
└─────────────────────────────────────────┘
```

---

## Этапы реализации

### Phase 1: Базовый механизм
1. [ ] Download to temp directory
2. [ ] Extract/verify
3. [ ] Create helper tool (Go, кроссплатформенный)
4. [ ] Launch helper + exit

### Phase 2: Platform integration
5. [ ] macOS: code signing + notarization
6. [ ] Windows: certificate + SmartScreen
7. [ ] Linux: AppImageUpdate integration

### Phase 3: Advanced
8. [ ] Delta updates (только изменённые файлы)
9. [ ] Rollback mechanism
10. [ ] Background download
11. [ ] A/B testing updates

---

## Security Considerations

1. **HTTPS only** — все загрузки через HTTPS
2. **Checksum verification** — SHA256 хэш в метаданных
3. **Code signing** — подпись приложения
4. **Notarization** (macOS) — Apple проверка
5. **Certificate pinning** — опционально для параноиков

---

## Альтернативы

| Решение | Плюсы | Минусы |
|---------|-------|--------|
| Sparkle (macOS) | Стандарт, надёжно | Только macOS |
| Squirrel | Популярно | Только Windows |
| electron-updater | Кроссплатформенно | Для Electron |
| Custom helper | Полный контроль | Больше работы |
| App Stores | Без забот | Ограничения, review |

---

## Рекомендация

**MVP**: Custom helper на Go (один бинарник для всех desktop платформ)
- Go компилируется статически
- Кроссплатформенный
- Простая логика: wait → copy → launch

**Long-term**: Интеграция с нативными механизмами
- macOS: Sparkle
- Windows: MSIX или WinGet
- Linux: Flatpak / Snap
