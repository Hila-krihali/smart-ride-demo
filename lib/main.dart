import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth/login_screen.dart';
import 'utils/app_colors.dart';
import 'services/api_service.dart';

void main() {
  runApp(const SmartRideApp());
}

class SmartRideApp extends StatelessWidget {
  const SmartRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final heeboTextTheme = GoogleFonts.heeboTextTheme();

    return MaterialApp(
      title: 'Smart Ride',
      debugShowCheckedModeBanner: false,
      locale: const Locale('he'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        textTheme: heeboTextTheme,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          error: AppColors.error,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.outlineVariant, width: 1),
          ),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          titleTextStyle: GoogleFonts.heebo(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
          shape: const Border(
            bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(0, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.heebo(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(0, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(color: AppColors.primary, width: 2),
            textStyle: GoogleFonts.heebo(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
          labelStyle: GoogleFonts.heebo(color: AppColors.onSurfaceVariant),
        ),
      ),
      home: const BackendConnectionGate(),
    );
  }
}

class BackendConnectionGate extends StatefulWidget {
  const BackendConnectionGate({super.key});

  @override
  State<BackendConnectionGate> createState() => _BackendConnectionGateState();
}

class _BackendConnectionGateState extends State<BackendConnectionGate> {
  bool isLoading = true;
  bool isConnected = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    checkBackendConnection();
  }

  Future<void> checkBackendConnection() async {
    try {
      await ApiService.healthCheck();

      if (!mounted) return;

      setState(() {
        isConnected = true;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isConnected = false;
        isLoading = false;
        errorMessage = 'לא ניתן להתחבר לשרת. ודאי שה־Backend פועל.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('שגיאת חיבור'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      isConnected = false;
                      errorMessage = '';
                    });

                    checkBackendConnection();
                  },
                  child: const Text('נסה שוב'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const LoginScreen();
  }
}