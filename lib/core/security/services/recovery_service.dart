import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_logger.dart';
import 'key_manager.dart';
import '../repository/encryption_repository.dart';
import '../../../features/auth/controllers/auth_controller.dart';

// ── Encryption State ──────────────────────────────────────────────────────────

/// Describes the encryption readiness state for the current authenticated user.
///
/// This is computed by [RecoveryService.getEncryptionState] immediately after
/// a user signs in. The router uses this value to decide which page to show.
enum EncryptionState {
  /// Master key is present in secure storage. The app can read/write encrypted
  /// documents immediately. No UI gate needed.
  ready,

  /// No key in secure storage AND no key blob in Firestore.
  /// This is the user's **first-ever login** (or they deleted all their data).
  /// The app must show the passphrase-setup page.
  needsSetup,

  /// No key in secure storage, BUT a key blob exists in Firestore.
  /// This is a **new device** — the user must enter their recovery passphrase
  /// to decrypt the blob and restore the master key.
  needsRecovery,
}

// ── Provider ──────────────────────────────────────────────────────────────────

final recoveryServiceProvider = Provider<RecoveryService>(
  (ref) => RecoveryService(
    keyManager: ref.read(keyManagerProvider),
    enc: ref.read(encryptionRepositoryProvider),
  ),
  name: 'recoveryServiceProvider',
);

// ── Service ───────────────────────────────────────────────────────────────────

/// Determines the encryption state and orchestrates key setup / recovery flows.
///
/// This is the entry point for the post-login encryption bootstrap. After
/// [authStateProvider] emits a non-null user, the router calls
/// [getEncryptionState] and redirects accordingly.
class RecoveryService {
  RecoveryService({required this._keyManager, required this._enc});

  final KeyManager _keyManager;
  final EncryptionRepository _enc;

  // ── State Detection ───────────────────────────────────────────────────────

  /// Determines the current [EncryptionState] for [uid].
  ///
  /// Order of checks:
  /// 1. Master key in secure storage → [EncryptionState.ready]
  /// 2. Key blob in Firestore → [EncryptionState.needsRecovery]
  /// 3. No blob anywhere → [EncryptionState.needsSetup]
  Future<EncryptionState> getEncryptionState(String uid) async {
    AppLogger.debug('RecoveryService: Checking encryption state for uid=$uid');

    final keyPresent = await _keyManager.isMasterKeyPresent(uid);
    if (keyPresent) {
      AppLogger.debug('RecoveryService: State=ready for uid=$uid');
      return EncryptionState.ready;
    }

    final blobPresent = await _keyManager.isKeyBlobPresent(uid);
    if (blobPresent) {
      AppLogger.info(
        'RecoveryService: State=needsRecovery for uid=$uid (new device)',
      );
      return EncryptionState.needsRecovery;
    }

    AppLogger.info(
      'RecoveryService: State=needsSetup for uid=$uid (first login)',
    );
    return EncryptionState.needsSetup;
  }

  // ── Setup ─────────────────────────────────────────────────────────────────

  /// Creates a new master key protected by [passphrase].
  ///
  /// Should be called from the passphrase-setup page after the user confirms
  /// their passphrase. After this completes, [getEncryptionState] will return
  /// [EncryptionState.ready].
  Future<void> setupPassphrase(String uid, String passphrase) async {
    AppLogger.info('RecoveryService: Setting up passphrase for uid=$uid');
    await _keyManager.createMasterKey(uid, passphrase);
    AppLogger.info('RecoveryService: Passphrase setup complete for uid=$uid');
  }

  // ── Recovery ─────────────────────────────────────────────────────────────

  /// Recovers the master key using [passphrase] on a new device.
  ///
  /// Should be called from the passphrase-recovery page. After this completes,
  /// [getEncryptionState] will return [EncryptionState.ready].
  ///
  /// Throws [InvalidPassphraseException] if the passphrase is wrong.
  Future<void> recoverWithPassphrase(String uid, String passphrase) async {
    AppLogger.info('RecoveryService: Attempting key recovery for uid=$uid');
    await _keyManager.recoverMasterKey(uid, passphrase);
    AppLogger.info('RecoveryService: Key recovery complete for uid=$uid');
  }

  // ── Sign-Out ──────────────────────────────────────────────────────────────

  /// Clears the master key from secure storage and the in-memory DEK cache.
  ///
  /// Called on sign-out. The encrypted key blob in Firestore is preserved so
  /// the user can recover on next sign-in.
  ///
  /// ⚠️ After this call, the user's data is unreadable until they sign back in
  /// and enter their recovery passphrase.
  Future<void> clearLocalKey(String uid) async {
    await _keyManager.clearMasterKey(uid);
    _enc.clearCacheForUser(uid);
    AppLogger.info(
      'RecoveryService: Local key and DEK cache cleared for uid=$uid',
    );
  }
}

// ── Async State Providers ────────────────────────────────────────────────────

/// Provides the current [EncryptionState] for the authenticated user.
///
/// This is watched by the router's redirect guard. The state is re-evaluated
/// whenever [authStateProvider] changes.
///
/// This provider is intentionally **not auto-disposed** — the encryption state
/// should persist across route changes.
final encryptionStateProvider = FutureProvider.family<EncryptionState, String>((
  ref,
  uid,
) async {
  final service = ref.read(recoveryServiceProvider);
  return service.getEncryptionState(uid);
}, name: 'encryptionStateProvider');

/// Reactively tracks the encryption state of the currently signed-in user.
///
/// When the user signs out or the auth state changes, this resolves to null.
/// When the user's encryptionStateProvider is updated or invalidated, this provider
/// also updates, notifying GoRouter via the router notifier listener.
final currentEncryptionStateProvider = FutureProvider<EncryptionState?>((
  ref,
) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  return ref.watch(encryptionStateProvider(user.uid).future);
}, name: 'currentEncryptionStateProvider');
