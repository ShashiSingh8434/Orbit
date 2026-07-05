import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/recovery_service.dart';
import '../exceptions/crypto_exceptions.dart';
import '../repository/encryption_repository.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../app/router/app_routes.dart';

class PassphraseRecoveryPage extends ConsumerStatefulWidget {
  const PassphraseRecoveryPage({super.key});

  @override
  ConsumerState<PassphraseRecoveryPage> createState() =>
      _PassphraseRecoveryPageState();
}

class _PassphraseRecoveryPageState
    extends ConsumerState<PassphraseRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Actions ──

  Future<void> _recover(String uid) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recovery = ref.read(recoveryServiceProvider);
      await recovery.recoverWithPassphrase(uid, _controller.text.trim());

      // Invalidate the encryption state so the router re-evaluates
      ref.invalidate(encryptionStateProvider(uid));
      ref.invalidate(encryptionRepositoryProvider);

      if (mounted) context.go(AppRoutes.home);
    } on InvalidPassphraseException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failedAttempts++;
          _errorMessage = _failedAttempts >= 3
              ? 'Incorrect passphrase ($_failedAttempts attempts). '
                    'Double-check your passphrase and try again.'
              : 'Incorrect passphrase. Please try again.';
        });
        _controller.clear();
      }
    } on KeyBlobNotFoundException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No encryption key found for this account. '
              'Please sign in on your original device first.';
        });
      }
    } on EncryptionException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.key_outlined,
                        color: cs.onSecondaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'New Device Detected',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  'Your Orbit data is encrypted. Enter the recovery passphrase '
                  'you created on your original device to unlock it here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Info box ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: cs.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is the passphrase you set when you first used Orbit. '
                          'It is different from your Google account password.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Passphrase field ──
                Text(
                  'Recovery Passphrase',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _controller,
                  obscureText: _obscure,
                  enabled: !_isLoading,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your recovery passphrase',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your recovery passphrase.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _recover(uid),
                ),

                // ── Error message ──
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Recover button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : () => _recover(uid),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_outlined),
                    label: Text(
                      _isLoading ? 'Decrypting…' : 'Unlock with Passphrase',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sign out option ──
                Center(
                  child: TextButton.icon(
                    onPressed: _isLoading ? null : _signOut,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Sign out and use a different account'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
