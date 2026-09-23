import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class RawResultScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const RawResultScreen({
    super.key,
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    // Convert JSON Map to formatted String
    final String prettyJson = const JsonEncoder.withIndent('  ').convert(data);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Result',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  backgroundColor: AppTheme.primaryCyan,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: SelectableText(
            prettyJson,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              color: AppTheme.accentNeon,
            ),
          ),
        ),
      ),
    );
  }
}
