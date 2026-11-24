# QuizArena API

L’API fournit le serveur Express, la validation de configuration, MongoDB, les routes de santé, l’authentification, les opérations de cours, les quiz/questions et le parcours de tentative avec timer de 10 secondes par question et correction serveur. Les vues de résultats enseignant, le classement et le mode live restent à implémenter.

## Prérequis

- Node.js 24 ou plus récent
- npm
- MongoDB local ou une URI MongoDB Atlas

## Démarrage local

```bash
cp .env.example .env
npm install
npm run dev
```

Avant de démarrer, générez une valeur privée pour `JWT_ACCESS_SECRET` avec `openssl rand -base64 32`, puis placez-la dans votre fichier `.env`. Ne partagez pas cette valeur et ne la commitez pas.

Le serveur démarre sur le port défini par `PORT` (3000 par défaut). Vérifier :

- `GET http://localhost:3000/api/v1/health` : le processus répond.
- `GET http://localhost:3000/api/v1/ready` : le processus répond et MongoDB est connecté.

## Commandes

- `npm run dev` : serveur de développement avec redémarrage automatique.
- `npm run typecheck` : vérifie les types TypeScript sans générer de fichiers.
- `npm run build` : compile `src/` dans `dist/`.
- `npm start` : démarre la version compilée.
- `npm test` : lance les tests d’intégration; ils exigent la base MongoDB dédiée `quizarena_test`.

## Tests d’intégration

Copier `.env.test.example` sous `.env.test`, vérifier que MongoDB local est actif, puis exécuter `npm test`. Les tests effacent et recréent les données dans `quizarena_test`; ne configure pas cette URI vers une base de développement ou de production.

Les contrats des routes se trouvent dans `../docs/openapi.yaml`.

Ne jamais committer `.env`. Ajouter les prochaines variables à `.env.example` avec des valeurs d’exemple non secrètes.
