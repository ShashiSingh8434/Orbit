import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/security/services/recovery_service.dart';
import '../../../core/security/repository/encryption_repository.dart';

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  late AuthRepository _repo;

  @override
  Future<void> build() async {
    _repo = ref.watch(authRepositoryProvider);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.signInWithGoogle);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();

    // Clear the local master key before signing out so no key material
    // remains on device after the session ends.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ref.read(recoveryServiceProvider).clearLocalKey(uid);
        ref.invalidate(encryptionStateProvider(uid));
        ref.invalidate(encryptionRepositoryProvider);
      } catch (_) {
        // Non-fatal — proceed with sign-out even if key clear fails
      }
    }

    state = await AsyncValue.guard(_repo.signOut);
  }

  /// Permanently deletes the user's account and clears their local master key.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Clear all key data locally first
        await ref.read(recoveryServiceProvider).clearLocalKey(uid);
        ref.invalidate(encryptionStateProvider(uid));
        ref.invalidate(encryptionRepositoryProvider);
      } catch (_) {
        // Non-fatal, continue deletion
      }
    }

    state = await AsyncValue.guard(_repo.deleteAccount);
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }
}
