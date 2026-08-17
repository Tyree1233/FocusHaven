import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/focus_shield_state.dart';
import '../providers/app_providers.dart';
import '../services/focus_shield_platform_bridge.dart';

/// Activates Focus Shield only for its separately supported native host.
///
/// iOS is enabled because it has a Family Controls adapter. Android, web, and
/// desktop remain dormant and honestly unsupported until their own reviewed
/// transports exist.
class FocusShieldPlatformHost extends ConsumerStatefulWidget {
  const FocusShieldPlatformHost({required this.child, this.enabled, super.key});

  final Widget child;
  final bool? enabled;

  @override
  ConsumerState<FocusShieldPlatformHost> createState() =>
      _FocusShieldPlatformHostState();
}

class _FocusShieldPlatformHostState
    extends ConsumerState<FocusShieldPlatformHost> {
  ProviderSubscription<FocusShieldState>? _stateSubscription;
  FocusShieldPlatformController? _controller;

  bool get _isEnabled =>
      widget.enabled ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

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
    final controller = ref.read(focusShieldPlatformControllerProvider);
    _controller = controller;
    if (!await controller.start() || !mounted) return;
    await controller.syncProtection(
      ref.read(focusShieldStateProvider).shouldProtect,
    );
    if (!mounted) return;
    _stateSubscription = ref.listenManual<FocusShieldState>(
      focusShieldStateProvider,
      (_, state) {
        if (controller.isStarted) {
          unawaited(controller.syncProtection(state.shouldProtect));
        }
      },
    );
    await controller.syncProtection(
      ref.read(focusShieldStateProvider).shouldProtect,
    );
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
