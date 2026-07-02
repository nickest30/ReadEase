class Parent {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String email;
  final String createdAt;

  Parent({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'full_name': fullName,
      'email': email,
      'created_at': createdAt,
    };
  }

  factory Parent.fromMap(Map<String, dynamic> map) {
    return Parent(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}