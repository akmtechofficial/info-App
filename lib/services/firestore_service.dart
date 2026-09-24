import 'package:cloud_firestore/cloud_firestore.dart';
import 'number_lookup_service.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final int credits;
  final double? customPricePerCredit;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.credits,
    this.customPricePerCredit,
    required this.createdAt,
  });

  factory UserProfile.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'User',
      credits: (data['credits'] ?? 0) as int,
      customPricePerCredit: data['customPricePerCredit'] != null
          ? (data['customPricePerCredit'] as num).toDouble()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class PricingSettings {
  final double pricePerCredit;
  final List<Map<String, dynamic>>? customPacks;

  const PricingSettings({
    this.pricePerCredit = 40.0,
    this.customPacks,
  });

  factory PricingSettings.fromSnapshot(DocumentSnapshot doc) {
    if (!doc.exists) return const PricingSettings();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rate = (data['pricePerCredit'] as num?)?.toDouble() ?? 40.0;
    final rawPacks = data['packs'] as List<dynamic>?;
    final List<Map<String, dynamic>>? packs = rawPacks?.map((p) => Map<String, dynamic>.from(p as Map)).toList();

    return PricingSettings(
      pricePerCredit: rate,
      customPacks: packs,
    );
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream pricing settings (global admin rate & packs)
  Stream<PricingSettings> streamPricingSettings() {
    return _db.collection('settings').doc('pricing').snapshots().map((snapshot) {
      return PricingSettings.fromSnapshot(snapshot);
    });
  }

  /// Stream user profile for live credit & custom rate updates
  Stream<UserProfile> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return UserProfile(
          uid: uid,
          email: '',
          displayName: 'User',
          credits: 0,
          customPricePerCredit: null,
          createdAt: DateTime.now(),
        );
      }
      return UserProfile.fromSnapshot(snapshot);
    });
  }

  /// Ensure User Document Exists in Firestore
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    int initialCredits = 1, // 1 Free initial credit for testing
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'credits': initialCredits,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Deduct 1 credit atomically and save search record
  Future<void> deductCreditAndLogSearch({
    required String uid,
    required NumberInfoResult result,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final lookupRef = _db.collection('lookups').doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception('User profile does not exist.');
      }

      final currentCredits = (snapshot.data()?['credits'] ?? 0) as int;
      if (currentCredits < 1) {
        throw Exception('Insufficient credits. Please recharge your account.');
      }

      // Deduct credit
      transaction.update(userRef, {
        'credits': currentCredits - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save search log
      transaction.set(lookupRef, {
        'userId': uid,
        'phoneNumber': result.phoneNumber,
        'result': result.toMap(),
        'creditsSpent': 1,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Deduct 1 credit atomically and save raw search record
  Future<void> deductCreditAndLogRawSearch({
    required String uid,
    required String queryType, // e.g., 'PAN', 'Aadhaar', 'RC', 'UPI'
    required String queryValue,
    required Map<String, dynamic> result,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final lookupRef = _db.collection('lookups').doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception('User profile does not exist.');
      }

      final currentCredits = (snapshot.data()?['credits'] ?? 0) as int;
      if (currentCredits < 1) {
        throw Exception('Insufficient credits. Please recharge your account.');
      }

      // Deduct credit
      transaction.update(userRef, {
        'credits': currentCredits - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save raw search log
      transaction.set(lookupRef, {
        'userId': uid,
        'queryType': queryType,
        'queryValue': queryValue,
        'result': result,
        'creditsSpent': 1,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Add credits atomically and log Payflux order (Idempotent - protects against duplicate crediting)
  Future<bool> addCreditsAndLogOrder({
    required String uid,
    required String orderId,
    required double amount,
    required int creditsToAdd,
    required String status,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final orderRef = _db.collection('orders').doc(orderId);

    return await _db.runTransaction<bool>((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (orderSnap.exists) {
        // Order has already been credited. Prevent duplicate crediting!
        return true;
      }

      final snapshot = await transaction.get(userRef);

      final currentCredits = snapshot.exists ? (snapshot.data()?['credits'] ?? 0) as int : 0;

      // Update credits
      if (snapshot.exists) {
        transaction.update(userRef, {
          'credits': currentCredits + creditsToAdd,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Record order
      transaction.set(orderRef, {
        'userId': uid,
        'orderId': orderId,
        'amount': amount,
        'creditsAdded': creditsToAdd,
        'status': status,
        'paymentGateway': 'Payflux',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  /// Stream user lookup history (sorted in Dart to avoid needing composite index)
  Stream<List<Map<String, dynamic>>> streamLookupHistory(String uid) {
    return _db
        .collection('lookups')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        if (tA is Timestamp && tB is Timestamp) {
          return tB.compareTo(tA);
        }
        return 0;
      });
      return list;
    });
  }

  /// Stream user payment history (sorted in Dart to avoid needing composite index)
  Stream<List<Map<String, dynamic>>> streamOrderHistory(String uid) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        if (tA is Timestamp && tB is Timestamp) {
          return tB.compareTo(tA);
        }
        return 0;
      });
      return list;
    });
  }
}
