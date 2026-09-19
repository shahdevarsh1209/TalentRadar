import 'package:flutter/foundation.dart';

/// A title from the master list. Profiles store [code]; [name] is for display.
@immutable
class JobTitle {
  const JobTitle({
    required this.code,
    required this.name,
    this.category = '',
    this.aliases = const [],
  });

  final String code;
  final String name;
  final String category;
  final List<String> aliases;

  factory JobTitle.fromJson(Map<String, dynamic> json) => JobTitle(
        code: '${json['code']}',
        name: '${json['name']}',
        category: '${json['category'] ?? ''}',
        aliases: (json['aliases'] as List?)?.map((alias) => '$alias').toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'category': category,
      };

  /// The alias that explains why this title matched, so the suggestion row can
  /// show "also known as SDE" rather than leaving the user guessing.
  String? matchedAlias(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (name.toLowerCase().contains(trimmed)) return null;
    for (final alias in aliases) {
      if (alias.toLowerCase().contains(trimmed)) return alias;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is JobTitle && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
