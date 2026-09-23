import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String latestVersion;
  final String updateUrl;
  final String message;

  const UpdateRequiredScreen({
    super.key,
    required this.latestVersion,
    required this.updateUrl,
    required this.message,
  });

  void _launchUpdateUrl() async {
    final uri = Uri.parse(updateUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent user from dismissing update screen via back button
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B0F19),
                Color(0xFF131C2E),
                Color(0xFF0B0F19),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Warning Icon Badge
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.dangerRed.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: AppTheme.dangerRed,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Update Title
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Version Tag Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentNeon.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentNeon),
                      ),
                      child: Text(
                        'New Version: v$latestVersion Available',
                        style: const TextStyle(
                          color: AppTheme.accentNeon,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Detail Message Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Text(
                        message.isNotEmpty
                            ? message
                            : 'This version of InfoApp is no longer supported or the release was updated on GitHub. Please download the latest update to continue.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Mandatory Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _launchUpdateUrl,
                        icon: const Icon(Icons.download_rounded, size: 22),
                        label: const Text(
                          'DOWNLOAD LATEST UPDATE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
