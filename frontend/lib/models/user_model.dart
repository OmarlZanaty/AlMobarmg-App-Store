class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.subscriptionPlan,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String subscriptionPlan;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      subscriptionPlan: (json['subscription_plan'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'subscription_plan': subscriptionPlan,
    };
  }
}
