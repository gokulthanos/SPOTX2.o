import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'core/app_theme.dart';
import 'screens/auth/landing_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/register_page.dart';
import 'screens/auth/otp_page.dart';
import 'screens/auth/forgot_password_page.dart';
import 'screens/passenger/home_page.dart';
import 'screens/conductor/conductor_login_page.dart';
import 'screens/conductor/conductor_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await StorageService.init();
  runApp(const SpotXApp());
}

class SpotXApp extends StatelessWidget {
  const SpotXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final auth = AuthProvider();
        auth.loadFromStorage();
        return auth;
      },
      child: MaterialApp(
        title: 'SpotX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (_) => const LandingPage(),
          '/auth/login': (_) => const LoginPage(),
          '/auth/register': (_) => const RegisterPage(),
          '/auth/otp': (_) => const OtpPage(),
          '/auth/forgot-password': (_) => const ForgotPasswordPage(),
          '/passenger/home': (_) => const HomePage(),
          '/conductor/login': (_) => const ConductorLoginPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/conductor/dashboard') {
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => ConductorDashboard(conductorData: args),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}
