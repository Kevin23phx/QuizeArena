import 'package:get_it/get_it.dart';

/// Accès au conteneur d'injection de dépendances.
/// Séparé de injection.dart (composition root) pour que la présentation puisse
/// résoudre ses BLoC sans importer toutes les features (pas de cycle d'imports).
final GetIt sl = GetIt.instance;
