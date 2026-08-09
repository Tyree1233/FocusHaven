import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'pro_benefit.dart';

class ProSheet extends ConsumerStatefulWidget {
  const ProSheet({super.key});

  @override
  ConsumerState<ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends ConsumerState<ProSheet> {
  static const _ink = Color(0xFF211442);

  final ScrollController _scrollController = ScrollController();
  late final Future<String?> _priceFuture;
  bool _storeActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _priceFuture = ref.read(iapServiceProvider).proPrice();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _beginStoreAction() {
    if (_storeActionInProgress) return false;
    setState(() => _storeActionInProgress = true);
    return true;
  }

  void _finishStoreAction() {
    if (mounted) setState(() => _storeActionInProgress = false);
  }

  Future<void> _buyPro() async {
    if (!_beginStoreAction()) return;
    try {
      await ref.read(iapServiceProvider).buyPro();
      _showMessage('Complete your purchase in the store window');
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('The store could not start this purchase right now');
    } finally {
      _finishStoreAction();
    }
  }

  Future<void> _restorePurchases() async {
    if (!_beginStoreAction()) return;
    try {
      await ref.read(iapServiceProvider).restorePurchases();
      _showMessage('Checking the store for previous purchases');
    } catch (_) {
      _showMessage('Previous purchases could not be checked right now');
    } finally {
      _finishStoreAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(proEntitlementProvider);
    final isPro = entitlement.value;
    final entitlementFailed = entitlement.hasError;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.workspace_premium,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'FocusHaven Pro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Protect your focus progress with secure cloud backup and restore it on your other devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                const ProBenefit(
                  icon: Icons.cloud_done_outlined,
                  label: 'Secure cloud backup',
                ),
                const ProBenefit(
                  icon: Icons.devices_outlined,
                  label: 'Restore on another device',
                ),
                const ProBenefit(
                  icon: Icons.all_inclusive,
                  label: 'One-time lifetime unlock',
                ),
                const SizedBox(height: 22),
                FutureBuilder<String?>(
                  future: _priceFuture,
                  builder: (context, snapshot) {
                    final price = snapshot.data;
                    return FilledButton(
                      onPressed:
                          isPro == false &&
                              price != null &&
                              !_storeActionInProgress
                          ? _buyPro
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: _ink,
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: Text(
                        isPro == true
                            ? 'FocusHaven Pro is active'
                            : isPro == null
                            ? entitlementFailed
                                  ? 'Pro status is unavailable'
                                  : 'Checking Pro status'
                            : price == null
                            ? 'Pro is not available yet'
                            : 'Unlock Pro for $price',
                      ),
                    );
                  },
                ),
                if (isPro == false || entitlementFailed)
                  TextButton(
                    onPressed: _storeActionInProgress
                        ? null
                        : _restorePurchases,
                    child: const Text('Restore purchases'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
