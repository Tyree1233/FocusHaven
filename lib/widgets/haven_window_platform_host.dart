import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/haven_window_platform_bridge.dart';

/// Activates a reviewed Haven Window transport on iOS and Android.
///
/// Startup performs a non-prompting authorization read. Calendar permission
/// can be requested only through the explicit action exposed by the card.
class HavenWindowPlatformHost extends ConsumerStatefulWidget {
  const HavenWindowPlatformHost({required this.child, this.enabled, super.key});

  final Widget child;
  final bool? enabled;

  @override
  ConsumerState<HavenWindowPlatformHost> createState() =>
      _HavenWindowPlatformHostState();
}

class _HavenWindowPlatformHostState
    extends ConsumerState<HavenWindowPlatformHost> {
  HavenWindowPlatformController? _controller;

  bool get _isEnabled =>
      widget.enabled ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android));

  @override
  void initState() {
    super.initState();
    if (!_isEnabled) return;
    final controller = ref.read(havenWindowPlatformControllerProvider);
    _controller = controller;
    unawaited(controller.start());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
