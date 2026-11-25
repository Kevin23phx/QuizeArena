import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/network/failure_mapper.dart';
import 'package:quizarena/core/network/paginated.dart';

DioException _badResponse(int status, Object? body) {
  final req = RequestOptions(path: '/courses');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: req,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('mapDioException (ErrorResponse du contrat)', () {
    test('422 : details [{field, message}] -> erreurs par champ', () {
      final failure = mapDioException(_badResponse(422, {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Requête invalide',
          'details': [
            {'field': 'name', 'message': 'Le nom est requis'},
            {'field': 'description', 'message': 'Trop long'},
          ],
        },
      }));

      expect(failure, isA<ValidationFailure>());
      final v = failure as ValidationFailure;
      expect(v.message, 'Requête invalide');
      expect(v.fieldErrors, {
        'name': 'Le nom est requis',
        'description': 'Trop long',
      });
    });

    test('403 -> ForbiddenFailure avec le message serveur', () {
      final failure = mapDioException(_badResponse(403, {
        'error': {'code': 'FORBIDDEN', 'message': 'Réservé aux enseignants', 'details': []},
      }));
      expect(failure, const ForbiddenFailure('Réservé aux enseignants'));
    });

    test('404 (code invalide) et 401', () {
      expect(
        mapDioException(_badResponse(404, {
          'error': {'code': 'NOT_FOUND', 'message': 'Cours introuvable', 'details': []},
        })),
        isA<NotFoundFailure>(),
      );
      expect(
        mapDioException(_badResponse(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Jeton invalide', 'details': []},
        })),
        isA<UnauthorizedFailure>(),
      );
    });

    test('timeout -> NetworkFailure', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/courses'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioException(e), isA<NetworkFailure>());
    });
  });

  group('Paginated.fromEnvelope', () {
    final json = {
      'data': [
        {'id': 'a'},
        {'id': 'b'},
      ],
      'meta': {'page': 1, 'limit': 2, 'total': 5},
    };

    test('lit data et meta', () {
      final page = Paginated<String>.fromEnvelope(json, (j) => j['id'] as String);
      expect(page.items, ['a', 'b']);
      expect(page.total, 5);
      expect(page.hasMore, isTrue);
    });

    test('dernière page : hasMore faux', () {
      final last = Paginated<String>.fromEnvelope(
        {
          'data': [
            {'id': 'e'},
          ],
          'meta': {'page': 3, 'limit': 2, 'total': 5},
        },
        (j) => j['id'] as String,
      );
      expect(last.hasMore, isFalse);
    });
  });
}
