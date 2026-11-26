import 'failure.dart';

/// Résultat d'une opération du domaine : succès ou `Failure`.
/// Les repositories ne lancent pas d'exception vers le domaine : ils renvoient
/// un `Result`, ce qui force l'appelant à traiter l'échec.
///
/// Usage :
///   switch (result) {
///     case Ok(:final value): ...
///     case Err(:final failure): ...
///   }
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
