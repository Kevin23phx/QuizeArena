# Cahier des charges — QuizArena (T17)

**Projet :** application mobile de quiz de classe  
**Cours :** Advanced Mobile Development — Flutter, BLoC, Node.js, Express et MongoDB  
**Groupe :** 4 membres — noms à compléter  
**Version :** 1.1 — plan d’exécution accéléré jusqu’au dimanche 29 novembre 2026

> Ce cahier traduit les consignes du *Project Book*, notamment la fiche T17 et les exigences techniques et livrables. Il sert de base au document de conception M1; les décisions de détail (champs, écrans, règles de durée) devront être validées par le groupe et consignées dans `docs/design.pdf`.

## 1. Vision et périmètre

QuizArena permet à un enseignant de gérer ses cours et de créer des quiz chronométrés. Les étudiants rejoignent un cours avec un code, répondent à un quiz et consultent leurs résultats. Le serveur corrige les réponses, protège les réponses exactes avant la soumission et calcule les résultats et le classement.

### Acteurs

- **Enseignant** : crée et gère ses cours, quiz et questions; consulte les tentatives et le classement de ses cours.
- **Étudiant** : rejoint un cours par code, passe un quiz autorisé, consulte ses résultats et le classement.

Un compte a un rôle explicite (`teacher` ou `student`). L’inscription et l’attribution des rôles doivent être conçues sans permettre à un utilisateur de s’octroyer le rôle enseignant librement. Le mécanisme retenu (création contrôlée, invitation ou comptes de démonstration) sera fixé à M1.

### Fonctionnalités du périmètre obligatoire

1. Inscription, connexion, renouvellement du jeton et déconnexion.
2. Création et gestion des cours par un enseignant; code de cours unique et partageable.
3. Rejoindre un cours avec un code; empêcher doublons et accès indu.
4. Création d’un quiz rattaché à un cours, avec titre, disponibilité et durée.
5. Création de questions à choix multiples et de propositions; réponse correcte stockée côté serveur.
6. Passage d’un quiz par un étudiant inscrit, avec minuterie et soumission.
7. Une tentative par étudiant et par quiz, sauf règle explicite d’autorisation d’une nouvelle tentative.
8. Correction automatique effectuée exclusivement par l’API après soumission ou expiration.
9. Consultation des résultats par étudiant et par question selon les autorisations; vue enseignant pour ses quiz et ses étudiants.
10. Classement par quiz/cours, calculé à partir des résultats enregistrés par le serveur.

### Règles métier non négociables

- Les réponses correctes ne sont jamais incluses dans les réponses API destinées à l’étudiant avant la soumission. Utiliser des DTO distincts pour la lecture étudiante et les opérations enseignant.
- Le serveur est l’autorité pour l’heure de début/fin, la durée, l’éligibilité, l’unicité de tentative et la note. L’horloge et les calculs du téléphone ne font pas foi.
- Un étudiant ne lit/modifie que ses propres tentatives; il n’accède qu’aux quiz de cours dont il est membre et disponibles pour lui.
- Un enseignant ne gère que ses cours, quiz et questions. Un enseignant ne peut pas administrer les données d’un autre enseignant.
- Les règles ci-dessus sont testées par des tests d’intégration API avec au moins un cas de refus d’accès par ressource.

## 2. Architecture et conventions obligatoires

### Dépôt et environnement

Monorepo unique, hébergé sur GitHub ou GitLab, avec l’enseignant invité dès M0 :

```text
project-root/
  api/                 # Node.js 24+, Express 5, TypeScript, Mongoose
  app/                 # Flutter stable, BLoC/Cubit
  docs/                # design.pdf, report.pdf, slides.pdf, captures et vidéo
  .github/workflows/   # CI sur chaque pull request
  README.md
```

API déployée en HTTPS, MongoDB Atlas, configuration validée au démarrage par variables d’environnement. Aucun secret ni URL sensible dans Git. L’URL de l’API côté Flutter est injectée avec `--dart-define`.

### API

Respecter les couches et modules par ressource : routes → contrôleurs → services → modèles/repositories, avec validation des entrées (Zod ou équivalent), format d’erreur commun, statuts HTTP cohérents, pagination bornée sur chaque liste, filtres/recherche sur au moins une liste et index adaptés. Sécurité : mots de passe Argon2id ou bcrypt, access token à courte durée, refresh token rotatif et stocké haché, révocation à la déconnexion, Helmet, limitation de débit à l’authentification et taille de corps limitée.

### Application Flutter

Organisation **feature-first**; chaque fonctionnalité a ses couches `domain`, `data`, `presentation` (et ses tests) :

```text
lib/
  core/                         # réseau, erreurs, stockage sécurisé, DI, widgets communs
  features/
    auth/{domain,data,presentation}/
    courses/{domain,data,presentation}/
    quizzes/{domain,data,presentation}/
    attempts/{domain,data,presentation}/
    leaderboard/{domain,data,presentation}/
```

Le domaine ne dépend ni de Flutter ni de Dio. Les contrats de repository sont dans le domaine; leurs implémentations et la conversion erreur→`Failure` sont dans `data`. BLoC/Cubit porte la logique d’état; aucun métier dans les widgets. Une composition root unique configure l’injection de dépendances (par ex. `get_it`). Navigation déclarative avec garde d’authentification. Jetons en stockage sécurisé; renouvellement automatique concurrent-safe. Les écrans de données affichent chargement, état vide, erreur avec reprise et contenu. Prévoir au moins une mise à jour optimiste avec rollback, un transformer BLoC délibéré, et cache puis réseau pour la liste principale.

### Pratiques d’équipe et qualité

- Branches courtes et pull requests; toute PR est relue par un autre membre. Aucun push direct sur `main` après M1.
- Issues assignées, jalons M0–M4 tagués (`m1`, `m2`, etc.) et note d’avancement à chaque jalon.
- CI à chaque PR : vérification TypeScript et tests API; formatage, `flutter analyze` et tests Flutter.
- Chaque membre produit des commits/PR substantiels et relus. Chaque membre contribue au code de l’API **et** de l’app et peut expliquer le système complet.

## 3. Modèle fonctionnel initial

Les ressources métier minimales (en plus des utilisateurs) sont reliées entre elles :

| Ressource | Relations et données principales | Contrôle d’accès essentiel |
|---|---|---|
| `courses` | `teacherId`, nom, description, `joinCode`, dates | propriétaire enseignant; lecture étudiant membre |
| `course_memberships` | `courseId`, `studentId`, date d’adhésion | étudiant voit ses adhésions; enseignant voit les membres de son cours |
| `quizzes` | `courseId`, titre, durée, fenêtre d’ouverture, statut, règles de tentative | enseignant propriétaire; étudiant membre et quiz ouvert |
| `questions` | `quizId`, énoncé, choix, réponse correcte, points, ordre | réponses correctes réservées à l’enseignant et à la correction serveur |
| `attempts` | `quizId`, `studentId`, début/fin serveur, réponses soumises, score, état | étudiant voit son résultat; enseignant voit les tentatives de son cours |

Les propositions peuvent être embarquées dans une question si cela simplifie leur lecture; les questions et tentatives sont référencées, car elles sont interrogées séparément. Justifier les décisions embed/reference, unicité, index et stratégie de classement dans `docs/design.pdf`. Index initiaux à évaluer : unicité du code de cours, unicité `(courseId, studentId)` des adhésions, unicité `(quizId, studentId)` des tentatives si une tentative permise, et index de liste/tri sur `courseId`, `quizId`, `studentId`, `createdAt`/score.

### API minimale à concevoir en M1

Les chemins exacts sont à confirmer dans la table d’API de `docs/design.pdf` et du README.

| Domaine | Opérations indicatives | Règle importante |
|---|---|---|
| Auth | `POST /auth/register`, `/login`, `/refresh`, `/logout` | rotation et révocation de session |
| Cours | `POST/GET /courses`, `GET/PATCH/DELETE /courses/:id` | listes paginées; propriétaire/adhésion |
| Adhésion | `POST /courses/join` avec code, `GET /courses/:id/members` | ne pas exposer les codes à des non-autorisés |
| Quiz | créer/lister/consulter/modifier un quiz | route étudiant renvoie seulement les données publiques |
| Questions | gérer les questions d’un quiz | correction inaccessible par endpoint étudiant |
| Tentatives | démarrer, soumettre, consulter mes tentatives | heure et note établies par le serveur; idempotence à définir |
| Résultats | résultats enseignant, résultat étudiant, classement | portée limitée au cours/quiz autorisé; pagination |

Chaque endpoint du document de conception et du README précise méthode, chemin, rôle, code succès, erreurs majeures et règles d’autorisation. Fournir `requests.http`, collection Postman/Bruno ou OpenAPI.

## 4. Répartition des responsabilités (4 membres)

Remplacer « Membre 1–4 » par les noms et identifiants. Les responsables principaux coordonnent leur domaine, mais la revue croisée et les tâches d’app/API garantissent que chacun code dans les deux parties. Le lead participe aussi au code. Les tâches transversales (rapport, UX, release) sont partagées; chaque membre rédige sa contribution individuelle au rapport.

| Membre / rôle principal | Responsabilité de réalisation | Contribution API | Contribution Flutter | Preuve individuelle attendue |
|---|---|---|---|---|
| **Membre 1 — Lead / intégration** | Planning, tableau d’issues, intégration, cohérence des contrats, suivi des jalons; coordonne README et slides | Authentification : routes/services register-login-refresh-logout, validation de configuration et tests du flux | Feature `auth` : écrans/états BLoC, repository et cas d’usage; garde de navigation avec le membre 3 | PR auth API + PR auth app; diagramme d’intégration; présentation du flux de jetons |
| **Membre 2 — Référent API / sécurité** | Modèle MongoDB, sécurité, autorisation, documentation API et revue des règles métier | Cours et adhésions : modèles, services, endpoints, code de jonction, rôles et tests d’accès | Feature `courses` : domaine, data source/repository, BLoC et écrans liste/détail/join | PR cours API + PR courses app; tests d’autorisation; explication des index et règles d’accès |
| **Membre 3 — Référent app / architecture** | Structure feature-first, composition root/DI, navigation, wireframes et revues app | Quiz et questions : schémas, endpoints enseignant et DTO étudiant sans correction, tests de fuite de réponses | Feature `quizzes` : création/édition côté enseignant et affichage côté étudiant; BLoC, états et formulaires | PR quiz/questions API + PR quizzes app; diagramme d’une feature; démonstration de DI et séparation de couches |
| **Membre 4 — Qualité / tests / release** | Pipeline CI, stratégie de tests, analyse statique, builds, seed de démo et contrôle de release; pilote rapport technique et répétition | Tentatives, résultats et classement : soumission, correction serveur, timer, unicité, endpoints paginés et tests d’intégration | Features `attempts` et `leaderboard` : passation/résultat/classement, tests `bloc_test`, timer d’interface non autoritaire, cache principal | PR API + PR app; CI verte; tests des règles serveur; APK installé et démontré |

### Travail partagé obligatoire

- Chaque membre livre au moins une PR applicative et une PR API, chacune relue par un pair différent si possible.
- Les responsabilités de conception, implémentation, tests et documentation sont partagées; le tableau ci-dessus désigne le pilote, pas un propriétaire exclusif.
- Tous les membres relisent les règles métier de T17 et participent au moins à une revue API et une revue Flutter.
- L’optimistic update doit porter sur une action réellement réversible (par exemple adhésion ou favori si ajouté), avec rollback en cas d’échec. Ne jamais afficher comme définitive une note calculée localement.
- Transformer possible : debounce pour recherche de cours/quiz, `droppable` pour pagination/soumission afin d’éviter les doublons. Le choix et la justification sont documentés.
- La fiche recommande le **quiz live en temps réel**. Compte tenu de la semaine disponible, le groupe décide dès le premier jour si un WebSocket end-to-end est réalisable. Si oui, le membre 4 pilote le protocole/API, le membre 3 l’état Flutter, le membre 2 les autorisations et le membre 1 l’intégration. Sinon, choisir dès le premier jour une option avancée de moindre portée et démontrable, par exemple recherche avancée avec debounce et filtres; vérifier que l’enseignant accepte ce choix si la carte T17 recommande spécifiquement le live. Ne pas entamer plusieurs options avancées.

## 5. Fonctionnalité avancée : choix adapté au délai

Le choix par défaut reste le quiz live en temps réel avec WebSocket (ou SSE si suffisant) : l’enseignant démarre une session; les étudiants inscrits la rejoignent; les changements d’état et le classement sont visibles sans actualisation manuelle. Pour tenir le délai, limiter le live à un seul quiz actif par cours et à un flux minimal : démarrer, rejoindre, soumettre, publier résultat/classement. N’ajouter ni chat ni présence détaillée.

Critères minimaux de validation :

1. Changement fait par un utilisateur visible sur un autre appareil connecté, sans refresh manuel.
2. Connexion au canal authentifiée et limitée aux membres du cours et à l’enseignant propriétaire.
3. Le serveur reste maître du timer, de la clôture et du score; aucun événement ne transmet les réponses exactes avant soumission.
4. Reconnexion/échec réseau gérés avec état visible et récupération par lecture API.
5. Test du flux ou protocole principal et démonstration sur deux clients; préciser les limites dans le rapport.

Le groupe doit livrer au moins une fonctionnalité avancée de la liste du Project Book, de bout en bout. Avec une semaine, toute option retenue doit être réduite à un parcours vertical démontrable et intégrée aux couches prévues. Les exigences obligatoires ne sont pas supprimées par cette réduction du délai.

## 6. Écrans et états attendus

- Connexion / inscription et retour d’erreurs de validation serveur `422` près des champs.
- Accueil adapté au rôle : cours enseignés ou cours rejoints.
- Rejoindre un cours par code; liste, détail et membres selon le rôle.
- Création et édition d’un quiz et de ses questions (enseignant).
- Liste et détail des quiz disponibles (étudiant), sans réponse correcte.
- Passation chronométrée, confirmation/soumission, écran de résultat.
- Vue des tentatives/résultats par question (enseignant), résultat personnel (étudiant).
- Classement et état live.

Toute vue qui charge des données doit distinguer chargement, vide, erreur récupérable et contenu. Prévoir erreurs réseau, session expirée, quiz fermé, tentative déjà utilisée, code invalide et indisponibilité live. Les wireframes et la carte de navigation figurent dans le document M1.

## 7. Calendrier accéléré — lundi 23 au dimanche 29 novembre 2026

Ce calendrier suppose un démarrage immédiat et du travail parallèle. Le dimanche est la date limite d’implémentation indiquée par le groupe; confirmer séparément avec l’enseignant les dates officielles de remise et de défense. Les étapes compressent le travail, pas les critères obligatoires du cours.

| Jour | Priorité commune | Livrable / condition de sortie |
|---|---|---|
| **Lundi 23 — cadrage** | Confirmer membres et rôles, repository/board, périmètre Must, décisions de données et API; répartir les issues; produire diagrammes et wireframes essentiels | Contrats API et modèles convenus avant les branches parallèles; liste de risques; squelette monorepo et CI initiale |
| **Mardi 24 — squelette vertical** | Auth API/app, déploiement provisoire, DI/navigations; cours et adhésion démarrés en parallèle | Depuis l’app, login vers API HTTPS; route protégée; une liste de cours avec états; première PR intégrée |
| **Mercredi 25 — cours et quiz** | Finir cours/join code; créer quiz/questions; écrans principaux teacher/student | Création de quiz côté enseignant; étudiant voit uniquement le DTO sans réponses correctes; données seedées |
| **Jeudi 26 — tentative sécurisée** | Soumission, timer serveur, correction, unicité d’essai et résultat; tests d’autorisation associés | Parcours complet enseignant → étudiant → correction serveur; tests démontrent refus d’accès et non-divulgation |
| **Vendredi 27 — complétude obligatoire** | Classement/résultats, pagination et filtre, cache puis réseau, transformer, rollback optimiste, gestion d’erreurs | Toutes les fonctions cœur T17 passent sur les parcours principaux; BLoC et endpoints principaux testés |
| **Samedi 28 — avancée et stabilisation** | Terminer fonctionnalité avancée, CI, tests, sécurité, déploiement, build release, README et rapport/slides | CI verte; API HTTPS; APK installé sur téléphone; seed/comptes de démo; vidéo de secours prête |
| **Dimanche 29 — gel et répétition** | Corriger uniquement les défauts bloquants, vérifier secrets, tagger release, répétition chronométrée de la défense | `v1.0.0`, livrables synchronisés, démo répétée sur API déployée et deux rôles; chacun sait expliquer sa contribution |

**Règle de pilotage :** réunion courte quotidienne (10–15 min); chaque tâche a un responsable, une issue et une PR. Fusionner souvent après revue. Si un blocage menace un critère obligatoire, le signaler le jour même et réduire d’abord les éléments `Could`, puis les embellissements UI; ne pas sacrifier sécurité, architecture, tests de règles serveur, déploiement ou app installable. Toute fonctionnalité avancée alternative doit être validée avec l’enseignant si nécessaire.

## 8. Tests et critères d’acceptation

### Tests API

- Auth : inscription, connexion, refresh rotatif, logout/révocation et refus d’un jeton invalide.
- Pour chaque ressource : opérations principales, validation et tests d’accès interdit (utilisateur B ne lit/modifie pas les données de A).
- Non-divulgation des bonnes réponses dans les endpoints étudiant, avant soumission.
- Timer appliqué par l’API; soumission après expiration rejetée ou traitée selon une règle explicite; note recalculée côté serveur.
- Une tentative par étudiant/quiz, y compris requêtes concurrentes ou répétées; réponse idempotente définie.
- Un enseignant ne traverse pas les frontières de propriété; un étudiant non membre ne rejoint pas un quiz privé.
- Pagination bornée, filtre/recherche, codes de statut et format d’erreur cohérents.

### Tests Flutter

- `bloc_test` pour chaque BLoC/Cubit contenant de la logique, voies réussite et échec.
- Test des états loading/empty/error/content, des erreurs de formulaire `422`, du renouvellement de session concurrent et du rollback optimiste.
- Test du transformer choisi (debounce/droppable) et du comportement de reprise après perte réseau.
- `flutter analyze` propre et code formaté.

### Définition de terminé d’une fonctionnalité

Une fonctionnalité est terminée lorsque son parcours UI, son BLoC, ses cas d’usage/domain, son repository, son API et son modèle sont intégrés; les autorisations et erreurs sont traitées; les tests utiles passent; une PR revue est fusionnée; l’issue, la documentation et la démonstration sont à jour.

## 9. Livrables finaux et défense

- **Dépôt** conforme au monorepo ci-dessus; README avec pitch en deux phrases, membres/rôles, liens API et APK, commandes locales <10 minutes, table des endpoints, comptes de test par rôle et limites connues.
- **API** déployée en HTTPS, Atlas, données de démonstration réalistes et comptes teacher/student. Documentation `requests.http`, Postman/Bruno ou OpenAPI.
- **App** release APK ou app bundle installable et démontré sur un vrai téléphone; configuration d’API au build; version attachée à `v1.0.0`.
- **Design** : `docs/design.pdf`, 6–10 pages, à M1.
- **Rapport** : `docs/report.pdf`, 10–15 pages, avec captures, architecture API/app, adaptations du labo, sécurité et risques OWASP API pertinents, deux BLoC expliqués (événements/états/transformers), tests et limites, fonctionnalité avancée, trois décisions à revoir, contribution individuelle de chaque membre avec liens de PR.
- **Slides** : `docs/slides.pdf`; **vidéo de secours** : `docs/demo.mp4` ou lien indiqué dans le README, trois minutes maximum.
- **Défense live** : parcours réaliste avec au moins deux rôles, API déployée, téléphone réel (deux téléphones ou téléphone + client REST), chaque membre prend la parole puis répond individuellement. Répéter avec minuteur et scénario de panne réseau.

## 10. Préparation de la défense : scénario proposé

1. L’enseignant se connecte, ouvre son cours et démarre un quiz live.
2. Un étudiant rejoint le cours avec le code et ouvre le quiz.
3. Montrer la question et le timer; depuis le client REST ou une vérification documentée, montrer qu’aucune réponse correcte n’est exposée.
4. L’étudiant soumet; démontrer correction serveur et résultat personnel.
5. Montrer le résultat par question côté enseignant et le classement qui se met à jour en direct sur l’autre appareil.
6. Tenter un accès interdit (étudiant vers tentative d’un autre étudiant ou enseignant vers cours d’un autre) et montrer le refus.

Préparer aussi un plan de secours reproductible avec données seedées et vidéo, sans dépendre d’une connexion réseau fragile le jour J.

## 11. Matrice de conformité au Project Book

| Exigence professeur | Réponse prévue dans QuizArena | Vérification / preuve |
|---|---|---|
| Clean Architecture | Domain indépendant de Flutter/Dio; contrats domain, implémentations data, présentation BLoC | Arborescence, diagramme feature, revue PR |
| Feature-first | `auth`, `courses`, `quizzes`, `attempts`, `leaderboard`, chacune avec couches | Arborescence `app/lib/features/` |
| Dependency injection | Composition root unique (`get_it` ou équivalent) | Configuration et explication en défense |
| API déployée | Node 24+, Express 5, TypeScript, MongoDB Atlas, HTTPS | URL health/API dans README, démonstration M2/M4 |
| Application installable | Build release APK/app bundle, installée sur téléphone réel | Release `v1.0.0` et démonstration |
| Sécurité | Tokens/rotation, validation, rate limit, règles rôle/objet; correction et timer serveur | Tests API, rapport et essais live |
| Tests et CI | Intégration API, autorisation; `bloc_test`; checks API/app à chaque PR | Pipeline vert et résultats de tests |
| Pratiques d’équipe | Git/PR revues, board, jalons/tags, contributions visibles de chacun | Historique Git, issues, PR, peer evaluation |
| Rapport et soutenance | Rapport 10–15 pages, slides, vidéo de secours, 25 min | Fichiers `docs/`, répétition chronométrée |
| Fonction avancée | Quiz live temps réel, authentifié et autorisé | Démo deux clients et preuve de mise à jour sans refresh |

## 12. Décisions à fermer le lundi 23 novembre

1. Comment autoriser/créer un compte enseignant sans auto-attribution abusive du rôle.
2. Détail de la question : choix unique seulement ou sélection multiple; barème et égalités du classement.
3. Règle précise après expiration et lorsqu’une connexion tombe pendant la tentative.
4. Peut-on autoriser une nouvelle tentative, et qui l’autorise?
5. Comportement d’une tentative interrompue, répétée ou envoyée deux fois.
6. Mécanisme live retenu (WebSocket/SSE), événements et stratégie de reconnexion.
7. Fournisseur de déploiement, URL, jeu de données de démonstration et coût/limites.
8. Attribution des noms/IDs aux quatre responsabilités et calendrier des revues.
 
## Référence

Consignes extraites de `project_book.pdf` : section 3 (exigences techniques), fiche T17 (QuizArena), sections 5–8 (livrables, défense, notation, intégrité), et checklists de l’annexe A. Le projet doit rester compris et défendable par chacun; toute assistance ou code externe utilisé doit être compris, vérifié et déclaré dans le rapport selon les consignes du cours.
