import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/payflux_service.dart';
import '../theme/app_theme.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectToWebRecharge();
    });
  }

  Future<void> _redirectToWebRecharge() async {
    if (_isRedirecting) return;
    setState(() {
      _isRedirecting = true;
    });

    final provider = Provider.of<AppProvider>(context, listen: false);
    final user = provider.user;

    try {
      await PayfluxService.openWebRechargePortal(uid: user?.uid);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isRedirecting = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recharge Credits'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.language_rounded,
                color: AppTheme.primaryCyan,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Online Web Recharge Portal',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Current Balance: ${provider.credits} Credits\nAll credit purchases and UPI payment gateway checkouts take place securely on our Web Recharge Portal.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isRedirecting ? null : _redirectToWebRecharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isRedirecting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'OPENING WEB PORTAL...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_browser_rounded, color: Colors.black, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'OPEN WEB RECHARGE PORTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 15,
                            ),
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
