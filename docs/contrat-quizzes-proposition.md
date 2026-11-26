# Contrat Quiz et Questions — PROPOSITION (Membre 3, à valider par le groupe)

L'app Flutter (feature `quizzes`) est déjà codée sur ce contrat. Tout écart doit
être décidé ensemble avant le code API correspondant. Même conventions que le
contrat Courses : préfixe `/api/v1`, enveloppe `{ "data": ... }` (liste : `+ "meta"`),
erreurs `{ "error": { "code", "message", "details": [ { "field", "message" } ] } }`,
pagination `page` / `limit` (max 50).

## Endpoints

| Méthode | Chemin | Rôle | Succès | Erreurs |
|---|---|---|---|---|
| GET | `/courses/{courseId}/quizzes?page&limit&q` | enseignant propriétaire, étudiant membre | 200 liste paginée | 401, 404 |
| POST | `/courses/{courseId}/quizzes` | enseignant propriétaire | 201 `{data: Quiz}` | 401, 403, 404, 422 |
| GET | `/quizzes/{quizId}` | propriétaire, étudiant membre (quiz publié) | 200 `{data: Quiz}` | 401, 404 |
| PATCH | `/quizzes/{quizId}` | enseignant propriétaire | 200 `{data: Quiz}` | 401, 403, 404, 422 |
| DELETE | `/quizzes/{quizId}` | enseignant propriétaire | 204 | 401, 403, 404 |
| GET | `/quizzes/{quizId}/questions` | **enseignant propriétaire uniquement** | 200 `{data: Question[]}` | 401, 403, 404 |
| POST | `/quizzes/{quizId}/questions` | enseignant propriétaire | 201 `{data: Question}` | 401, 403, 404, 422 |
| PATCH | `/questions/{questionId}` | enseignant propriétaire | 200 `{data: Question}` | 401, 403, 404, 422 |
| DELETE | `/questions/{questionId}` | enseignant propriétaire | 204 | 401, 403, 404 |

Règles :
- Un étudiant ne voit que les quiz **publiés** des cours dont il est membre. Un quiz
  brouillon ou d'un autre cours répond **404** (comme pour les cours).
- Les questions avec `correctIndex` ne sont **jamais** servies à un étudiant. La
  lecture des questions pendant une tentative se fait via la feature `attempts`
  (Membre 4), avec un DTO distinct **sans** `correctIndex`.
- Test d'intégration demandé : un étudiant appelle `GET /quizzes/{id}/questions`
  -> 403 ; aucune réponse étudiante ne contient `correctIndex`.
- Publier (`status: "published"`) exige au moins une question, sinon **422**.

## Schémas

**Quiz**
```json
{
  "id": "string",
  "courseId": "string",
  "title": "string (1-100)",
  "durationMinutes": 20,
  "status": "draft | published",
  "questionCount": 2,
  "opensAt": "date-time | null",
  "closesAt": "date-time | null"
}
```

**Corps de POST/PATCH quiz** : `title`, `durationMinutes` (entier >= 1), `status`,
`opensAt`, `closesAt` (les deux dates sont toujours envoyées ; `null` = pas de date).
Erreur 422 si `closesAt` <= `opensAt`.

**Question** (vue enseignant)
```json
{
  "id": "string",
  "quizId": "string",
  "text": "string (1-500)",
  "choices": ["string", "string"],
  "correctIndex": 0,
  "points": 2,
  "order": 1
}
```

**Corps de POST/PATCH question** : `text`, `choices` (2 à 4 chaînes non vides),
`correctIndex` (index valide dans `choices`), `points` (entier >= 1).
Choix unique uniquement (décision à confirmer).

## Questions ouvertes pour le responsable API
1. `questionCount` est-il calculé par le serveur ? (l'app l'affiche dans les listes)
2. L'ordre des questions : automatique à la création (ordre d'ajout) ?
3. Un étudiant peut-il lire un quiz hors fenêtre d'ouverture (détail seul) ou 404 ?
