import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Auth Screens
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';

// User Screens
import 'features/user/user_dashboard_screen.dart';
import 'features/user/studio_list_screen.dart';

// Admin Screens
import 'features/admin/AdminDashboardScreen.dart';
import 'features/admin/add_studio_screen.dart';
import 'features/admin/admin_studio_list_screen.dart';
import 'features/admin/AdminViewBookingsScreen.dart';
import 'features/admin/admin_user_details_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const HarmonyHubApp());
}

class HarmonyHubApp extends StatelessWidget {
  const HarmonyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HarmonyHub',

      // 🌿 GLOBAL THEME (FORCES BLUE EVERYWHERE)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),

        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),

        // ✅ ALL ELEVATED BUTTONS
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),

        // ✅ ALL TEXT BUTTONS (Login links, Register, Resend email)
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
        ),

        // ✅ INPUT FIELD CURSOR + FOCUS COLOR
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
          labelStyle: TextStyle(color: Colors.blue),
        ),

        // ✅ ICON COLORS
        iconTheme: const IconThemeData(color: Colors.blue),
      ),

      // 👇 Entry point
      home: const SplashScreen(),

      routes: {
        // AUTH
        '/login': (context) => const LoginScreen(),

        // USER
        '/user': (context) => const UserDashboardScreen(),
        '/studios': (context) => const StudioListScreen(),

        // ADMIN
        '/admin': (context) => const AdminDashboardScreen(),
        '/admin/add-studio': (context) => const AddStudioScreen(),
        '/admin/studios': (context) => const AdminStudioListScreen(),
        '/admin/bookings': (context) => const AdminViewBookingsScreen(),

        // USER DETAILS
        '/admin/user-details': (context) {
          final userId =
              ModalRoute.of(context)!.settings.arguments as String;
          return AdminUserDetailsScreen(userId: userId);
        },
      },
    );
  }
}
