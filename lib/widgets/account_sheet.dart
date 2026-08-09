import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../providers/app_providers.dart';

typedef AccountSheetAction = Future<void> Function();

class AccountSheet extends riverpod.ConsumerWidget {
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
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final authService = ref.read(authServiceProvider);

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
                  onPressed: authService.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                )
              else
                FilledButton.icon(
                  onPressed: () => _signIn(context, ref),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
              if (authState.isSignedIn)
                TextButton.icon(
                  onPressed: deleteCloudBackup,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete cloud backup'),
                ),
              TextButton.icon(
                onPressed: deleteLocalData,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete local data'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: openPro,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('FocusHaven Pro'),
              ),
              TextButton.icon(
                onPressed: openFocusProfile,
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('Discover your focus profile'),
              ),
              TextButton.icon(
                onPressed: openAppearance,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Appearance'),
              ),
              TextButton.icon(
                onPressed: openPrivacyPolicy,
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Privacy Policy'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, riverpod.WidgetRef ref) async {
    final result = await ref.read(authServiceProvider).signInWithGoogle();
    if (!context.mounted) return;

    if (result != null) {
      Navigator.pop(context);
      return;
    }

    final message =
        ref.read(authStateProvider).signInError ??
        'Sign-in was not completed. Please try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
