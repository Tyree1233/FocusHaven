import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    try {
      if (!widget.isSignedIn) {
        _showMessage('Sign in with Google to back up your focus data');
        return;
      }

      final isPro = await ref.read(iapServiceProvider).refreshEntitlement();
      if (!mounted) return;
      if (!isPro) {
        _showMessage('Upgrade to Pro to use cloud backup');
        return;
      }

      final succeeded = await ref
          .read(cloudSyncServiceProvider)
          .syncFocusData(widget.backup);
      _showMessage(
        succeeded
            ? 'Focus data backed up securely'
            : 'Backup failed. Check your Firebase setup.',
      );
    } catch (_) {
      _showMessage('Cloud backup could not be completed right now');
    } finally {
      _finishAction();
    }
  }

  Future<void> _restore() async {
    if (!_beginAction('restore')) return;
    try {
      if (!widget.isSignedIn) {
        _showMessage('Sign in with Google to restore your focus data');
        return;
      }

      final isPro = await ref.read(iapServiceProvider).refreshEntitlement();
      if (!mounted) return;
      if (!isPro) {
        _showMessage('Upgrade to Pro to restore cloud backup');
        return;
      }

      final result = await ref
          .read(cloudSyncServiceProvider)
          .fetchFocusDataResult();
      if (!mounted) return;
      final message = switch (result.status) {
        CloudBackupFetchStatus.found =>
          widget.restoreBackup(result.backup!)
              ? 'Focus data restored from cloud'
              : 'That cloud backup could not be restored',
        CloudBackupFetchStatus.notFound => 'No cloud backup found yet',
        CloudBackupFetchStatus.unauthenticated =>
          'Sign in with Google to restore your focus data',
        CloudBackupFetchStatus.invalid =>
          'That cloud backup could not be restored',
        CloudBackupFetchStatus.unavailable =>
          'Cloud restore is unavailable. Check your connection and try again.',
      };
      _showMessage(message);
    } catch (_) {
      _showMessage('Cloud restore could not be completed right now');
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
          label: Text(activeAction == 'backup' ? 'Backing up…' : 'Back up'),
        ),
        TextButton.icon(
          onPressed: isBusy ? null : _restore,
          icon: const Icon(Icons.cloud_download_outlined),
          label: Text(activeAction == 'restore' ? 'Restoring…' : 'Restore'),
        ),
      ],
    );
  }
}
