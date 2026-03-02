class User {
  final int userId;
  final String email;
  
  User({
    required this.userId,
    required this.email,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      email: json['email'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
    };
  }
}