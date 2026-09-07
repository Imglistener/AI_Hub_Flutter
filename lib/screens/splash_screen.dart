import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'hub_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      OnboardingService.instance.hasSeenOnboarding(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    final hasSeenOnboarding = results[0] as bool;
    final isSignedIn = AuthService.instance.isSignedIn;

    if (!mounted) return;

    Widget destination;
    if (!hasSeenOnboarding) {
      destination = const OnboardingScreen();
    } else if (isSignedIn) {
      destination = const HubScreen();
    } else {
      destination = const AuthScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.hub_outlined, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nexus',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primaryVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}