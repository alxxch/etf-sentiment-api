import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/etf_provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const EtfSentimentApp());
}

class EtfSentimentApp extends StatelessWidget {
  final EtfProvider? etfProvider;
  final AudioService? audioService;

  const EtfSentimentApp({
    super.key,
    this.etfProvider,
    this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final Widget app = MaterialApp(
      title: 'Smart Market Sentiment',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.cardSurface,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.cardSurface,
          primary: AppColors.bullish,
          error: AppColors.bearish,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );

    return MultiProvider(
      providers: [
        if (etfProvider != null)
          ChangeNotifierProvider<EtfProvider>.value(value: etfProvider!)
        else
          ChangeNotifierProvider<EtfProvider>(
            create: (_) => EtfProvider(),
          ),
        if (audioService != null)
          ChangeNotifierProvider<AudioService>.value(value: audioService!)
        else
          ChangeNotifierProvider<AudioService>(
            create: (_) => AudioService(),
          ),
      ],
      child: app,
    );
  }
}
