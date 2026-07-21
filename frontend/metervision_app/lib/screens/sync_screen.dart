import 'package:flutter/material.dart';
import '../core/theme.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Status')),
      // TODO: watch syncQueueProvider (Hive box) once SyncService exists
      body: const Center(
        child: Text('No pending uploads', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
