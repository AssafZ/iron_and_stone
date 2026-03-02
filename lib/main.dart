import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iron_and_stone/data/drift/app_database.dart';
import 'package:iron_and_stone/data/drift/match_dao.dart';
import 'package:iron_and_stone/state/match_notifier.dart';
import 'package:iron_and_stone/ui/theme/app_theme.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        matchDaoProvider.overrideWithValue(MatchDao(AppDatabase())),
      ],
      child: const IronAndStoneApp(),
    ),
  );
}

class IronAndStoneApp extends StatelessWidget {
  const IronAndStoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iron and Stone',
      theme: AppTheme.themeData,
      home: const Scaffold(
        body: Center(
          child: Text(
            'Iron and Stone',
            style: TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}
