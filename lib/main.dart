import 'package:flutter/material.dart';

import 'src/screens/dashboard_screen.dart';

void main() {
  runApp(const FoodRushApp());
}

class FoodRushApp extends StatelessWidget {
  const FoodRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Rush - Restaurant Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
