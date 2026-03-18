import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const HadirInApp());
}

class HadirInApp extends StatelessWidget {
  const HadirInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HadirIn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LandingScreen(),
    );
  }
}