import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/focus_haven_localizations.dart';
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
  Future<String?>? _priceFuture;
  bool _storeActionInProgress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _priceFuture ??= ref
        .read(iapServiceProvider)
        .proPrice(localizations: context.l10n);
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
    final l10n = context.l10n;
    try {
      await ref.read(iapServiceProvider).buyPro(localizations: l10n);
      _showMessage(l10n.proCompletePurchase);
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(l10n.proPurchaseCouldNotStart);
    } finally {
      _finishStoreAction();
    }
  }

  Future<void> _restorePurchases() async {
    if (!_beginStoreAction()) return;
    final l10n = context.l10n;
    try {
      await ref.read(iapServiceProvider).restorePurchases();
      _showMessage(l10n.proCheckingPreviousPurchases);
    } catch (_) {
      _showMessage(l10n.proRestoreCouldNotStart);
    } finally {
      _finishStoreAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(proEntitlementProvider);
    final legacyLifetimePurchasesEnabled = ref
        .read(iapServiceProvider)
        .legacyLifetimePurchasesEnabled;
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
                        tooltip: context.l10n.proBackTooltip,
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
                  context.l10n.proTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  legacyLifetimePurchasesEnabled
                      ? context.l10n.proLegacyDescription
                      : context.l10n.proSubscriptionDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                ProBenefit(
                  icon: Icons.cloud_done_outlined,
                  label: context.l10n.proBenefitSecureBackup,
                ),
                ProBenefit(
                  icon: Icons.devices_outlined,
                  label: context.l10n.proBenefitRestoreDevice,
                ),
                if (legacyLifetimePurchasesEnabled)
                  ProBenefit(
                    icon: Icons.all_inclusive,
                    label: context.l10n.proBenefitLifetime,
                  )
                else ...[
                  ProBenefit(
                    icon: Icons.auto_awesome_outlined,
                    label: context.l10n.proBenefitEnhancedCoaching,
                  ),
                  ProBenefit(
                    icon: Icons.calendar_view_month_outlined,
                    label: context.l10n.proBenefitMonthly,
                  ),
                  ProBenefit(
                    icon: Icons.savings_outlined,
                    label: context.l10n.proBenefitAnnual,
                  ),
                ],
                const SizedBox(height: 22),
                FutureBuilder<String?>(
                  future: _priceFuture,
                  builder: (context, snapshot) {
                    final price = snapshot.data;
                    return FilledButton(
                      onPressed:
                          legacyLifetimePurchasesEnabled &&
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
                            ? context.l10n.proActive
                            : isPro == null
                            ? entitlementFailed
                                  ? context.l10n.proStatusUnavailable
                                  : context.l10n.proCheckingStatus
                            : !legacyLifetimePurchasesEnabled
                            ? context.l10n.proPlansComingSoon
                            : price == null
                            ? context.l10n.proUnavailable
                            : context.l10n.proUnlockForPrice(price),
                      ),
                    );
                  },
                ),
                if (isPro == false || entitlementFailed)
                  TextButton(
                    onPressed: _storeActionInProgress
                        ? null
                        : _restorePurchases,
                    child: Text(context.l10n.proRestorePurchases),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
