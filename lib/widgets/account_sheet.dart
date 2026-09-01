import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../l10n/focus_haven_localizations.dart';
import '../providers/app_providers.dart';

typedef AccountSheetAction = Future<void> Function();

class AccountSheet extends riverpod.ConsumerStatefulWidget {
  const AccountSheet({
    required this.deleteAccount,
    required this.deleteCloudBackup,
    required this.deleteLocalData,
    required this.openPro,
    required this.openFocusProfile,
    required this.openAppearance,
    required this.openPrivacyPolicy,
    super.key,
  });

  final AccountSheetAction deleteAccount;
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
    final supportsAppleSignIn = ref.watch(
      authServiceProvider.select((auth) => auth.supportsAppleSignIn),
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.accountTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.accountCloseTooltip,
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                authState.isSignedIn
                    ? context.l10n.accountSignedInAs(authState.displayName)
                    : context.l10n.accountSignedOutDescription,
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
                              ? context.l10n.accountSignedInPrivacy
                              : context.l10n.accountSignedOutPrivacy,
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
                    _authActionInProgress
                        ? context.l10n.accountSigningOut
                        : context.l10n.accountSignOut,
                  ),
                )
              else ...[
                if (supportsAppleSignIn) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white38,
                      disabledForegroundColor: Colors.black54,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isActionInProgress ? null : _signInWithApple,
                    icon: const Icon(Icons.apple),
                    label: Text(
                      _authActionInProgress
                          ? context.l10n.accountSigningIn
                          : context.l10n.accountContinueWithApple,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (supportsAppleSignIn)
                  OutlinedButton.icon(
                    onPressed: _isActionInProgress ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text(
                      _authActionInProgress
                          ? context.l10n.accountSigningIn
                          : context.l10n.accountSignInWithGoogle,
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _isActionInProgress ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text(
                      _authActionInProgress
                          ? context.l10n.accountSigningIn
                          : context.l10n.accountSignInWithGoogle,
                    ),
                  ),
              ],
              if (authState.isSignedIn)
                TextButton.icon(
                  onPressed: _isActionInProgress
                      ? null
                      : () => _runSheetAction(widget.deleteCloudBackup),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.accountDeleteCloudBackup),
                ),
              if (authState.isSignedIn)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _isActionInProgress
                      ? null
                      : () => _runSheetAction(widget.deleteAccount),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(context.l10n.accountDeleteAccount),
                ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.deleteLocalData),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(context.l10n.accountDeleteLocalData),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openPro),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(context.l10n.accountPro),
              ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openFocusProfile),
                icon: const Icon(Icons.psychology_outlined),
                label: Text(context.l10n.accountDiscoverProfile),
              ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openAppearance),
                icon: const Icon(Icons.palette_outlined),
                label: Text(context.l10n.accountAppearance),
              ),
              TextButton.icon(
                onPressed: _isActionInProgress
                    ? null
                    : () => _runSheetAction(widget.openPrivacyPolicy),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(context.l10n.accountPrivacyPolicy),
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
    final l10n = context.l10n;
    try {
      await action();
    } catch (_) {
      _showMessage(l10n.accountActionFailed);
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

  Future<void> _signInWithGoogle() =>
      _signIn(() => ref.read(authServiceProvider).signInWithGoogle());

  Future<void> _signInWithApple() =>
      _signIn(() => ref.read(authServiceProvider).signInWithApple());

  Future<void> _signIn(Future<Object?> Function() authenticate) async {
    if (!_beginAuthAction()) return;
    final l10n = context.l10n;
    try {
      final result = await authenticate();
      if (!mounted) return;

      if (result != null) {
        Navigator.pop(context);
        return;
      }

      final message =
          ref.read(authStateProvider).signInError ??
          l10n.accountSignInNotCompleted;
      _showMessage(message);
    } catch (_) {
      _showMessage(l10n.accountSignInFailed);
    } finally {
      _finishAuthAction();
    }
  }

  Future<void> _signOut() async {
    if (!_beginAuthAction()) return;
    final l10n = context.l10n;
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      _showMessage(l10n.accountSignOutFailed);
    } finally {
      _finishAuthAction();
    }
  }
}
