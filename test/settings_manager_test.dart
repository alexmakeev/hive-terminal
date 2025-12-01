import 'package:flutter_test/flutter_test.dart';
import 'package:hive_terminal/features/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsManager', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default SSH folder path is null', () {
      final settings = SettingsManager();
      expect(settings.sshFolderPath, isNull);
      expect(settings.hasAccess, isFalse);
    });

    test('load restores saved SSH folder path', () async {
      SharedPreferences.setMockInitialValues({'ssh_folder_path': '/home/user/.ssh'});

      final settings = SettingsManager();
      await settings.load();

      expect(settings.sshFolderPath, '/home/user/.ssh');
      expect(settings.hasAccess, isTrue);
    });

    test('setSshFolderPath updates path', () async {
      final settings = SettingsManager();

      await settings.setSshFolderPath('/test/path');
      expect(settings.sshFolderPath, '/test/path');
      expect(settings.hasAccess, isTrue);

      await settings.setSshFolderPath(null);
      expect(settings.sshFolderPath, isNull);
      expect(settings.hasAccess, isFalse);
    });

    test('notifies listeners on changes', () async {
      final settings = SettingsManager();
      var notified = false;
      settings.addListener(() => notified = true);

      await settings.setSshFolderPath('/some/path');
      expect(notified, isTrue);
    });
  });
}
