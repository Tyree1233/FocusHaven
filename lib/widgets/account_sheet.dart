import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../providers/app_providers.dart';

typedef AccountSheetAction = Future<void> Function();

class AccountSheet extends riverpod.ConsumerStatefulWidget {
  const AccountSheet({
    required this.deleteCloudBackup,
    required this.deleteLocalData,
    required this.openPro,
    required this.openFocusProfile,
    required this.openAppearance,
    required this.openPrivacyPolicy,
    super.key,
  });

  final AccountSheetAction deleteCloudBackup;
  final AccountSheetAction deleteLocalData;
  final AccountSheetAction openPro;
  final AccountSheetAction openFocusProfile;
  final AccountSheetAction openAppearance;
  final AccountSheetAction openPrivacyPolicy;

  @override
  riverpod.ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends riverpod.ConsumerState<AccountSheet> {
  bool _authActionInProgress = false;
  bool _sheetActionInProgress = false;

  bool get _isActionInProgress =>
      _authActionInProgress || _sheetActionInProgress;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your FocusHaven account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                authState.isSignedIn
                    ? 'Signed in as ${authState.displayName}'
                    : 'Sign in to protect your focus history and use cloud backup.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        authState.isSignedIn
                            ? Icons.cloud_done_outlined
                            : Icons.phone_android_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authState.isSignedIn
                              ? 'Your focus data stays on this device. FocusHaven Pro can also back it up privately to your account.'
                              : 'Your focus data stays private on this device. Sign in only when you want optional cloud backup.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (authState.isSignedIn)
                OutlinedButton.icon(
                  onPressed: _isActionInProgress ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    _authActionInProgress ? 'Signing out…' : 'Sign out',
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _isActionInProgress ? null : _signIn,
                  icon: const Icon(Icons.login),
                  label: Text(
                    _authActionInProgress
                        ? 'Signing in…'
                        : 'Sign in with Google',
                  ),
                ),
              if (authState.isSignedIn)
                TextButton.icon(
                  onPressed: _isActionInProgress
                      ? null
                      : () => _runSheetAction(widget.deleteCloudBackup),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete cloud backup'),
                ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.deleteLocalData),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete local data'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openPro),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('FocusHaven Pro'),
              ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openFocusProfile),
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('Discover your focus profile'),
              ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openAppearance),
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Appearance'),
              ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openPrivacyPolicy),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Privacy Policy'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSheetAction(AccountSheetAction action) async {
    if (_isActionInProgress) return;
    setState(() => _sheetActionInProgress = true);
    try {
      await action();
    } catch (_) {
      _showMessage(
        'That account action could not be completed. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _sheetActionInProgress = false);
    }
  }

  bool _beginAuthAction() {
    if (_isActionInProgress) return false;
    setState(() => _authActionInProgress = true);
    return true;
  }

  void _finishAuthAction() {
    if (mounted) setState(() => _authActionInProgress = false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    if (!_beginAuthAction()) return;
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;

      if (result != null) {
        Navigator.pop(context);
        return;
      }

      final message =
          ref.read(authStateProvider).signInError ??
          'Sign-in was not completed. Please try again.';
      _showMessage(message);
    } catch (_) {
      _showMessage('Sign-in could not be completed. Please try again.');
    } finally {
      _finishAuthAction();
    }
  }

  Future<void> _signOut() async {
    if (!_beginAuthAction()) return;
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      _showMessage('Sign-out could not be completed. Please try again.');
    } finally {
      _finishAuthAction();
    }
  }
}
