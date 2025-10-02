class Subject {
  final int id;
  final String name;
  final int? section;
  final int level;

  Subject({
    required this.id,
    required this.name,
    this.section,
    required this.level,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'],
      name: json['name'],
      section: json['section'],
      level: json['level'],
    );
  }
}
