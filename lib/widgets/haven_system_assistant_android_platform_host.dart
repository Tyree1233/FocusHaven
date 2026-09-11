import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/haven_system_assistant_android_platform_bridge.dart';

/// Enables only the private Android-to-Flutter system-assistant transport.
///
/// Phase 217H declares no App Actions capability or public shortcut. This host
/// merely acknowledges an exact text-free native request into the existing
/// memory-only inbox when Android is foregrounded. The production review host
/// and Haven Action Engine retain all review and execution authority.
final class HavenSystemAssistantAndroidPlatformHost
    extends ConsumerStatefulWidget {
  const HavenSystemAssistantAndroidPlatformHost({
    required this.child,
    this.enabled,
    super.key,
  });

  final Widget child;
  final bool? enabled;

  @override
  ConsumerState<HavenSystemAssistantAndroidPlatformHost> createState() =>
      _HavenSystemAssistantAndroidPlatformHostState();
}

final class _HavenSystemAssistantAndroidPlatformHostState
    extends ConsumerState<HavenSystemAssistantAndroidPlatformHost>
    with WidgetsBindingObserver {
  HavenSystemAssistantAndroidPlatformController? _controller;
  bool _observingLifecycle = false;

  bool get _isEnabled =>
      widget.enabled ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    if (!_isEnabled) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    final controller = ref.read(
      havenSystemAssistantAndroidPlatformControllerProvider,
    );
    _controller = controller;
    unawaited(controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = _controller;
      if (controller != null) unawaited(controller.refresh());
    }
  }

  @override
  void dispose() {
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _controller?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
