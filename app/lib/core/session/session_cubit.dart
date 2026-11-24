import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/token_storage.dart';

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

/// Démarrage : on n'a pas encore lu le stockage sécurisé.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.role);

  final UserRole role;

  @override
  List<Object?> get props => [role];
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

/// Source de vérité unique de la session, utilisée par le router (garde d'auth).
///
/// Le Membre 1 (feature auth) appelle `signedIn` après un login réussi et
/// `signedOut` après un logout. L'intercepteur réseau appelle `signedOut`
/// quand le refresh échoue.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._storage) : super(const SessionUnknown());

  final TokenStorage _storage;

  Future<void> restore() async {
    final token = await _storage.readRefreshToken();
    final role = await _storage.readRole();
    if (token != null && role != null) {
      emit(SessionAuthenticated(role));
    } else {
      emit(const SessionUnauthenticated());
    }
  }

  void signedIn(UserRole role) => emit(SessionAuthenticated(role));

  Future<void> signedOut() async {
    await _storage.clear();
    emit(const SessionUnauthenticated());
  }
}
