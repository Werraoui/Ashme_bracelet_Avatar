import 'package:flutter/material.dart';

import '../navigation/root_scaffold.dart';
import 'theme.dart';

class AshtmeApp extends StatelessWidget {
  const AshtmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ashtme',
      debugShowCheckedModeBanner: false,
      theme: AshtmeTheme.dark(),
      home: const RootScaffold(),
    );
  }
}

