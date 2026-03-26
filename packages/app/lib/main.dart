import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'theme.dart';

void main() {
  runApp(const ProjectStatusApp());
}

class ProjectStatusApp extends StatelessWidget {
  const ProjectStatusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Status',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const DashboardScreen(),
    );
  }
}
