class SavedLink {
  SavedLink({
    required this.id,
    required this.url,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String title;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static SavedLink fromMap(Map<dynamic, dynamic> map) {
    return SavedLink(
      id: map['id']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}