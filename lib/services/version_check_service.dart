import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VersionCheckResult {
  final bool isUpdateRequired;
  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final String message;

  VersionCheckResult({
    required this.isUpdateRequired,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    required this.message,
  });
}

class VersionCheckService {
  static const String currentAppVersion = '1.0.0';
  static const String remoteVersionUrl =
      'https://raw.githubusercontent.com/akmtechofficial/info-App/master/version.json';
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/akmtechofficial/info-App/releases/latest';
  static const String defaultDownloadUrl =
      'https://raw.githubusercontent.com/akmtechofficial/info-App/master/app-release.apk';

  static Future<VersionCheckResult> checkVersionStatus() async {
    try {
      // 1. Check raw version.json configuration from GitHub repo
      final rawResponse = await http
          .get(Uri.parse(remoteVersionUrl))
          .timeout(const Duration(seconds: 5));

      if (rawResponse.statusCode == 200) {
        final data = jsonDecode(rawResponse.body);
        final bool isActive = data['is_active'] ?? true;
        final String minVersion = data['min_version'] ?? '1.0.0';
        final String latestVersion = data['latest_version'] ?? currentAppVersion;
        final String downloadUrl = data['download_url'] ?? defaultDownloadUrl;
        final String msg = data['message'] ??
            'A new required update for InfoApp is available. Please update the app to continue.';

        final bool isOutdated = _isVersionLower(currentAppVersion, minVersion);

        if (!isActive || isOutdated) {
          return VersionCheckResult(
            isUpdateRequired: true,
            currentVersion: currentAppVersion,
            latestVersion: latestVersion,
            updateUrl: downloadUrl.replaceAll('NumInfo-App', 'info-App'),
            message: msg,
          );
        }

        // App version.json is active and valid!
        return VersionCheckResult(
          isUpdateRequired: false,
          currentVersion: currentAppVersion,
          latestVersion: latestVersion,
          updateUrl: defaultDownloadUrl,
          message: 'App is up to date.',
        );
      } else if (rawResponse.statusCode == 404) {
        // If version.json was deleted on GitHub, trigger kill-switch!
        return VersionCheckResult(
          isUpdateRequired: true,
          currentVersion: currentAppVersion,
          latestVersion: '2.0.0',
          updateUrl: defaultDownloadUrl,
          message:
              'This application build or repository release has been deleted or revoked on GitHub.',
        );
      }

      // 2. Secondary GitHub Release API Check
      try {
        final releaseRes = await http
            .get(Uri.parse(githubReleasesApiUrl))
            .timeout(const Duration(seconds: 4));

        if (releaseRes.statusCode == 200) {
          final relData = jsonDecode(releaseRes.body);
          final String tagName =
              (relData['tag_name'] ?? '').toString().replaceAll('v', '');
          final List assets = relData['assets'] ?? [];

          if (tagName.isNotEmpty &&
              _isVersionLower(currentAppVersion, tagName)) {
            final String apkUrl = assets.isNotEmpty
                ? (assets.first['browser_download_url'] ?? defaultDownloadUrl)
                : defaultDownloadUrl;
            return VersionCheckResult(
              isUpdateRequired: true,
              currentVersion: currentAppVersion,
              latestVersion: tagName,
              updateUrl: apkUrl,
              message: 'A new update (v$tagName) is required to use InfoApp.',
            );
          }
        }
      } catch (_) {}

      return VersionCheckResult(
        isUpdateRequired: false,
        currentVersion: currentAppVersion,
        latestVersion: currentAppVersion,
        updateUrl: defaultDownloadUrl,
        message: 'App is up to date.',
      );
    } catch (e) {
      if (kDebugMode) print('Version check error: $e');
      return VersionCheckResult(
        isUpdateRequired: false,
        currentVersion: currentAppVersion,
        latestVersion: currentAppVersion,
        updateUrl: defaultDownloadUrl,
        message: 'Network offline.',
      );
    }
  }

  static bool _isVersionLower(String current, String required) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final rParts = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final r = i < rParts.length ? rParts[i] : 0;
        if (c < r) return true;
        if (c > r) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
