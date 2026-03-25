import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const HadirInApp());
}

class HadirInApp extends StatelessWidget {
  const HadirInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hadir-In',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // App selalu dimulai dari LoginScreen
      home: const LoginScreen(destination: LoginDestination.landing),
    );
  }
}