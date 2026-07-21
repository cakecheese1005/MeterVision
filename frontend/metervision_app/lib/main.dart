import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  // ProviderScope must wrap the whole app
  // this is what makes every ref.watch()/ref.read() call in the widget tree work.
  runApp(const ProviderScope(child: MeterVisionApp()));
}

class MeterVisionApp extends StatelessWidget {
  const MeterVisionApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeterVision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  } 
} 