import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  Api.token = prefs.getString('token') ?? '';
  Api.baseUrl = prefs.getString('baseUrl') ?? 'http://81.70.191.44:8001';
  runApp(const MiaoWenApp());
}

class MiaoWenApp extends StatelessWidget {
  const MiaoWenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '妙文',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF20a53a)),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: (Api.token != null && Api.token!.isNotEmpty)
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
