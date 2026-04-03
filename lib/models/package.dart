class Package {
  final String name;
  final String? displayName;
  final String? iconPath;
  final String version;
  final String description;
  final String? installedVersion;
  final bool isInstalled;
  final String? size;
  final String? section;

  const Package({
    required this.name,
    required this.version,
    required this.description,
    this.displayName,
    this.iconPath,
    this.installedVersion,
    this.isInstalled = false,
    this.size,
    this.section,
  });

  /// Human-readable name: displayName from .desktop, or raw package name.
  String get effectiveName => displayName ?? name;

  Package copyWith({
    String? name,
    String? displayName,
    String? iconPath,
    String? version,
    String? description,
    String? installedVersion,
    bool? isInstalled,
    String? size,
    String? section,
  }) {
    return Package(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      iconPath: iconPath ?? this.iconPath,
      version: version ?? this.version,
      description: description ?? this.description,
      installedVersion: installedVersion ?? this.installedVersion,
      isInstalled: isInstalled ?? this.isInstalled,
      size: size ?? this.size,
      section: section ?? this.section,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Package && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
