class User {
  final int id;
  final String name;
  final String email;
  final String mobile;
  final String address;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.address,
    required this.isVerified,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["id"] as int,
      name: (json["name"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      mobile: (json["mobile"] ?? "").toString(),
      address: (json["address"] ?? "").toString(),
      isVerified: (json["isVerified"] ?? false) as bool,
      createdAt: json["createdAt"] != null ? DateTime.tryParse(json["createdAt"].toString()) : null,
      updatedAt: json["updatedAt"] != null ? DateTime.tryParse(json["updatedAt"].toString()) : null,
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return {
      "name": name,
      "email": email,
      "mobile": mobile,
      "address": address,
      // Password is not stored in this model; send it separately on create/update.
    };
  }
}

