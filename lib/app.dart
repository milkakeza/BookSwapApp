import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/browse_screen.dart';
import 'screens/email_verification_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
      ],
      child: Consumer<AuthProvider>(builder: (context, auth, _) {
        Widget home;
        
        if (auth.isSignedIn) {
          home = const BrowseScreen();
        } else if (auth.isSignedInButUnverified) {
          home = EmailVerificationScreen(email: auth.user?.email ?? '');
        } else {
          home = const AuthScreen();
        }

        return MaterialApp(
          title: 'BookSwap',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F6F2),
            iconTheme: const IconThemeData(
              color: Colors.black87,
              size: 24,
            ),
            appBarTheme: const AppBarTheme(
              iconTheme: IconThemeData(
                color: Colors.black87,
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
          home: home,
          routes: {
            '/home': (ctx) => const BrowseScreen(),
            '/auth': (ctx) => const AuthScreen(),
            '/verify': (ctx) => EmailVerificationScreen(
              email: auth.user?.email ?? '',
            ),
          },
        );
      }),
    );
  }
}
