class UserModel {
  String name;
  String email;
  String token;

  UserModel({required this.name, required this.email, required this.token});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['user']['name'], // تعديل للوصول للبيانات داخل `user`
      email: json['user']['email'],
      token: json['token'] ?? '',
    );
  }
}
