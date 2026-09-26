import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/update_required_screen.dart';
import 'services/version_check_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase App
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const InfoApp());
}

class InfoApp extends StatefulWidget {
  const InfoApp({super.key});

  @override
  State<InfoApp> createState() => _InfoAppState();
}

class _InfoAppState extends State<InfoApp> {
  bool _isCheckingVersion = true;
  VersionCheckResult? _versionResult;

  @override
  void initState() {
    super.initState();
    _checkAppVersion();
  }

  Future<void> _checkAppVersion() async {
    final result = await VersionCheckService.checkVersionStatus();
    if (mounted) {
      setState(() {
        _versionResult = result;
        _isCheckingVersion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'NumInfo Intelligence',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: _isCheckingVersion
                ? Scaffold(
                    backgroundColor: AppTheme.darkBackground,
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SpinKitCubeGrid(color: AppTheme.primaryCyan, size: 40),
                          SizedBox(height: 20),
                          Text(
                            'Verifying App Status...',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : (_versionResult != null && _versionResult!.isUpdateRequired)
                    ? UpdateRequiredScreen(
                        latestVersion: _versionResult!.latestVersion,
                        updateUrl: _versionResult!.updateUrl,
                        message: _versionResult!.message,
                      )
                    : (provider.user == null
                        ? const AuthScreen()
                        : const HomeScreen()),
          );
        },
      ),
    );
  }
}
