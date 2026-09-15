import 'package:flutter/material.dart';

class KbmCardholderApp extends StatelessWidget {
  const KbmCardholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBM',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('KBM Cardholder — scaffolding')),
      ),
    );
  }
}
