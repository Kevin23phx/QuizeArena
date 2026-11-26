import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../session/session_cubit.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../di/injection.dart';

/// Pages TEMPORAIRES pour valider la garde de navigation.
/// À remplacer : login par features/auth (Membre 1), home par l'accueil par rôle.

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: Builder(
        builder: (context) {
          final state = context.watch<SessionCubit>().state;
          final label = state is SessionAuthenticated ? state.role.name : '?';
          return Scaffold(
            appBar: AppBar(
              title: Text('Accueil ($label)'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => context.read<AuthCubit>().logout(),
                ),
              ],
            ),
            body: const Center(child: Text('Route protégée OK')),
          );
        },
      ),
    );
  }
}
