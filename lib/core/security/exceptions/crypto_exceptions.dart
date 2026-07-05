sealed class EncryptionException implements Exception {
  const EncryptionException(this.message, [this.cause]);

  // Human-readable error description (safe to log; never contains key material).
  final String message;

  // Optional underlying cause (e.g. from the `cryptography` package).
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message'
      '${cause != null ? '\n  Caused by: $cause' : ''}';
}

// ── Key Management Exceptions ─────────────────────────────────────────────────

final class KeyNotFoundException extends EncryptionException {
  const KeyNotFoundException([
    super.message = 'Master key not found in secure storage.',
  ]);
}

final class KeyBlobNotFoundException extends EncryptionException {
  const KeyBlobNotFoundException([
    super.message =
        'Encrypted key blob not found in Firestore. '
        'This may be a first-time sign-in; please set up your recovery passphrase.',
  ]);
}

final class InvalidPassphraseException extends EncryptionException {
  const InvalidPassphraseException([
    super.message =
        'Recovery passphrase is incorrect or the key blob is corrupted.',
  ]);
}

// ── Data Encryption Exceptions ────────────────────────────────────────────────

final class DecryptionFailureException extends EncryptionException {
  const DecryptionFailureException(super.message, [super.cause]);
}

final class MalformedEnvelopeException extends EncryptionException {
  const MalformedEnvelopeException(super.message);
}

// ── Migration Exceptions ──────────────────────────────────────────────────────

final class MigrationException extends EncryptionException {
  const MigrationException(super.message, [super.cause]);
}

// ── Key Rotation Exceptions ───────────────────────────────────────────────────

final class KeyRotationException extends EncryptionException {
  const KeyRotationException(super.message, [super.cause]);
}

// ── Extension for UI Copy ────────────────────────────────────────────────────

extension CryptoExceptionExtension on Object {
  String get userFriendlyMessage {
    final error = this;
    if (error is KeyNotFoundException) {
      return 'Security key is missing on this device. Please recover using your passphrase.';
    }
    if (error is KeyBlobNotFoundException) {
      return 'No backup security key was found. If this is a new account, please complete first-time setup.';
    }
    if (error is InvalidPassphraseException) {
      return 'Incorrect passphrase. Please try again.';
    }
    if (error is DecryptionFailureException) {
      return 'Failed to decrypt your data. The security key might be incorrect or the data was corrupted.';
    }
    if (error is MalformedEnvelopeException) {
      return 'Decryption failed due to an unrecognized data format.';
    }
    if (error is EncryptionException) {
      return error.message;
    }

    final errStr = error.toString();
    if (errStr.startsWith('Exception: ')) {
      return errStr.substring(11);
    }
    return errStr;
  }
}
