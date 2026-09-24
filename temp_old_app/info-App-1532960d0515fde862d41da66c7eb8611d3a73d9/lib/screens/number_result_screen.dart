import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/number_lookup_service.dart';
import '../theme/app_theme.dart';

class NumberResultScreen extends StatelessWidget {
  final NumberInfoResult result;

  const NumberResultScreen({super.key, required this.result});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppTheme.accentNeon,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Intelligence Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Raw Data',
            onPressed: () => _copyToClipboard(
              context,
              result.formattedRawJson,
              'Raw Metadata',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.cardBg, Color(0xFF1E2B45)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryCyan.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryCyan),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            size: 16, color: AppTheme.primaryCyan),
                        const SizedBox(width: 6),
                        Text(
                          result.apiSource,
                          style: const TextStyle(
                            color: AppTheme.primaryCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '+91 ${result.phoneNumber}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentNeon,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Prominent Copy Button Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Raw Metadata JSON',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(
                    context,
                    result.formattedRawJson,
                    'Raw Metadata',
                  ),
                  icon: const Icon(Icons.copy_all_rounded,
                      size: 18, color: Colors.black),
                  label: const Text('COPY RAW DATA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentNeon,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Raw JSON Viewer Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D131F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accentNeon.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentNeon.withOpacity(0.08),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.data_object_rounded,
                              color: AppTheme.accentNeon, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'JSON Payload Response',
                            style: TextStyle(
                              color: AppTheme.accentNeon,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy_rounded,
                            color: AppTheme.primaryCyan, size: 20),
                        tooltip: 'Copy JSON text',
                        onPressed: () => _copyToClipboard(
                          context,
                          result.formattedRawJson,
                          'JSON payload',
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 16),
                  SelectableText(
                    result.formattedRawJson,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Additional Extracted Fields Summary
            const Text(
              'Parsed Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 12),

            _buildSummaryTile(
              icon: Icons.cell_tower_rounded,
              label: 'Carrier / Operator',
              value: result.carrier,
              iconColor: AppTheme.primaryCyan,
            ),
            _buildSummaryTile(
              icon: Icons.map_rounded,
              label: 'Circle / Location',
              value: result.circle,
              iconColor: Colors.amberAccent,
            ),
            _buildSummaryTile(
              icon: Icons.phone_android_rounded,
              label: 'Line Type',
              value: result.lineType,
              iconColor: Colors.purpleAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
