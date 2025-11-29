import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// File logger with rotation support
class FileLogger {
  static FileLogger? _instance;
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const String logFileName = 'log.txt';
  static const String backupFileName = 'log.old.txt';

  File? _logFile;
  File? _backupFile;
  bool _initialized = false;

  FileLogger._();

  static FileLogger get instance {
    _instance ??= FileLogger._();
    return _instance!;
  }

  /// Initialize logger - call once at app startup
  Future<void> init() async {
    if (_initialized) return;

    try {
      final logDir = await _getLogDirectory();
      _logFile = File(path.join(logDir, logFileName));
      _backupFile = File(path.join(logDir, backupFileName));

      // Create log file if doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }

      // Check rotation
      await _rotateIfNeeded();

      _initialized = true;

      // Log startup
      await log('=== App Started ===');
      await log('Platform: ${Platform.operatingSystem}');
      await log('Version: ${Platform.operatingSystemVersion}');
      await log('Executable: ${Platform.resolvedExecutable}');
      await log('Working directory: ${Directory.current.path}');
    } catch (e, stack) {
      debugPrint('Failed to initialize file logger: $e\n$stack');
    }
  }

  /// Get log directory based on platform
  Future<String> _getLogDirectory() async {
    if (Platform.isWindows) {
      // Use app directory on Windows
      final exeDir = path.dirname(Platform.resolvedExecutable);
      return exeDir;
    } else if (Platform.isMacOS) {
      // ~/Library/Logs/HiveTerminal
      final home = Platform.environment['HOME'] ?? '/tmp';
      final logDir = path.join(home, 'Library', 'Logs', 'HiveTerminal');
      await Directory(logDir).create(recursive: true);
      return logDir;
    } else if (Platform.isLinux) {
      // ~/.local/share/hive-terminal/logs
      final home = Platform.environment['HOME'] ?? '/tmp';
      final logDir = path.join(home, '.local', 'share', 'hive-terminal', 'logs');
      await Directory(logDir).create(recursive: true);
      return logDir;
    } else {
      // Fallback to temp directory
      return Directory.systemTemp.path;
    }
  }

  /// Rotate log file if it exceeds max size
  Future<void> _rotateIfNeeded() async {
    if (_logFile == null) return;

    try {
      if (await _logFile!.exists()) {
        final stat = await _logFile!.stat();
        if (stat.size >= maxFileSize) {
          // Delete old backup if exists
          if (await _backupFile!.exists()) {
            await _backupFile!.delete();
          }
          // Rename current log to backup
          await _logFile!.rename(_backupFile!.path);
          // Create new log file
          _logFile = File(_logFile!.path);
          await _logFile!.create();
          await log('=== Log rotated (previous file exceeded ${maxFileSize ~/ 1024 ~/ 1024}MB) ===');
        }
      }
    } catch (e) {
      debugPrint('Failed to rotate log: $e');
    }
  }

  /// Log a message with timestamp
  Future<void> log(String message) async {
    if (_logFile == null) {
      debugPrint('[FileLogger not initialized] $message');
      return;
    }

    try {
      final timestamp = DateTime.now().toIso8601String();
      final line = '[$timestamp] $message\n';

      await _logFile!.writeAsString(line, mode: FileMode.append);

      // Also print to console in debug mode
      if (kDebugMode) {
        debugPrint(message);
      }
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  /// Log an error with stack trace
  Future<void> logError(String message, Object error, [StackTrace? stackTrace]) async {
    await log('ERROR: $message');
    await log('  Exception: $error');
    if (stackTrace != null) {
      await log('  Stack trace:\n$stackTrace');
    }
  }

  /// Get path to current log file
  String? get logFilePath => _logFile?.path;

  /// Read current log contents (for debugging/sharing)
  Future<String?> readLog() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      debugPrint('Failed to read log: $e');
    }
    return null;
  }
}

/// Global logger instance for convenience
FileLogger get logger => FileLogger.instance;
