import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

/// Transformer BLoC : attend `duration` sans nouvel événement (debounce),
/// puis ne garde que le traitement le plus récent (switchMap).
/// Choix délibéré pour la recherche : pas une requête par frappe, et une
/// réponse tardive d'une ancienne recherche ne peut pas écraser la dernière.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}
