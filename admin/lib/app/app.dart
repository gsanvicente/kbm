import 'package:flutter/material.dart';

class KbmAdminApp extends StatelessWidget {
  const KbmAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBM Admin',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('KBM Admin — scaffolding')),
      ),
    );
  }
}
