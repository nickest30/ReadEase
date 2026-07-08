class Teacher {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String email;
  final String schoolName;
  final String createdAt;
  final String? firebaseUid;

  Teacher({
    this.id,
    this.firebaseUid,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.email,
    required this.schoolName,
    required this.createdAt
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'username': username,
      'password_hash': passwordHash,
      'full_name': fullName,
      'email': email,
      'school_name': schoolName,
      'created_at': createdAt,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as int?,
      firebaseUid: map['firebase_uid'] as String?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      schoolName: map['school_name'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}