import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/number_lookup_service.dart';
import '../services/payflux_service.dart';
import '../services/raw_api_service.dart';

class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  UserProfile? _profile;
  PricingSettings _pricingSettings = const PricingSettings();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserProfile>? _profileSubscription;
  StreamSubscription<PricingSettings>? _pricingSubscription;

  bool _isLoading = false;
  String? _errorMessage;
  NumberInfoResult? _lastSearchResult;

  User? get user => _user;
  UserProfile? get profile => _profile;
  PricingSettings get pricingSettings => _pricingSettings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NumberInfoResult? get lastSearchResult => _lastSearchResult;
  int get credits => _profile?.credits ?? 0;

  /// Effective price per credit (per-user custom rate if set by admin, otherwise global admin rate)
  double get effectivePricePerCredit => _profile?.customPricePerCredit ?? _pricingSettings.pricePerCredit;

  /// Whether current user has a specialized custom VIP price rate
  bool get hasCustomRate => _profile?.customPricePerCredit != null;

  /// Dynamic credit packages calculated using real-time admin pricing
  List<Map<String, dynamic>> get creditPacks {
    final rate = effectivePricePerCredit;
    final custom = hasCustomRate;

    final defaultPacks = [
      {'id': 'pack_1', 'credits': 1, 'price': (rate * 1).round(), 'title': 'Starter Pack', 'tag': '', 'desc': '1 Full Number Search'},
      {'id': 'pack_3', 'credits': 3, 'price': (rate * 3).round(), 'title': 'Value Pack', 'tag': 'Popular', 'desc': '3 Full Number Searches'},
      {'id': 'pack_5', 'credits': 5, 'price': (rate * 5).round(), 'title': 'Pro Pack', 'tag': 'Best Value', 'desc': '5 Full Number Searches'},
      {'id': 'pack_10', 'credits': 10, 'price': (rate * 10).round(), 'title': 'Ultra Pack', 'tag': '20% Extra', 'desc': '10 Full Number Searches'},
    ];

    if (_pricingSettings.customPacks != null && _pricingSettings.customPacks!.isNotEmpty) {
      return _pricingSettings.customPacks!.map((p) {
        final credits = (p['credits'] as num?)?.toInt() ?? 1;
        final basePrice = (p['price'] as num?)?.toInt() ?? (credits * 40);
        final dynamicPrice = custom ? (credits * rate).round() : basePrice;

        return {
          'id': p['id']?.toString() ?? 'pack_$credits',
          'credits': credits,
          'price': dynamicPrice,
          'title': p['title']?.toString() ?? '$credits Credits Pack',
          'tag': p['tag']?.toString() ?? '',
          'desc': p['desc']?.toString() ?? '$credits Full Number Searches',
        };
      }).toList();
    }

    return defaultPacks;
  }

  AppProvider() {
    _initAuthListener();
    _initPricingListener();
  }

  void _initPricingListener() {
    _pricingSubscription = _firestoreService.streamPricingSettings().listen((settings) {
      _pricingSettings = settings;
      notifyListeners();
    });
  }

  void _initAuthListener() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      _user = user;
      _profileSubscription?.cancel();

      if (user != null) {
        // Ensure user profile document exists
        _firestoreService.createUserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'InfoApp User',
        );

        // Subscribe to real-time profile updates
        _profileSubscription =
            _firestoreService.streamUserProfile(user.uid).listen((profileData) {
          _profile = profileData;
          notifyListeners();
        });
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --- AUTH ACTIONS ---

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cred = await _authService.signInWithGoogle();
      _isLoading = false;
      if (cred != null) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Google Sign-In cancelled.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = _cleanAuthError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
  }

  // --- NUMBER LOOKUP ACTION ---

  Future<NumberInfoResult?> searchPhoneNumber(String phoneNumber) async {
    if (_user == null) {
      _errorMessage = 'Please sign in to search numbers.';
      notifyListeners();
      return null;
    }

    if (credits < 1) {
      _errorMessage =
          'Insufficient Credits (Cost: 1 Credit). Please purchase credits to search.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch info using Multi-API Fallback Engine (Next.js server handles credit check, deduction & search logging)
      final result = await NumberLookupService.lookupNumber(
        phoneNumber,
        uid: _user!.uid,
      );

      _lastSearchResult = result;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  // --- RAW API LOOKUP ACTION ---

  Future<Map<String, dynamic>?> searchRaw({
    required String queryType,
    required String queryValue,
  }) async {
    if (_user == null) {
      _errorMessage = 'Please sign in to search.';
      notifyListeners();
      return null;
    }

    if (credits < 1) {
      _errorMessage =
          'Insufficient Credits (Cost: 1 Credit). Please purchase credits to search.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Map<String, dynamic> result;
      if (queryType == 'PAN') {
        result = await RawApiService.lookupPan(queryValue);
      } else if (queryType == 'Aadhaar') {
        result = await RawApiService.lookupAadhaar(queryValue);
      } else if (queryType == 'RC') {
        result = await RawApiService.lookupRc(queryValue);
      } else {
        throw Exception('Unknown query type: $queryType');
      }

      await _firestoreService.deductCreditAndLogRawSearch(
        uid: _user!.uid,
        queryType: queryType,
        queryValue: queryValue,
        result: result,
      );

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  // --- PAYFLUX RECHARGE ACTION ---

  Future<PayfluxOrderResponse> initiatePayfluxRecharge({
    required double amount,
    required int creditsToAdd,
  }) async {
    if (_user == null) {
      return PayfluxOrderResponse(
        success: false,
        message: 'Please sign in to purchase credits.',
      );
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final orderRes = await PayfluxService.createOrder(
      amount: amount,
      customerEmail: _user!.email ?? 'user@infoapp.com',
      customerName: _user!.displayName ?? 'Subscriber',
    );

    _isLoading = false;
    notifyListeners();
    return orderRes;
  }

  /// Fulfill Order directly upon Payflux SDK verified success
  Future<bool> fulfillSuccessfulOrder({
    required String orderId,
    required double amount,
    required int creditsToAdd,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.addCreditsAndLogOrder(
        uid: _user!.uid,
        orderId: orderId,
        amount: amount,
        creditsToAdd: creditsToAdd,
        status: 'SUCCESS',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update balance: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Verify Payment & Credit User Balance (fallback polling)
  Future<bool> verifyAndFulfillOrder({
    required String orderId,
    required double amount,
    required int creditsToAdd,
  }) async {
    return await fulfillSuccessfulOrder(
      orderId: orderId,
      amount: amount,
      creditsToAdd: creditsToAdd,
    );
  }

  String _cleanAuthError(String error) {
    if (error.contains('user-not-found')) return 'No user found with this email.';
    if (error.contains('wrong-password')) return 'Incorrect password.';
    if (error.contains('email-already-in-use')) return 'Email already registered.';
    if (error.contains('weak-password')) return 'Password should be at least 6 characters.';
    if (error.contains('invalid-email')) return 'Invalid email address.';
    return error.replaceAll('FirebaseAuthException: ', '');
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _pricingSubscription?.cancel();
    super.dispose();
  }
}
