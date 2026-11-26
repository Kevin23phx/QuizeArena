import 'package:equatable/equatable.dart';

/// Erreur métier unique vue par le domaine et la présentation.
/// Le domaine ne connaît jamais DioException : la conversion se fait dans `data`
/// (voir core/network/failure_mapper.dart).
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Pas de connexion, timeout, DNS...
final class NetworkFailure extends Failure {
  const NetworkFailure(
      [super.message = 'Connexion impossible. Vérifiez votre réseau.']);
}

/// 401 : session expirée ou jeton invalide (après échec du refresh).
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
      [super.message = 'Session expirée. Reconnectez-vous.']);
}

/// 403 : rôle ou propriété de la ressource insuffisants.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Accès refusé.']);
}

/// 404.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Ressource introuvable.']);
}

/// 409 : doublon (déjà membre, tentative déjà utilisée...).
final class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'Conflit avec l\'état actuel.']);
}

/// 422 : erreurs de validation serveur, par champ (à afficher près des champs).
final class ValidationFailure extends Failure {
  const ValidationFailure({
    String message = 'Données invalides.',
    this.fieldErrors = const {},
  }) : super(message);

  /// ex. {'title': 'Le titre est requis'}
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// 5xx.
final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erreur serveur. Réessayez plus tard.']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Une erreur inattendue est survenue.']);
}
