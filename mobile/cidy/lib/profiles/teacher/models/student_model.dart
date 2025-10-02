class Student {
  final int id;
  final String fullname;
  final String? image;
  final double paid;
  final double unpaid;

  Student({
    required this.id,
    required this.fullname,
    this.image,
    required this.paid,
    required this.unpaid,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      fullname: json['full_name'],
      image: json['profile_image'],
      paid: double.tryParse(json['paid_amount']?.toString() ?? '0.0') ?? 0.0,
      unpaid:
          double.tryParse(json['unpaid_amount']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}
