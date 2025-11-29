import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_terminal/core/updater/update_service.dart';

/// Get expected asset name pattern for current platform
String? _getExpectedPattern() {
  if (Platform.isMacOS) return '.dmg';
  if (Platform.isWindows) return '-windows.zip';
  if (Platform.isLinux) return '.AppImage';
  if (Platform.isAndroid) return '.apk';
  return null;
}

/// Get expected asset name for current platform
String _getExpectedAssetName() {
  if (Platform.isMacOS) return 'hive-terminal.dmg';
  if (Platform.isWindows) return 'hive-terminal-windows.zip';
  if (Platform.isLinux) return 'hive-terminal-linux.AppImage';
  if (Platform.isAndroid) return 'app-release.apk';
  return 'unknown';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService.isNewerVersion', () {
    test('returns true when latest is newer (major)', () {
      expect(UpdateService.isNewerVersion('2.0.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('10.0.0', '9.0.0'), isTrue);
    });

    test('returns true when latest is newer (minor)', () {
      expect(UpdateService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.10.0', '1.9.0'), isTrue);
    });

    test('returns true when latest is newer (patch)', () {
      expect(UpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.10', '1.0.9'), isTrue);
    });

    test('returns false when versions are equal', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('2.3.4', '2.3.4'), isFalse);
    });

    test('returns false when current is newer', () {
      expect(UpdateService.isNewerVersion('1.0.0', '2.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('handles versions with different lengths', () {
      expect(UpdateService.isNewerVersion('1.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('2', '1.9.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.0', '1.0.0'), isFalse);
    });

    test('handles invalid versions gracefully', () {
      expect(UpdateService.isNewerVersion('invalid', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0', 'invalid'), isFalse);
      expect(UpdateService.isNewerVersion('', '1.0.0'), isFalse);
    });
  });

  group('UpdateService.getDownloadUrl', () {
    late UpdateService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'test-repo',
          currentVersion: '1.0.0',
        ),
      );
    });

    test('returns platform-specific URL when asset exists', () {
      final expectedAsset = _getExpectedAssetName();
      final releaseData = {
        'html_url': 'https://github.com/test/test-repo/releases/v1.0.0',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/test/test-repo/releases/download/v1.0.0/app-release.apk',
          },
          {
            'name': 'hive-terminal-windows.zip',
            'browser_download_url': 'https://github.com/test/test-repo/releases/download/v1.0.0/hive-terminal-windows.zip',
          },
          {
            'name': 'hive-terminal-linux.AppImage',
            'browser_download_url': 'https://github.com/test/test-repo/releases/download/v1.0.0/hive-terminal-linux.AppImage',
          },
          {
            'name': 'hive-terminal.dmg',
            'browser_download_url': 'https://github.com/test/test-repo/releases/download/v1.0.0/hive-terminal.dmg',
          },
        ],
      };

      final url = service.getDownloadUrl(releaseData);
      // Should find the asset matching current platform
      expect(url, contains(expectedAsset));
    });

    test('returns html_url when no matching asset for platform', () {
      final releaseData = {
        'html_url': 'https://github.com/test/test-repo/releases/v1.0.0',
        'assets': [
          {
            'name': 'some-unrelated-file.txt',
            'browser_download_url': 'https://github.com/test/test-repo/releases/download/v1.0.0/some-unrelated-file.txt',
          },
        ],
      };

      final url = service.getDownloadUrl(releaseData);
      expect(url, equals('https://github.com/test/test-repo/releases/v1.0.0'));
    });

    test('returns null when no assets', () {
      final releaseData = {
        'html_url': 'https://github.com/test/test-repo/releases/v1.0.0',
        'assets': <dynamic>[],
      };

      final url = service.getDownloadUrl(releaseData);
      expect(url, isNull);
    });

    test('returns null when assets is null', () {
      final releaseData = {
        'html_url': 'https://github.com/test/test-repo/releases/v1.0.0',
      };

      final url = service.getDownloadUrl(releaseData);
      expect(url, isNull);
    });
  });

  group('UpdateService.checkForUpdate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns UpdateInfo when newer version available', () async {
      final expectedPattern = _getExpectedPattern();
      final expectedAsset = _getExpectedAssetName();

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('api.github.com'));
        expect(request.url.toString(), contains('releases/latest'));

        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
            'html_url': 'https://github.com/test/repo/releases/tag/v2.0.0',
            'body': 'Release notes here',
            'published_at': '2024-01-01T00:00:00Z',
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': 'https://github.com/test/repo/releases/download/v2.0.0/app-release.apk',
              },
              {
                'name': 'hive-terminal-linux.AppImage',
                'browser_download_url': 'https://github.com/test/repo/releases/download/v2.0.0/hive-terminal-linux.AppImage',
              },
              {
                'name': 'hive-terminal-windows.zip',
                'browser_download_url': 'https://github.com/test/repo/releases/download/v2.0.0/hive-terminal-windows.zip',
              },
              {
                'name': 'hive-terminal.dmg',
                'browser_download_url': 'https://github.com/test/repo/releases/download/v2.0.0/hive-terminal.dmg',
              },
            ],
          }),
          200,
        );
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();

      expect(update, isNotNull);
      expect(update!.version, equals('2.0.0'));
      // Should find asset for current platform
      if (expectedPattern != null) {
        expect(update.downloadUrl, contains(expectedAsset));
      }
      expect(update.releaseNotes, equals('Release notes here'));
    });

    test('returns null when no newer version', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.0.0',
            'html_url': 'https://github.com/test/repo/releases/tag/v1.0.0',
            'body': 'Current version',
            'published_at': '2024-01-01T00:00:00Z',
            'assets': [],
          }),
          200,
        );
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();
      expect(update, isNull);
    });

    test('returns null when current is newer than latest', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.9.0',
            'html_url': 'https://github.com/test/repo/releases/tag/v0.9.0',
            'body': 'Old version',
            'published_at': '2024-01-01T00:00:00Z',
            'assets': [],
          }),
          200,
        );
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();
      expect(update, isNull);
    });

    test('returns null on API error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();
      expect(update, isNull);
    });

    test('returns null on network error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();
      expect(update, isNull);
    });

    test('handles tag without v prefix', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': '2.0.0', // No 'v' prefix
            'html_url': 'https://github.com/test/repo/releases/tag/2.0.0',
            'body': 'Release notes',
            'published_at': '2024-01-01T00:00:00Z',
            'assets': [],
          }),
          200,
        );
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();
      expect(update, isNotNull);
      expect(update!.version, equals('2.0.0'));
    });

    test('fallbacks to html_url when no matching asset', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
            'html_url': 'https://github.com/test/repo/releases/tag/v2.0.0',
            'body': 'Release notes',
            'published_at': '2024-01-01T00:00:00Z',
            'assets': [
              {
                'name': 'some-other-file.txt',
                'browser_download_url': 'https://example.com/file.txt',
              },
            ],
          }),
          200,
        );
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      final update = await service.forceCheckForUpdate();
      expect(update, isNotNull);
      expect(update!.downloadUrl, equals('https://github.com/test/repo/releases/tag/v2.0.0'));
    });
  });

  group('UpdateService.shouldCheck', () {
    test('returns true when never checked before', () async {
      SharedPreferences.setMockInitialValues({});

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
          checkInterval: Duration(hours: 24),
        ),
      );

      expect(await service.shouldCheck(), isTrue);
    });

    test('returns false when checked recently', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'update_last_check': now,
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
          checkInterval: Duration(hours: 24),
        ),
      );

      expect(await service.shouldCheck(), isFalse);
    });

    test('returns true when interval has passed', () async {
      final oldTime = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'update_last_check': oldTime,
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'test',
          repo: 'repo',
          currentVersion: '1.0.0',
          checkInterval: Duration(hours: 24),
        ),
      );

      expect(await service.shouldCheck(), isTrue);
    });
  });

  group('UpdateService integration', () {
    test('full update check flow with mocked HTTP', () async {
      SharedPreferences.setMockInitialValues({});
      final expectedAsset = _getExpectedAssetName();

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
            'html_url': 'https://github.com/alexmakeev/hive-terminal/releases/tag/v2.0.0',
            'body': '## What\'s New\n- Feature 1\n- Feature 2',
            'published_at': '2024-06-01T12:00:00Z',
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': 'https://github.com/alexmakeev/hive-terminal/releases/download/v2.0.0/app-release.apk',
              },
              {
                'name': 'hive-terminal-linux.AppImage',
                'browser_download_url': 'https://github.com/alexmakeev/hive-terminal/releases/download/v2.0.0/hive-terminal-linux.AppImage',
              },
              {
                'name': 'hive-terminal-windows.zip',
                'browser_download_url': 'https://github.com/alexmakeev/hive-terminal/releases/download/v2.0.0/hive-terminal-windows.zip',
              },
              {
                'name': 'hive-terminal.dmg',
                'browser_download_url': 'https://github.com/alexmakeev/hive-terminal/releases/download/v2.0.0/hive-terminal.dmg',
              },
            ],
          }),
          200,
        );
      });

      final service = UpdateService(
        const UpdateConfig(
          owner: 'alexmakeev',
          repo: 'hive-terminal',
          currentVersion: '1.0.0',
        ),
        httpClient: mockClient,
      );

      // Should check (never checked before)
      expect(await service.shouldCheck(), isTrue);

      // Force check for update
      final update = await service.forceCheckForUpdate();

      // Verify update info
      expect(update, isNotNull);
      expect(update!.version, equals('2.0.0'));
      expect(update.releaseNotes, contains('Feature 1'));

      // Should get the platform-specific asset URL
      expect(update.downloadUrl, contains(expectedAsset));

      // Record the check
      await service.recordCheck();

      // Should not check again immediately
      expect(await service.shouldCheck(), isFalse);
    });
  });
}
