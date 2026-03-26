import 'package:flutter/material.dart';

import 'theme.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const LaunchpadApp());
}

class LaunchpadApp extends StatelessWidget {
  const LaunchpadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Launchpad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const DashboardScreen(),
    );
  }
}
