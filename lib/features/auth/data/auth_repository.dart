import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_logger.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

// ── Abstract Interface ────────────────────────────────────────────────────────

abstract class AuthRepository {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  Future<UserCredential?> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteAccount();
}

// ── Firebase Implementation ───────────────────────────────────────────────────

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(userCredential.user!);
    return userCredential;
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final batch = _db.batch();

    // 1. Tasks
    final tasks = await _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();
    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
    }

    // 2. Decisions
    final decisions = await _db
        .collection('users')
        .doc(uid)
        .collection('decisions')
        .get();
    for (final doc in decisions.docs) {
      batch.delete(doc.reference);
    }

    // 3. Events
    final events = await _db
        .collection('users')
        .doc(uid)
        .collection('events')
        .get();
    for (final doc in events.docs) {
      batch.delete(doc.reference);
    }

    // 4. Learnings
    final learnings = await _db
        .collection('users')
        .doc(uid)
        .collection('learnings')
        .get();
    for (final doc in learnings.docs) {
      batch.delete(doc.reference);
    }

    // 5. Days
    final days = await _db
        .collection('users')
        .doc(uid)
        .collection('days')
        .get();
    for (final doc in days.docs) {
      batch.delete(doc.reference);
    }

    // 6. Academic
    final academic = await _db
        .collection('users')
        .doc(uid)
        .collection('academic')
        .get();
    for (final doc in academic.docs) {
      batch.delete(doc.reference);
    }

    // 7. Reflections
    final reflectionDates = await _db
        .collection('users')
        .doc(uid)
        .collection('reflections')
        .get();
    for (final dateDoc in reflectionDates.docs) {
      final entries = await dateDoc.reference.collection('entries').get();
      for (final entry in entries.docs) {
        batch.delete(entry.reference);
      }
      batch.delete(dateDoc.reference);
    }

    // 8. Security Data
    final securityData = await _db
        .collection('users')
        .doc(uid)
        .collection('security')
        .get();
    for (final doc in securityData.docs) {
      batch.delete(doc.reference);
    }

    // 9. User Document
    batch.delete(_db.collection('users').doc(uid));

    await batch.commit();

    // Delete auth account
    await user.delete();
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // ── Private ──

  Future<void> _ensureUserDocument(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    int attempts = 0;
    while (true) {
      try {
        final doc = await docRef.get();
        if (!doc.exists) {
          await docRef.set({
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'createdAt': Timestamp.now(),
          });
        }
        break;
      } catch (e, stackTrace) {
        attempts++;
        final errString = e.toString();
        final isPermissionDenied =
            errString.contains('permission-denied') ||
            errString.contains('PERMISSION_DENIED') ||
            (e is FirebaseException && e.code == 'permission-denied');

        if (isPermissionDenied && attempts < 4) {
          AppLogger.warning(
            'AuthRepository: Permission denied while ensuring user document for uid=${user.uid}. '
            'Retrying in ${200 * attempts}ms...',
          );
          await Future.delayed(Duration(milliseconds: 200 * attempts));
          continue;
        }
        AppLogger.error(
          'AuthRepository: Failed to ensure user document for uid=${user.uid} after $attempts attempts',
          e,
          stackTrace,
        );
        rethrow;
      }
    }
  }
}
