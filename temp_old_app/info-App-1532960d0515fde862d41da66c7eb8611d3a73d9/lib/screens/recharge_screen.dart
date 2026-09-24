import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/payflux_service.dart';
import '../payflux/payflux.dart';
import '../theme/app_theme.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  int _selectedCredits = 5;
  bool _isPaying = false;

  Map<String, dynamic> _getSelectedPack(List<Map<String, dynamic>> packs) {
    for (final p in packs) {
      if (p['credits'] == _selectedCredits) {
        return p;
      }
    }
    if (packs.isNotEmpty) {
      return packs.first;
    }
    return <String, dynamic>{
      'id': 'pack_5',
      'credits': 5,
      'price': 200,
      'title': 'Pro Pack',
      'tag': 'Best Value',
      'desc': '5 Full Number Searches',
    };
  }

  Future<void> _handleDirectRecharge(Map<String, dynamic> pack) async {
    if (_isPaying) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final double amount = (pack['price'] as num).toDouble();
    final int credits = pack['credits'] as int;

    setState(() {
      _isPaying = true;
    });

    try {
      // 1. Create order on Payflux
      final orderRes = await provider.initiatePayfluxRecharge(
        amount: amount,
        creditsToAdd: credits,
      );

      if (!orderRes.success || orderRes.orderId == null || orderRes.checkoutToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(orderRes.message ?? 'Failed to initialize payment order.'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
        setState(() {
          _isPaying = false;
        });
        return;
      }

      // 2. Launch Native Payflux In-App Checkout (100% Pure Native Flutter UPI Sheet)
      final PaymentResult result = await PayfluxService.startPayment(
        context: context,
        orderId: orderRes.orderId!,
        checkoutToken: orderRes.checkoutToken!,
        amount: orderRes.amount ?? amount,
        merchantName: orderRes.merchantName,
        upiId: orderRes.upiId,
        mode: orderRes.mode,
      );

      if (!mounted) return;

      // 3. Handle Result
      if (result.status == PaymentStatus.success) {
        // Fulfill & credit user balance
        await provider.fulfillSuccessfulOrder(
          orderId: orderRes.orderId!,
          amount: amount,
          creditsToAdd: credits,
        );

        if (mounted) {
          _showSuccessDialog(credits, result.transactionId ?? 'UTR_CONFIRMED');
        }
      } else if (result.status == PaymentStatus.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Payment failed or timed out.'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  void _showSuccessDialog(int creditsAdded, String txnId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.primaryCyan, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha:0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 56,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Recharge Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+$creditsAdded Credits added to your balance.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.primaryCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Txn Ref: $txnId',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CONTINUE SEARCHING',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final packs = provider.creditPacks;
    final selectedPack = _getSelectedPack(packs);
    final rate = provider.effectivePricePerCredit;
    final isCustomRate = provider.hasCustomRate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recharge Credits'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Credit Rate Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCustomRate
                      ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
                      : [AppTheme.cardBg, const Color(0xFF1B283D)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCustomRate ? const Color(0xFFA855F7) : AppTheme.primaryCyan.withValues(alpha:0.3),
                  width: isCustomRate ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCustomRate
                              ? const Color(0xFFA855F7).withValues(alpha:0.2)
                              : AppTheme.primaryCyan.withValues(alpha:0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCustomRate ? Icons.auto_awesome_rounded : Icons.stars_rounded,
                          color: isCustomRate ? const Color(0xFFC084FC) : AppTheme.primaryCyan,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance: ${provider.credits} Credits',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your Rate: ₹${rate.toInt()} per 1 Credit (1 Search)',
                              style: TextStyle(
                                fontSize: 13,
                                color: isCustomRate ? const Color(0xFFE9D5FF) : AppTheme.accentNeon,
                                fontWeight: isCustomRate ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isCustomRate) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA855F7).withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: Color(0xFFC084FC), size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Special Custom Rate applied to your account!',
                              style: TextStyle(fontSize: 11, color: Color(0xFFE9D5FF), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Credit Package',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 14),

            // Dynamic Package Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.25,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: packs.length,
              itemBuilder: (context, index) {
                final item = packs[index];
                final isSelected = _selectedCredits == item['credits'];

                return GestureDetector(
                  onTap: _isPaying
                      ? null
                      : () {
                          setState(() {
                            _selectedCredits = item['credits'] as int;
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryCyan.withValues(alpha:0.12)
                          : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryCyan
                            : AppTheme.cardBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item['tag'] != null && item['tag'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item['tag'].toString(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['credits']} Credits',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${item['price']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // In-App Direct Payflux CTA with Dynamic Price
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isPaying ? null : () => _handleDirectRecharge(selectedPack),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isPaying
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
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
                            'PROCESSING PAYMENT...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.black, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'PAY ₹${selectedPack['price']} VIA UPI / PAYFLUX',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Instant In-App Payment • Supports PhonePe, GPay, Paytm & UPI QR',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
