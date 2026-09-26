import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/number_lookup_service.dart';
import '../theme/app_theme.dart';
import 'number_result_screen.dart';
import 'raw_result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final uid = provider.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryCyan,
          labelColor: AppTheme.primaryCyan,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Searches'),
            Tab(text: 'Recharges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchHistoryList(uid),
          _buildRechargeHistoryList(uid),
        ],
      ),
    );
  }

  Widget _buildSearchHistoryList(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamLookupHistory(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryCyan));
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              'No previous searches found.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final String? queryType = log['queryType'];
            final resultMap = log['result'] as Map<String, dynamic>? ?? {};

            // If it's a new Raw Lookup (Aadhaar, PAN, RC)
            if (queryType != null) {
              final queryValue = log['queryValue'] ?? 'Unknown';
              return Card(
                color: AppTheme.cardBg,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.cardBorder),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E2D42),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.data_object_rounded,
                        color: AppTheme.primaryCyan),
                  ),
                  title: Text(
                    '$queryType: $queryValue',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Raw JSON Data',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppTheme.textMuted),
                  onTap: () {
                    // Navigate to RawResultScreen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RawResultScreen(
                          title: '$queryType Result',
                          data: resultMap,
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            // Otherwise, it's a legacy Number Lookup
            final result = NumberInfoResult.fromMap(resultMap);

            return Card(
              color: AppTheme.cardBg,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2D42),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.manage_search_rounded,
                      color: AppTheme.primaryCyan),
                ),
                title: Text(
                  '+91 ${result.phoneNumber}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${result.name} • ${result.carrier}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NumberResultScreen(result: result),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRechargeHistoryList(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamOrderHistory(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryCyan));
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No recharge records found.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final amount = order['amount'] ?? 0;
            final credits = order['creditsAdded'] ?? 0;

            return Card(
              color: AppTheme.cardBg,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2D42),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppTheme.accentNeon),
                ),
                title: Text(
                  'Added +$credits Credits',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Order ID: ${order['orderId'] ?? 'Payflux'}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                trailing: Text(
                  '₹$amount',
                  style: const TextStyle(
                    color: AppTheme.primaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
