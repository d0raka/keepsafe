/// A tiny `Result` type so the data/crypto layers can report expected
/// failures (wrong password, corrupt file) as values instead of throwing.
///
/// Unexpected/programmer errors should still throw. This is only for the
/// handful of outcomes the UI must react to gracefully.
library;

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The success value, or throws if this is an [Err].
  T get value => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final error) => throw StateError('Result is Err: $error'),
      };

  /// The error, or null if this is an [Ok].
  VaultError? get errorOrNull =>
      switch (this) { Err<T>(:final error) => error, _ => null };

  R fold<R>(R Function(T value) onOk, R Function(VaultError error) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final error) => onErr(error),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  @override
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final VaultError error;
}

/// Expected, user-facing failure categories.
enum VaultError {
  /// Master password was wrong, or the file was tampered with (GCM auth fail).
  wrongPasswordOrTampered,

  /// File is not a recognisable KeepSafe vault envelope.
  notAVault,

  /// Envelope uses a format/version this build cannot read.
  unsupportedVersion,

  /// File could not be read/written (I/O, permissions).
  ioFailure,
}
