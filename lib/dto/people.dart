import 'dart:convert';
import 'dart:typed_data';

class People {
  final String id;
  final String? studentId;
  final String name;
  final String? email;
  final String? classification;
  final List<List<double>> embeddings;
  final List<Uint8List> images;

  People({
    required this.id,
    required this.name,
    required this.classification,
    this.studentId,
    this.email,
    this.embeddings = const [],
    this.images = const <Uint8List>[],
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
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => base64Decode(e as String))
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
      'images': images.map((i) => base64Encode(i)).toList(),
    };
  }

  /// Convert to a Map suitable for storing in SQLite.
  /// Embeddings and images are stored as JSON strings under their columns.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'name': name,
      'email': email,
      'classification': classification,
      'embeddings': jsonEncode(embeddings),
      'images': jsonEncode(images.map((i) => base64Encode(i)).toList()),
    };
  }

  /// Construct a People from a DB row (embeddings and images are expected to be JSON strings)
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
        decodedEmbeddings = [];
      }
    }

    List<Uint8List> decodedImages = [];
    if (map['images'] != null) {
      try {
        final dynamic rawImg = jsonDecode(map['images'] as String);
        if (rawImg is List) {
          decodedImages = rawImg.map<Uint8List>((e) => base64Decode(e.toString())).toList();
        }
      } catch (_) {
        decodedImages = [];
      }
    }

    return People(
      id: map['id'] as String,
      studentId: map['studentId'] as String?,
      name: map['name'] as String,
      email: map['email'] as String?,
      classification: map['classification'] as String?,
      embeddings: decodedEmbeddings,
      images: decodedImages,
    );
  }
}
