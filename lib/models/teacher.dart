class Teacher {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String email;
  final String schoolName;
  final bool emailVerified;              // NEW
  final String? phoneNumber;             // NEW
  final bool phoneVerified;              // NEW
  final String? phoneVerifiedAt;         // NEW
  final String? backupCodeHash;          // NEW
  final bool backupCodeUsed;             // NEW
  final String createdAt;
  final String? firebaseUid;
  final String? lastSyncedAt;            // NEW
  final bool pendingSync;                // NEW

  Teacher({
    this.id,
    this.firebaseUid,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.email,
    required this.schoolName,
    this.emailVerified = false,
    this.phoneNumber,
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.backupCodeHash,
    this.backupCodeUsed = false,
    required this.createdAt,
    this.lastSyncedAt,
    this.pendingSync = false,
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
      'email_verified': emailVerified ? 1 : 0,
      'phone_number': phoneNumber,
      'phone_verified': phoneVerified ? 1 : 0,
      'phone_verified_at': phoneVerifiedAt,
      'backup_code_hash': backupCodeHash,
      'backup_code_used': backupCodeUsed ? 1 : 0,
      'created_at': createdAt,
      'last_synced_at': lastSyncedAt,
      'pending_sync': pendingSync ? 1 : 0,
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
      emailVerified: ((map['email_verified'] as int?) ?? 0) == 1,
      phoneNumber: map['phone_number'] as String?,
      phoneVerified: ((map['phone_verified'] as int?) ?? 0) == 1,
      phoneVerifiedAt: map['phone_verified_at'] as String?,
      backupCodeHash: map['backup_code_hash'] as String?,
      backupCodeUsed: ((map['backup_code_used'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] as String,
      lastSyncedAt: map['last_synced_at'] as String?,
      pendingSync: ((map['pending_sync'] as int?) ?? 0) == 1,
    );
  }
}