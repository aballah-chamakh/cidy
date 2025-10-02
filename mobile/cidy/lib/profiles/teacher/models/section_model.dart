class Section {
  final int id;
  final String name;
  final int level;

  Section({required this.id, required this.name, required this.level});

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(id: json['id'], name: json['name'], level: json['level']);
  }
}
