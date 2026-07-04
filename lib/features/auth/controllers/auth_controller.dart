import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/security/services/recovery_service.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    state = await AsyncValue.guard(_repo.signOut);

    if (uid != null) {
      try {
        await ref.read(recoveryServiceProvider).clearLocalKey(uid);
      } catch (_) {
        // Non-fatal — proceed
      }
    }
  }

  /// Permanently deletes the user's account and clears their local master key.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    state = await AsyncValue.guard(_repo.deleteAccount);

    if (uid != null) {
      try {
        await ref.read(recoveryServiceProvider).clearLocalKey(uid);
      } catch (_) {
        // Non-fatal
      }
    }
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }
}
