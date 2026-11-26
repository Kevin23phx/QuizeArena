import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../session/session_cubit.dart';
import '../storage/token_storage.dart';

/// Pages TEMPORAIRES pour valider la garde de navigation.
/// À remplacer : login par features/auth (Membre 1), home par l'accueil par rôle.

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class LoginPlaceholderPage extends StatelessWidget {
  const LoginPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion (placeholder)')),
      body: Center(
        child: Wrap(
          spacing: 12,
          children: [
            ElevatedButton(
              onPressed: () =>
                  context.read<SessionCubit>().signedIn(UserRole.teacher),
              child: const Text('Simuler enseignant'),
            ),
            ElevatedButton(
              onPressed: () =>
                  context.read<SessionCubit>().signedIn(UserRole.student),
              child: const Text('Simuler étudiant'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionCubit>().state;
    final label = state is SessionAuthenticated ? state.role.name : '?';
    return Scaffold(
      appBar: AppBar(
        title: Text('Accueil ($label)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<SessionCubit>().signedOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route protégée OK'),
            const SizedBox(height: 16),
            // Raccourci de démonstration vers la feature quizzes (à retirer
            // quand l'accueil par rôle et la feature courses seront intégrés).
            FilledButton(
              onPressed: () => context.push('/courses/demo-course/quizzes'),
              child: const Text('Quiz du cours démo'),
            ),
          ],
        ),
      ),
    );
  }
}
