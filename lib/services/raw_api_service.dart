import 'dart:convert';
import 'package:http/http.dart' as http;

class RawApiService {
  // TODO: Replace this placeholder with your live web-recharge Next.js domain (e.g., https://my-recharge.vercel.app)
  static const String _backendProxyBaseUrl = 'https://info-app-recharge-tawny.vercel.app';

  /// Fetch raw JSON data from our secure Next.js backend proxy
  static Future<Map<String, dynamic>> _fetchSecure(String type, String query) async {
    final url = '$_backendProxyBaseUrl/api/raw-lookup?type=$type&query=$query';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'x-api-key': 'INFO_APP_SECRET_2026',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          return {'response': decoded};
        }
      } else {
        throw Exception('Server error: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch data securely: $e');
    }
  }

  /// PAN Lookup
  static Future<Map<String, dynamic>> lookupPan(String pan) async {
    return _fetchSecure('PAN', pan);
  }

  /// Aadhaar Lookup
  static Future<Map<String, dynamic>> lookupAadhaar(String aadhaar) async {
    return _fetchSecure('Aadhaar', aadhaar);
  }

  /// RC Lookup
  static Future<Map<String, dynamic>> lookupRc(String vehicleNo) async {
    return _fetchSecure('RC', vehicleNo);
  }
}
