class AppImage {
  const AppImage({
    required this.id,
    required this.name,
    required this.managedPath,
    required this.addedAt,
  });

  final String id;
  final String name;
  final String managedPath;
  final DateTime addedAt;

  factory AppImage.fromJson(Map<String, dynamic> json) {
    return AppImage(
      id: json['id'] as String,
      name: json['name'] as String,
      managedPath: json['managedPath'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'managedPath': managedPath,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  AppImage copyWith({String? id, String? name, String? managedPath, DateTime? addedAt}) {
    return AppImage(
      id: id ?? this.id,
      name: name ?? this.name,
      managedPath: managedPath ?? this.managedPath,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
