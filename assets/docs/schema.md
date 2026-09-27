# ReadEase Database Schema

**Version:** 1.0
**Last updated:** September 2026

This document defines the complete data structure for ReadEase,
covering both the local SQLite cache and the cloud Firestore database.

---

## 1. Design Principles

| Principle | Description |
|-----------|-------------|
| **Cloud is source of truth** | Firestore holds the authoritative account, class, and progress data |
| **SQLite is a cache** | Local device stores everything needed for offline use |
| **PIN stays local** | 4-digit PIN hashes are NEVER synced to cloud (security) |
| **Offline-first** | All core features work without internet |
| **Role-based collections** | Students, parents, teachers live in separate collections |
| **Flat over nested** | Queries use flat collections where possible to avoid index requirements |

---

## 2. Firestore Structure

### 2.1 `students/{studentUid}`

One document per student (solo or linked).

| Field | Type | Description |
|-------|------|-------------|
| `username` | string | Login username (unique) |
| `displayName` | string | Name shown in UI |
| `gradeLevel` | number | 1-6 |
| `totalPoints` | number | Accumulated points |
| `badgeCount` | number | Unique (grade, difficulty) passes |
| `parentId` | string? | Firebase UID of linked parent (null if solo) |
| `classId` | string? | Firestore class document ID (null if not joined) |
| `className` | string? | Denormalized class name for quick display |
| `firebaseUid` | string | Same as document ID |
| `createdAt` | timestamp | Account creation |
| `lastUpdated` | timestamp | Last sync |

**Read access:** student themselves, their linked parent, their teacher
**Write access:** student themselves

### 2.2 `parents/{parentUid}`

One document per parent account.

| Field | Type | Description |
|-------|------|-------------|
| `username` | string | Login username (unique) |
| `fullName` | string | Full name |
| `email` | string | Email address |
| `firebaseUid` | string | Same as document ID |
| `createdAt` | timestamp | Account creation |
| `lastUpdated` | timestamp | Last sync |

**Read/write access:** parent themselves only

### 2.3 `teachers/{teacherUid}`

One document per teacher account.

| Field | Type | Description |
|-------|------|-------------|
| `username` | string | Login username (unique) |
| `fullName` | string | Full name |
| `email` | string | Email address |
| `schoolName` | string | School name |
| `firebaseUid` | string | Same as document ID |
| `createdAt` | timestamp | Account creation |
| `lastUpdated` | timestamp | Last sync |

**Read/write access:** teacher themselves only

### 2.4 `classes/{classId}` (top-level, flat)

One document per class. Enables join-code lookup without collection group indexes.

| Field | Type | Description |
|-------|------|-------------|
| `teacherUid` | string | Firestore UID of the owning teacher |
| `teacherName` | string | Denormalized teacher name |
| `className` | string | Class name |
| `gradeLevel` | number | 1-6 |
| `joinCode` | string | 6-character uppercase code |
| `studentCount` | number | Enrolled student count |
| `createdAt` | timestamp | Class creation |

**Read access:** any authenticated user (for join-code lookup)
**Write access:** only the owning teacher

### 2.5 `classes/{classId}/enrollments/{studentUid}`

One document per enrolled student.

| Field | Type | Description |
|-------|------|-------------|
| `studentName` | string | Student display name |
| `gradeLevel` | number | Student's grade |
| `totalPoints` | number | Snapshot of points at enrollment |
| `enrolledAt` | timestamp | Enrollment time |

**Read access:** owning teacher + the student themselves
**Write access:** the student themselves (self-enrollment)

### 2.6 `students/{studentUid}/results/{resultId}` (M4)

Per-quiz result history. Synced from local SQLite.

| Field | Type | Description |
|-------|------|-------------|
| `gradeLevel` | number | 1-6 |
| `difficulty` | string | easy / medium / hard |
| `score` | number | Correct answers |
| `totalQuestions` | number | Total questions |
| `pointsEarned` | number | Points awarded |
| `wrongWordIds` | array<number> | IDs of missed words |
| `completedAt` | timestamp | Quiz completion time |

### 2.7 `students/{studentUid}/badges/{badgeId}` (M4)

Earned badges.

| Field | Type | Description |
|-------|------|-------------|
| `gradeLevel` | number | 1-6 |
| `difficulty` | string | easy / medium / hard |
| `badgeName` | string | Human-readable name |
| `pointsEarned` | number | Points at badge award |
| `earnedAt` | timestamp | Award time |

### 2.8 `leaderboard/{studentUid}`

Global ranking snapshot. Denormalized for fast sorted queries.

| Field | Type | Description |
|-------|------|-------------|
| `displayName` | string | Student name |
| `gradeLevel` | number | 1-6 |
| `totalPoints` | number | Accumulated points |
| `badgeCount` | number | Badge count |
| `classId` | string? | For class-scoped filtering |
| `lastUpdated` | timestamp | Last sync |

**Read access:** any authenticated user
**Write access:** the student themselves

---

## 3. SQLite Structure

Local cache on the device. Mirrors Firestore for offline use.

### 3.1 `students`

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | Local ID |
| `username` | TEXT UNIQUE | |
| `password_hash` | TEXT | Bcrypt hash (local only) |
| `display_name` | TEXT | |
| `grade_level` | INTEGER | |
| `pin_hash` | TEXT | Bcrypt hash (local only, NEVER synced) |
| `is_linked` | INTEGER | 0 = solo, 1 = linked |
| `parent_id` | INTEGER? | Local FK |
| `total_points` | INTEGER | |
| `firebase_uid` | TEXT | Links to cloud |
| `class_firestore_id` | TEXT? | Firestore class ID |
| `class_name` | TEXT? | Denormalized |
| `last_synced_at` | TEXT? | ISO timestamp |
| `pending_sync` | INTEGER | 0 = synced, 1 = needs push |
| `created_at` | TEXT | ISO timestamp |

### 3.2 `parents`

Same as Firestore parents, plus `password_hash` (local bcrypt), `firebase_uid`, `last_synced_at`, `pending_sync`.

### 3.3 `teachers`

Same as Firestore teachers, plus `password_hash`, `firebase_uid`, `last_synced_at`, `pending_sync`.

### 3.4 `class_groups`

Local cache of joined/created classes.

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | |
| `teacher_id` | INTEGER | |
| `firestore_id` | TEXT? | Cloud ID |
| `class_name` | TEXT | |
| `grade_level` | INTEGER | |
| `join_code` | TEXT UNIQUE | |
| `created_at` | TEXT | |

### 3.5 `class_enrollments`

Local cache of student ↔ class relationships.

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | |
| `class_group_id` | INTEGER | |
| `student_id` | INTEGER | |
| `enrolled_at` | TEXT | |

### 3.6 `words` (unchanged)

Lesson content. Seeded locally, never synced.

### 3.7 `quiz_results` (unchanged, plus M4 sync flag)

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | |
| `student_id` | INTEGER | |
| `grade_level` | INTEGER | |
| `difficulty` | TEXT | |
| `score` | INTEGER | |
| `total_questions` | INTEGER | |
| `points_earned` | INTEGER | |
| `wrong_word_ids` | TEXT | JSON array |
| `completed_at` | TEXT | ISO timestamp |
| `synced_to_cloud` | INTEGER | 0 = pending, 1 = synced (M4) |

### 3.8 `badges` (M4)

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | |
| `student_id` | INTEGER | |
| `grade_level` | INTEGER | |
| `difficulty` | TEXT | |
| `badge_name` | TEXT | |
| `points_earned` | INTEGER | |
| `earned_at` | TEXT | |
| `synced_to_cloud` | INTEGER | 0 or 1 |

### 3.9 `sync_queue` (M4)

Offline actions waiting to sync.

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK | |
| `action_type` | TEXT | "quiz_submit", "class_join", "profile_update" |
| `payload_json` | TEXT | Action-specific data |
| `created_at` | TEXT | |
| `retry_count` | INTEGER | |

---

## 4. Firestore Security Rules

See `firestore.rules` in project root.

**Key principles:**
- Users can only write their own data
- Teachers can only write their own classes
- Students can self-enroll in classes
- Parents can read their linked children's data
- Everyone authenticated can read `classes` (for join lookup) and `leaderboard` (for rankings)

---

## 5. Data Flow Patterns

### 5.1 Student Signup

User fills form

Firebase Auth creates account → uid

Firestore: create students/{uid}

SQLite: insert into students table

Store pin_hash locally (never synced)

Update students/{uid}.lastUpdated

text

### 5.2 Parent Signup (with linked child)
Firebase Auth creates parent account → parentUid

Firestore: create parents/{parentUid}

SQLite: insert parent locally

When adding a child:

SQLite: insert child with parent_id, is_linked=1

Firestore: create students/{childUid} with parentId=parentUid

text

### 5.3 Teacher Signup
Firebase Auth creates account → teacherUid

Firestore: create teachers/{teacherUid}

SQLite: insert teacher locally

text

### 5.4 Create Class
Teacher fills form (className, gradeLevel)

Generate 6-char join code

Firestore: create classes/{classId} (flat)

Firestore: create teachers/{teacherUid}/classes/{classId} (for teacher's list)

SQLite: insert class locally

Show join code to teacher

text

### 5.5 Student Joins Class
Student enters code

Query: classes.where(joinCode == code).limit(1)

If found:
a. Firestore: create classes/{classId}/enrollments/{studentUid}
b. Firestore: update students/{uid}.classId
c. Update class studentCount (+1)
d. SQLite: update student's class_firestore_id, class_name

Confirm to user

text

### 5.6 Teacher Views Class
Query: classes/{classId}/enrollments

Get list of student UIDs

For each, optionally fetch students/{uid} for extra info

Display ranked list

text

### 5.7 Quiz Complete
Write quiz_results to SQLite

Update student total_points locally

If online:
a. Firestore: add students/{uid}/results/{resultId}
b. Update students/{uid}.totalPoints, badgeCount
c. Update leaderboard/{uid}
d. Mark synced_to_cloud=1 in SQLite

Else:
a. Mark synced_to_cloud=0
b. Add to sync_queue

text

### 5.8 Cross-Device Login
User enters credentials on new device

Firebase Auth signs in → uid

Fetch Firestore: students/parents/teachers/{uid}

Insert into local SQLite

Prompt for PIN setup (local-only)

App ready

text

---

## 6. Migration Strategy

### M3 (now)
- Add `classes/{classId}` flat collection
- Add `students/{uid}` sync on signup
- Add `last_synced_at` + `pending_sync` to SQLite
- Update Firestore Rules

### M4 (deferred)
- Add `students/{uid}/results/` and `/badges/`
- Add `sync_queue` processing
- Add offline resilience
- Move badge storage to proper table

---

## 7. Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Sept 2026 | Initial schema. M3 scope: flat classes, student sync, join flow. |