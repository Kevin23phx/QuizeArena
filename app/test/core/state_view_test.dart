import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/widgets/state_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('loading', (tester) async {
    await tester.pumpWidget(_wrap(
      StateView(status: ViewStatus.loading, contentBuilder: (_) => const Text('c')),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('empty', (tester) async {
    await tester.pumpWidget(_wrap(
      StateView(
        status: ViewStatus.empty,
        emptyMessage: 'Aucun quiz',
        contentBuilder: (_) => const Text('c'),
      ),
    ));
    expect(find.text('Aucun quiz'), findsOneWidget);
  });

  testWidgets('error avec reprise', (tester) async {
    var retried = 0;
    await tester.pumpWidget(_wrap(
      StateView(
        status: ViewStatus.error,
        failure: const NetworkFailure(),
        onRetry: () => retried++,
        contentBuilder: (_) => const Text('c'),
      ),
    ));
    expect(find.text(const NetworkFailure().message), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, 1);
  });

  testWidgets('content', (tester) async {
    await tester.pumpWidget(_wrap(
      StateView(status: ViewStatus.content, contentBuilder: (_) => const Text('ok')),
    ));
    expect(find.text('ok'), findsOneWidget);
  });
}
