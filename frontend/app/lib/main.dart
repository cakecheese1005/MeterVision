import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/local_store.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/sync_provider.dart';

void main() async {
  // Required before any plugin (Hive / secure storage) is touched.
  WidgetsFlutterBinding.ensureInitialized();

  // Opens the offline boxes (pending_readings, consumers_cache, auth_box)
  // so the app works without a network on first frame.
  await LocalStore.init();

  // ProviderScope must wrap the whole app — this is what makes every
  // ref.watch()/ref.read() call in the widget tree work.
  runApp(const ProviderScope(child: MeterVisionApp()));
}

class MeterVisionApp extends ConsumerWidget {
  const MeterVisionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MeterVision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SyncBootstrap(child: child),
    );
  }
}

/// Keeps the sync subsystem alive for the lifetime of the app.
///
/// ---------------------------------------------------------------------
/// WHY THIS WIDGET EXISTS
/// ---------------------------------------------------------------------
///
/// Riverpod providers are lazy: a provider is only constructed once something
/// watches it, and is torn down when nothing does. `syncProvider` was fully
/// implemented — connectivity auto-drain, queue watcher, re-entrancy guard —
/// and no widget anywhere in the tree ever watched it.
///
/// So `SyncNotifier` was never constructed. The `ref.listen(connectivityProvider)`
/// reconnect trigger inside it never registered, the Hive queue watcher never
/// started, and there was no path to `syncNow()` at all. Readings were captured
/// and queued correctly and then simply never left the device.
///
/// Watching it here, above the router, means it comes up with the app and stays
/// up regardless of which screen is on top.
///
/// It also runs the launch-time sync: as soon as an officer is authenticated,
/// anything left in the queue from a previous session is pushed. The other two
/// triggers are the connectivity listener inside `syncProvider` and the manual
/// button on the sync screen.
class SyncBootstrap extends ConsumerStatefulWidget {
  final Widget? child;

  const SyncBootstrap({super.key, required this.child});

  @override
  ConsumerState<SyncBootstrap> createState() => _SyncBootstrapState();
}

class _SyncBootstrapState extends ConsumerState<SyncBootstrap> {
  bool _launchSyncDone = false;

  @override
  Widget build(BuildContext context) {
    // Keeps SyncNotifier (and through it, the connectivity listener and the
    // Hive queue watcher) alive.
    ref.watch(syncProvider);

    // Sync-on-launch, once, after the officer is authenticated. Waiting for
    // authentication matters: draining the queue without a valid token would
    // just burn every draft's retry budget against a wall of 401s.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated || _launchSyncDone) return;

      _launchSyncDone = true;

      // Deferred so the first frame renders before any network work starts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(syncProvider.notifier).syncNow();
      });
    });

    return widget.child ?? const SizedBox.shrink();
  }
}
