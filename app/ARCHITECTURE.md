# Architecture de l'app QuizArena (Flutter)

Document tenu par le Membre 3 (référent app / architecture).

## Règle de dépendance (Clean Architecture, feature-first)

```
presentation (widgets, BLoC/Cubit)  ──►  domain (entités, contrats repository, usecases)
data (datasource Dio, DTO, repository impl) ──►  domain
```

- `domain` : Dart pur. **Interdit** : `package:flutter`, `package:dio`.
- `data` : implémente les contrats du domaine, convertit `DioException` -> `Failure`
  via `core/network/failure_mapper.dart`.
- `presentation` : BLoC/Cubit portent la logique d'état, les widgets n'en contiennent aucune.
- Les features ne s'importent pas entre elles en `data`/`domain`. Partage = `core/`.

## Arborescence d'une feature

```
features/<feature>/
  <feature>_module.dart      # enregistrement DI de la feature (seul fichier DI à toucher)
  domain/    entities/  repositories/ (abstract)  usecases/
  data/      datasources/  models/ (DTO fromJson)  repositories/ (impl)
  presentation/  bloc/  pages/  widgets/
test/features/<feature>/     # bloc_test + tests repository/usecases
```

## Injection de dépendances (composition root unique)

`lib/core/di/injection.dart` : seul endroit qui connaît les implémentations concrètes.
Chaque feature s'enregistre dans son `*_module.dart` :

- datasource / repository / usecases : `registerLazySingleton` (type = **contrat du domaine**)
- BLoC / Cubit : `registerFactory` (état neuf à chaque écran)
- dans un widget : `BlocProvider(create: (_) => sl<MonBloc>())`

## Navigation

`core/router/app_router.dart` (go_router). La garde est la fonction pure
`redirectFor(SessionState, location)` (testée). `SessionCubit` est la source de vérité
de la session : `signedIn(role)` après login, `signedOut()` après logout ou refresh raté.
Chaque membre ajoute les routes de sa feature dans `routes: [...]`.

## Réseau et erreurs

- `API_URL` injectée via `--dart-define=API_URL=https://...` (jamais en dur).
- `AuthInterceptor` : Bearer automatique ; sur 401, **un seul** refresh partagé
  (single-flight), puis rejeu des requêtes ; échec -> session fermée.
- Toute erreur remonte au BLoC sous forme de `Failure` (sealed class).
  `ValidationFailure.fieldErrors` sert à afficher les erreurs 422 près des champs.

## États d'écran

Tout écran de données utilise `StateView` : `loading | empty | error (+ Réessayer) | content`.

## Checklist de revue de PR Flutter

- [ ] `domain/` n'importe ni Flutter ni Dio
- [ ] Contrat de repository dans `domain`, implémentation dans `data`
- [ ] Aucune logique métier dans les widgets
- [ ] Erreurs converties en `Failure` dans `data`
- [ ] Les 4 états d'écran gérés (`StateView`)
- [ ] BLoC enregistré en `registerFactory` dans le `*_module.dart`
- [ ] `bloc_test` : succès + échec
- [ ] Pas de secret ni d'URL en dur
- [ ] `dart format .` et `flutter analyze` propres
- [ ] Une note calculée localement n'est jamais présentée comme définitive

## Commandes

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run --dart-define=API_URL=http://10.0.2.2:3000
```
