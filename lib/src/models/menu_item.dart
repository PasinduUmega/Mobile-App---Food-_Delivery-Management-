class MenuItemModel {
  const MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.available,
  });

  final int id;
  final String name;
  final String category;
  final double price;
  final bool available;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      available: json['available'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'available': available,
    };
  }

  MenuItemModel copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    bool? available,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      available: available ?? this.available,
    );
  }
}
