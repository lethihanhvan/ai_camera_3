import 'dart:convert';

class People {
  final String id;
  final String? studentId;
  final String name;
  final String? email;
  final String? classification;
  final List<List<double>> embeddings;

  People({
    required this.id,
    required this.name,
    required this.classification,
    this.studentId,
    this.email,
    this.embeddings = const [],
  });

  factory People.fromJson(Map<String, dynamic> json) {
    return People(
      id: json['id'] as String,
      name: json['name'] as String,
      classification: json['classification'] as String?,
      studentId: json['studentId'] as String?,
      email: json['email'] as String?,
      embeddings: (json['embeddings'] as List<dynamic>?)
              ?.map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
              .toList() ??
          [],
    );
  }

  /// Convert to a JSON-serializable map (useful for APIs)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'name': name,
      'email': email,
      'classification': classification,
      'embeddings': embeddings,
    };
  }

  /// Convert to a Map suitable for storing in SQLite.
  /// Embeddings are stored as a JSON string under the `embeddings` column.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'name': name,
      'email': email,
      'classification': classification,
      'embeddings': jsonEncode(embeddings),
    };
  }

  /// Construct a People from a DB row (embeddings is expected to be a JSON string)
  factory People.fromMap(Map<String, dynamic> map) {
    List<List<double>> decodedEmbeddings = [];
    if (map['embeddings'] != null) {
      try {
        final dynamic raw = jsonDecode(map['embeddings'] as String);
        if (raw is List) {
          decodedEmbeddings = raw
              .map<List<double>>((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
              .toList();
        }
      } catch (_) {
        // If decoding fails, leave embeddings empty
        decodedEmbeddings = [];
      }
    }

    return People(
      id: map['id'] as String,
      studentId: map['studentId'] as String?,
      name: map['name'] as String,
      email: map['email'] as String?,
      classification: map['classification'] as String?,
      embeddings: decodedEmbeddings,
    );
  }
}