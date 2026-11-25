import 'package:equatable/equatable.dart';

/// Page de résultats, selon l'enveloppe commune des listes du contrat :
/// { "data": [ ... ], "meta": { "page": 1, "limit": 20, "total": 42 } }
class Paginated<T> extends Equatable {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  /// Lit l'enveloppe JSON brute. `fromJson` convertit un élément de `data`.
  factory Paginated.fromEnvelope(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final meta = json['meta'] as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    return Paginated<T>(
      items: [for (final e in data) fromJson(e as Map<String, dynamic>)],
      page: meta['page'] as int,
      limit: meta['limit'] as int,
      total: meta['total'] as int,
    );
  }

  final List<T> items;
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;

  @override
  List<Object?> get props => [items, page, limit, total];
}
