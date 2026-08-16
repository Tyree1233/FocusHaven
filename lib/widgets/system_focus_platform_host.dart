import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_focus_snapshot.dart';
import '../providers/app_providers.dart';
import '../services/system_focus_platform_bridge.dart';

/// Activates the system-focus bridge only for an intentionally supported host.
///
/// Android is enabled now that its strict native snapshot store exists. Apple,
/// web, and desktop remain dormant until their own adapters are installed.
class SystemFocusPlatformHost extends ConsumerStatefulWidget {
  const SystemFocusPlatformHost({required this.child, this.enabled, super.key});

  final Widget child;
  final bool? enabled;

  @override
  ConsumerState<SystemFocusPlatformHost> createState() =>
      _SystemFocusPlatformHostState();
}

class _SystemFocusPlatformHostState
    extends ConsumerState<SystemFocusPlatformHost> {
  ProviderSubscription<SystemFocusSnapshot>? _snapshotSubscription;
  SystemFocusPlatformBridge? _bridge;

  bool get _isEnabled =>
      widget.enabled ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    if (!_isEnabled) return;
    unawaited(_activateAfterTimerRestoration());
  }

  Future<void> _activateAfterTimerRestoration() async {
    try {
      await ref.read(timerInitializationProvider);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final bridge = ref.read(systemFocusPlatformBridgeProvider);
    _bridge = bridge;
    _snapshotSubscription = ref.listenManual<SystemFocusSnapshot>(
      systemFocusSnapshotProvider,
      (_, snapshot) {
        if (bridge.isStarted) unawaited(bridge.publish(snapshot));
      },
    );
    await bridge.start();
  }

  @override
  void dispose() {
    _snapshotSubscription?.close();
    _bridge?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
