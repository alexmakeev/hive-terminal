import 'package:flutter_test/flutter_test.dart';
import 'package:hive_terminal/features/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsManager', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default focus zoom is 1.3', () {
      final settings = SettingsManager();
      expect(settings.focusZoom, 1.3);
    });

    test('default SSH folder path is null', () {
      final settings = SettingsManager();
      expect(settings.sshFolderPath, isNull);
      expect(settings.hasAccess, isFalse);
    });

    test('load restores saved focus zoom', () async {
      SharedPreferences.setMockInitialValues({'focus_zoom': 1.2});

      final settings = SettingsManager();
      await settings.load();

      expect(settings.focusZoom, 1.2);
    });

    test('load restores saved SSH folder path', () async {
      SharedPreferences.setMockInitialValues({'ssh_folder_path': '/home/user/.ssh'});

      final settings = SettingsManager();
      await settings.load();

      expect(settings.sshFolderPath, '/home/user/.ssh');
      expect(settings.hasAccess, isTrue);
    });

    test('setFocusZoom clamps to valid range', () async {
      final settings = SettingsManager();

      await settings.setFocusZoom(0.5); // Below minimum
      expect(settings.focusZoom, 1.0);

      await settings.setFocusZoom(2.0); // Above maximum
      expect(settings.focusZoom, 1.5);

      await settings.setFocusZoom(1.25);
      expect(settings.focusZoom, 1.25);
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

      await settings.setFocusZoom(1.4);
      expect(notified, isTrue);
    });
  });
}
