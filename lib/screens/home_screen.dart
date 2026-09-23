import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'number_result_screen.dart';
import 'recharge_screen.dart';
import 'generic_lookup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _phoneController = TextEditingController();

  void _openRechargePortal() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RechargeScreen()),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSearch() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty || phone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final provider = Provider.of<AppProvider>(context, listen: false);

    final result = await provider.searchPhoneNumber(phone);

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NumberResultScreen(result: result),
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
        title: const Text('NumInfo Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => provider.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting & Credit Balance Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF131C2E), Color(0xFF1E2D4A)],
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
                    color: AppTheme.primaryCyan.withOpacity(0.12),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: AppTheme.textMuted.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.profile?.displayName ?? 'Subscriber',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCyan.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: AppTheme.primaryCyan, size: 26),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${provider.credits} Credits',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentNeon,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _openRechargePortal,
                        icon: const Icon(Icons.add_shopping_cart_rounded,
                            size: 18, color: Colors.black),
                        label: const Text('ADD CREDITS'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Number Search Input Section
            const Text(
              'Search Mobile Number',
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
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                prefixIcon: const Icon(Icons.phone_android_rounded,
                    color: AppTheme.primaryCyan),
                counterText: '',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                  onPressed: () => _phoneController.clear(),
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
                            'LOOKUP NUMBER DETAILS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // More Lookup Tools Section
            const Text(
              'More Lookup Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 2.5,
              children: [
                _buildToolButton(
                  context,
                  title: 'Aadhaar Info',
                  icon: Icons.fingerprint_rounded,
                  queryType: 'Aadhaar',
                  hintText: 'Enter 12-digit Aadhaar',
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                ),
                _buildToolButton(
                  context,
                  title: 'PAN Info',
                  icon: Icons.credit_card_rounded,
                  queryType: 'PAN',
                  hintText: 'Enter 10-char PAN',
                  keyboardType: TextInputType.text,
                  maxLength: 10,
                ),
                _buildToolButton(
                  context,
                  title: 'RC Info',
                  icon: Icons.directions_car_rounded,
                  queryType: 'RC',
                  hintText: 'Enter Vehicle Number',
                  keyboardType: TextInputType.text,
                  maxLength: 10,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Info Cards
            Row(
              children: [
                Expanded(
                  child: _buildFeatureCard(
                    icon: Icons.flash_on_rounded,
                    title: 'Multi-API Engine',
                    subtitle: 'Automatic fallback between servers',
                    iconColor: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFeatureCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Payflux UPI',
                    subtitle: 'Instant credit recharge via QR',
                    iconColor: AppTheme.primaryCyan,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String queryType,
    required String hintText,
    required TextInputType keyboardType,
    required int maxLength,
  }) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GenericLookupScreen(
              title: title,
              queryType: queryType,
              hintText: hintText,
              icon: icon,
              keyboardType: keyboardType,
              maxLength: maxLength,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.cardBg,
        foregroundColor: AppTheme.primaryCyan,
        side: const BorderSide(color: AppTheme.cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
