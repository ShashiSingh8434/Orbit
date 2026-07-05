import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/recovery_service.dart';
import '../exceptions/crypto_exceptions.dart';
import '../repository/encryption_repository.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../app/router/app_routes.dart';

final _uidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

class PassphraseSetupPage extends ConsumerStatefulWidget {
  const PassphraseSetupPage({super.key});

  @override
  ConsumerState<PassphraseSetupPage> createState() =>
      _PassphraseSetupPageState();
}

class _PassphraseSetupPageState extends ConsumerState<PassphraseSetupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  bool _acknowledged = false;
  String? _errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Actions ──

  Future<void> _submit(String uid) async {
    if (!_acknowledged) {
      setState(
        () =>
            _errorMessage = 'Please acknowledge the warning before continuing.',
      );
      _shakeController.forward(from: 0);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recovery = ref.read(recoveryServiceProvider);
      await recovery.setupPassphrase(uid, _passphraseController.text.trim());

      // Invalidate the encryption state so the router re-evaluates
      ref.invalidate(encryptionStateProvider(uid));
      ref.invalidate(encryptionRepositoryProvider);

      if (mounted) context.go(AppRoutes.home);
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
    // Retrieve the UID from the auth state — the router guarantees a user
    // is present when this page is shown.
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // We need uid — retrieve from auth state via provider
    final uid = ref.watch(_uidProvider);
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
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: cs.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Secure Your Data',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  'Orbit encrypts your data on your device. '
                  'You need a recovery passphrase to access it on a new device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                // ── ⚠ Warning card ──
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (ctx, child) {
                    final offset =
                        _shakeAnim.value *
                        8 *
                        (0.5 - (_shakeAnim.value % 1)).sign;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: cs.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Critical Warning',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: cs.error,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _warningBullet(
                          context,
                          'This passphrase protects the key that encrypts ALL your '
                          'Orbit data (reflections, decisions, tasks, etc.).',
                        ),
                        const SizedBox(height: 6),
                        _warningBullet(
                          context,
                          'If you sign in on a new device, you will need this '
                          'passphrase to decrypt your data.',
                        ),
                        const SizedBox(height: 6),
                        _warningBullet(
                          context,
                          'Orbit cannot reset or recover your passphrase. '
                          'There is NO account recovery option.',
                        ),
                        const SizedBox(height: 10),
                        _warningBullet(
                          context,
                          'Forgetting this passphrase means your data is '
                          'permanently unreadable.',
                          isCritical: true,
                        ),
                        const SizedBox(height: 14),
                        // Acknowledgement checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acknowledged,
                              activeColor: cs.primary,
                              onChanged: (v) =>
                                  setState(() => _acknowledged = v ?? false),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _acknowledged = !_acknowledged,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'I understand that losing this passphrase means '
                                    'losing access to my data permanently.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                  controller: _passphraseController,
                  obscureText: _obscure1,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Choose a strong passphrase',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure1 ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Passphrase cannot be empty.';
                    }
                    if (v.trim().length < 12) {
                      return 'Use at least 12 characters for security.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(uid),
                ),

                const SizedBox(height: 16),

                // ── Confirm passphrase field ──
                Text(
                  'Confirm Passphrase',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscure2,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Re-enter your passphrase',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure2 ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passphraseController.text) {
                      return 'Passphrases do not match.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(uid),
                ),

                // ── Error message ──
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Submit button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : () => _submit(uid),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock),
                    label: Text(
                      _isLoading
                          ? 'Securing your data…'
                          : 'Create Passphrase & Continue',
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

                // ── Hint about Argon2id ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Protected with Argon2id + AES-256-GCM',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _warningBullet(
    BuildContext context,
    String text, {
    bool isCritical = false,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: isCritical ? 2 : 5),
          child: Icon(
            isCritical ? Icons.dangerous : Icons.circle,
            size: isCritical ? 16 : 8,
            color: isCritical ? cs.error : cs.onErrorContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onErrorContainer,
              fontWeight: isCritical ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
