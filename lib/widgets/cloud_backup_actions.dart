import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/focus_haven_localizations.dart';
import '../providers/app_providers.dart';
import '../services/cloud_sync_service.dart';

typedef CloudBackupRestorer = bool Function(Map<String, dynamic> backup);

class CloudBackupActions extends ConsumerStatefulWidget {
  const CloudBackupActions({
    required this.isSignedIn,
    required this.backup,
    required this.restoreBackup,
    super.key,
  });

  final bool isSignedIn;
  final Map<String, dynamic> backup;
  final CloudBackupRestorer restoreBackup;

  @override
  ConsumerState<CloudBackupActions> createState() => _CloudBackupActionsState();
}

class _CloudBackupActionsState extends ConsumerState<CloudBackupActions> {
  String? _activeAction;

  bool _beginAction(String action) {
    if (_activeAction != null) return false;
    setState(() => _activeAction = action);
    return true;
  }

  void _finishAction() {
    if (mounted) setState(() => _activeAction = null);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _backUp() async {
    if (!_beginAction('backup')) return;
    final l10n = context.l10n;
    try {
      if (!widget.isSignedIn) {
        _showMessage(l10n.cloudBackupSignInToBackUp);
        return;
      }

      final isPro = await ref.read(iapServiceProvider).refreshEntitlement();
      if (!mounted) return;
      if (!isPro) {
        _showMessage(l10n.cloudBackupUpgradeToBackUp);
        return;
      }

      final succeeded = await ref
          .read(cloudSyncServiceProvider)
          .syncFocusData(widget.backup);
      _showMessage(
        succeeded ? l10n.cloudBackupSucceeded : l10n.cloudBackupFailed,
      );
    } catch (_) {
      _showMessage(l10n.cloudBackupUnavailable);
    } finally {
      _finishAction();
    }
  }

  Future<void> _restore() async {
    if (!_beginAction('restore')) return;
    final l10n = context.l10n;
    try {
      if (!widget.isSignedIn) {
        _showMessage(l10n.cloudRestoreSignIn);
        return;
      }

      final isPro = await ref.read(iapServiceProvider).refreshEntitlement();
      if (!mounted) return;
      if (!isPro) {
        _showMessage(l10n.cloudRestoreUpgrade);
        return;
      }

      final result = await ref
          .read(cloudSyncServiceProvider)
          .fetchFocusDataResult();
      if (!mounted) return;
      final message = switch (result.status) {
        CloudBackupFetchStatus.found =>
          widget.restoreBackup(result.backup!)
              ? l10n.cloudRestoreSucceeded
              : l10n.cloudRestoreInvalid,
        CloudBackupFetchStatus.notFound => l10n.cloudRestoreNotFound,
        CloudBackupFetchStatus.unauthenticated => l10n.cloudRestoreSignIn,
        CloudBackupFetchStatus.invalid => l10n.cloudRestoreInvalid,
        CloudBackupFetchStatus.unavailable => l10n.cloudRestoreUnavailable,
      };
      _showMessage(message);
    } catch (_) {
      _showMessage(l10n.cloudRestoreCouldNotComplete);
    } finally {
      _finishAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAction = _activeAction;
    final isBusy = activeAction != null;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: isBusy ? null : _backUp,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(
            activeAction == 'backup'
                ? context.l10n.cloudBackupInProgress
                : context.l10n.cloudBackupAction,
          ),
        ),
        TextButton.icon(
          onPressed: isBusy ? null : _restore,
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(
            activeAction == 'restore'
                ? context.l10n.cloudRestoreInProgress
                : context.l10n.cloudRestoreAction,
          ),
        ),
      ],
    );
  }
}
