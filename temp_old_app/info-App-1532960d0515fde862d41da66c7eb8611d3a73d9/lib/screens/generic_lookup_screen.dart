import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'raw_result_screen.dart';
import 'recharge_screen.dart';

class GenericLookupScreen extends StatefulWidget {
  final String title;
  final String queryType;
  final String hintText;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLength;

  const GenericLookupScreen({
    super.key,
    required this.title,
    required this.queryType,
    required this.hintText,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLength = 16,
  });

  @override
  State<GenericLookupScreen> createState() => _GenericLookupScreenState();
}

class _GenericLookupScreenState extends State<GenericLookupScreen> {
  final _inputController = TextEditingController();

  void _openRechargePortal() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RechargeScreen()),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _handleSearch() async {
    final query = _inputController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid input.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final provider = Provider.of<AppProvider>(context, listen: false);

    final result = await provider.searchRaw(
      queryType: widget.queryType,
      queryValue: query,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RawResultScreen(
            title: '\${widget.queryType} Result',
            data: result,
          ),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppTheme.dangerRed,
          action: provider.errorMessage!.contains('Credits')
              ? SnackBarAction(
                  label: 'RECHARGE',
                  textColor: AppTheme.primaryCyan,
                  onPressed: _openRechargePortal,
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Details Below',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cost: 1 Credit per successful lookup',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _inputController,
              keyboardType: widget.keyboardType,
              maxLength: widget.maxLength,
              style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: Icon(widget.icon, color: AppTheme.primaryCyan),
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                  onPressed: () => _inputController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : _handleSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                ),
                child: provider.isLoading
                    ? const SpinKitThreeBounce(color: Colors.black, size: 24)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.search_rounded, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            'LOOKUP INFO',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
