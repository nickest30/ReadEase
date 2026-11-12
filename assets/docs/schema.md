ReadEase Database Schema — Updated (v2.0)
Version: 2.0
Last Updated: October 2026
Status: Reflects current deployed implementation (SQLite v23, Firestore deployed state)
Supersedes: v1.0 (September 2026) — see Changelog at end for what changed

1. Design Principles
Principle	Description
Cloud is source of truth	Firestore holds authoritative account, class, and progress data
SQLite is a cache	Local device stores everything needed for offline-first use
PIN hashes are synced	4-digit PIN hashes are bcrypt-hashed and synced to Firestore for cross-device PIN continuity (design change from Capstone 1 — see §8.1)
Offline-first	All core features work without internet
Role-based collections	Students, parents, teachers live in separate top-level collections
Flat over nested	Queries use flat collections where possible to avoid index requirements
Validation at write-time	Firestore rules enforce type and range checks (gradeLevel 1–6, totalPoints 0–100000)
2. Firestore Structure
2.1 students/{studentUid}
One document per student (solo or linked).

Field	Type	Description
username	string	Login username (unique)
displayName	string	Name shown in UI
gradeLevel	number	1–6
totalPoints	number	Accumulated points (0–100000)
badgeCount	number	Unique (grade, difficulty) passes
pinHash	string	Bcrypt hash of 4-digit PIN (synced — see §8.1)
avatarIndex	number	1–12, references preset avatar
parentId	string?	Firebase UID of linked parent (null if solo)
classId	string?	Firestore class document ID (null if not joined)
className	string?	Denormalized class name for quick display
firebaseUid	string	Same as document ID
createdAt	timestamp	Account creation
lastUpdated	timestamp	Last sync
Read access: student themselves; their linked parent (parentId == request.auth.uid); their teacher (via class enrollment)
Write access: student themselves only
Validation: gradeLevel in 1–6; totalPoints in 0–100000

2.2 students/{studentUid}/results/{resultId}
Per-quiz result history, synced from local SQLite.

Field	Type	Description
gradeLevel	number	1–6
difficulty	string	easy / medium / hard
score	number	Correct answers
totalQuestions	number	Total questions
pointsEarned	number	Points awarded
wrongWordIds	array<number>	IDs of missed words
completedAt	timestamp	Quiz completion time
batchId	string?	Batch identifier for game association
gameType	string?	Which game/quiz type produced this attempt
2.3 students/{studentUid}/badges/{badgeId}
Earned badges (one per successful difficulty level).

Field	Type	Description
gradeLevel	number	1–6
difficulty	string	easy / medium / hard
badgeName	string	Human-readable name
pointsEarned	number	Points at badge award
earnedAt	timestamp	Award time
2.4 students/{studentUid}/mastery/{wordId}
Word mastery tracking (added M5 — Content Foundation).

Field	Type	Description
correctCount	number	Total correct answers on this word
wrongCount	number	Total wrong answers on this word
masteredAt	timestamp?	When correct count first reached 3 (mastery threshold)
lastUpdated	timestamp	Last mastery update
2.5 students/{studentUid}/encounters/{wordId}
Word discovery tracking (added M5).

Field	Type	Description
firstSeenAt	timestamp	First encounter with this word
timesSeen	number	Total encounter count
2.6 students/{studentUid}/starred/{wordId}
Starred/favorited words (added M5).

Field	Type	Description
starredAt	timestamp	Time of starring
2.7 parents/{parentUid}
One document per parent account.

Field	Type	Description
username	string	Login username (unique)
fullName	string	Full name
email	string	Email address
emailVerified	boolean	Firebase email verification status
phoneNumber	string?	E.164 format (e.g., +639123456789)
phoneVerified	boolean	Whether phone was verified (future SMS OTP)
phoneVerifiedAt	timestamp?	Time of phone verification
backupCodeHash	string?	Bcrypt hash of 6-digit backup code
backupCodeUsed	boolean	Whether backup code has been consumed
firebaseUid	string	Same as document ID
createdAt	timestamp	Account creation
lastUpdated	timestamp	Last sync
Read/write access: parent themselves only
Special rule: allow list: if request.query.limit == 1 — enables forgot-password email existence check (§8.5)

2.8 teachers/{teacherUid}
One document per teacher account.

Field	Type	Description
username	string	Login username (unique)
fullName	string	Full name
email	string	Email address
schoolName	string	School name
emailVerified	boolean	Firebase email verification status
phoneNumber	string?	E.164 format
phoneVerified	boolean	Whether phone was verified
phoneVerifiedAt	timestamp?	Time of phone verification
backupCodeHash	string?	Bcrypt hash of 6-digit backup code
backupCodeUsed	boolean	Whether backup code has been consumed
firebaseUid	string	Same as document ID
createdAt	timestamp	Account creation
lastUpdated	timestamp	Last sync
Read/write access: teacher themselves only
Special rule: allow list: if request.query.limit == 1 — enables forgot-password email existence check (§8.5)

2.9 teachers/{teacherUid}/classes/{classId}
Nested class list per teacher (for dashboard "My Classes" query).

Field	Type	Description
className	string	Class name
gradeLevel	number	1–6
joinCode	string	6-character uppercase code
studentCount	number	Enrolled student count
createdAt	timestamp	Class creation
Read/write access: owning teacher only

2.10 classes/{classId} (top-level, flat)
One document per class. Enables join-code lookup without collection-group indexes.

Field	Type	Description
teacherUid	string	Firestore UID of the owning teacher
teacherName	string	Denormalized teacher name
className	string	Class name
gradeLevel	number	1–6
joinCode	string	6-character uppercase code (unique)
studentCount	number	Enrolled student count
createdAt	timestamp	Class creation
Read access: any authenticated user (for join-code lookup)
Write access: owning teacher only

2.11 classes/{classId}/enrollments/{studentUid}
One document per enrolled student.

Field	Type	Description
studentName	string	Student display name
gradeLevel	number	Student's grade
totalPoints	number	Snapshot of points at enrollment
avatarIndex	number	Student's avatar at enrollment
enrolledAt	timestamp	Enrollment time
Read access: owning teacher + the student themselves
Write access: the student themselves (self-enrollment)

2.12 leaderboard/{studentUid}
Global ranking snapshot. Denormalized for fast sorted queries.

Field	Type	Description
displayName	string	Student name
gradeLevel	number	1–6
totalPoints	number	Accumulated points (0–100000)
badgeCount	number	Badge count
avatarIndex	number	1–12
classId	string?	For class-scoped filtering
lastUpdated	timestamp	Last sync
Read access: any authenticated user
Write access: the student themselves only (with validation rules)

2.13 link_codes/{code}
Parent-generated link codes for child linking. 24-hour TTL.

Field	Type	Description
parentUid	string	Firebase UID of the parent
parentName	string	Parent display name (shown to child)
createdAt	timestamp	Code generation time
expiresAt	timestamp	Expiry (24h after creation)
Read access: allow get (exact code match by any authenticated user); allow list: if false (prevents enumeration)
Write access: creator (parent) only

3. SQLite Structure (v23)
Local cache on the device. 28 tables total.

3.1 students
Column	Type	Notes
id	INTEGER PK	Local ID
username	TEXT UNIQUE NOT NULL	
password_hash	TEXT?	Bcrypt hash (local only)
display_name	TEXT NOT NULL	
grade_level	INTEGER NOT NULL	1–6
pin_hash	TEXT?	Bcrypt hash (local only)
recovery_code_hash	TEXT?	Bcrypt hash ⭐ NEW in v23
is_linked	INTEGER NOT NULL DEFAULT 0	0 = solo, 1 = linked
parent_id	INTEGER?	Local FK to parents.id
parent_firebase_uid	TEXT?	Firebase UID of linked parent
total_points	INTEGER NOT NULL DEFAULT 0	
recovery_email	TEXT?	Deprecated — kept for legacy data
recovery_email_verified	INTEGER DEFAULT 0	Deprecated
firebase_uid	TEXT?	Links to Firestore
class_firestore_id	TEXT?	Firestore class doc ID
class_name	TEXT?	Denormalized
last_synced_at	TEXT?	ISO timestamp
pending_sync	INTEGER NOT NULL DEFAULT 0	0 = synced, 1 = needs push
created_at	TEXT NOT NULL	ISO timestamp
avatar_index	INTEGER NOT NULL DEFAULT 1	1–12
3.2 parents
Column	Type	Notes
id	INTEGER PK	
username	TEXT UNIQUE NOT NULL	
password_hash	TEXT NOT NULL	Bcrypt
full_name	TEXT NOT NULL	
email	TEXT NOT NULL	
email_verified	INTEGER DEFAULT 0	
phone_number	TEXT?	
phone_verified	INTEGER DEFAULT 0	
phone_verified_at	TEXT?	ISO timestamp
backup_code_hash	TEXT?	Bcrypt
backup_code_used	INTEGER DEFAULT 0	
created_at	TEXT NOT NULL	
firebase_uid	TEXT?	
last_synced_at	TEXT?	
pending_sync	INTEGER DEFAULT 0	
3.3 teachers
Column	Type	Notes
id	INTEGER PK	
username	TEXT UNIQUE NOT NULL	
password_hash	TEXT NOT NULL	Bcrypt
full_name	TEXT NOT NULL	
email	TEXT NOT NULL	
school_name	TEXT NOT NULL	
email_verified	INTEGER DEFAULT 0	
phone_number	TEXT?	
phone_verified	INTEGER DEFAULT 0	
phone_verified_at	TEXT?	
backup_code_hash	TEXT?	
backup_code_used	INTEGER DEFAULT 0	
firebase_uid	TEXT?	
created_at	TEXT NOT NULL	
last_synced_at	TEXT?	
pending_sync	INTEGER DEFAULT 0	
3.4 class_groups
Local cache of joined/created classes.

Column	Type	Notes
id	INTEGER PK	
teacher_id	INTEGER NOT NULL	FK → teachers
class_name	TEXT NOT NULL	
grade_level	INTEGER NOT NULL	
join_code	TEXT UNIQUE NOT NULL	
firestore_id	TEXT?	Cloud ID
created_at	TEXT NOT NULL	
3.5 class_enrollments
Column	Type	Notes
id	INTEGER PK	
class_group_id	INTEGER NOT NULL	FK → class_groups
student_id	INTEGER NOT NULL	FK → students
enrolled_at	TEXT NOT NULL	
3.6 words
Lesson content. Seeded locally, never synced.

Column	Type	Notes
id	INTEGER PK	
text	TEXT NOT NULL	
grade_level	INTEGER NOT NULL	
difficulty	TEXT NOT NULL	easy / medium / hard
batch_id	INTEGER?	FK → batches
category	TEXT DEFAULT 'general'	
image_asset	TEXT NOT NULL	
audio_asset	TEXT NOT NULL	
lesson_cue_audio	TEXT?	Short intro audio
lesson_cue	TEXT DEFAULT ''	
definition	TEXT DEFAULT ''	
sample_sentence	TEXT DEFAULT ''	
sample_sentence_audio	TEXT?	
source	TEXT DEFAULT ''	
sensitivity_reviewed	INTEGER DEFAULT 0	
sensitivity_notes	TEXT?	
quiz_choices	TEXT NOT NULL	JSON array
correct_answer	TEXT NOT NULL	
3.7 batches
Column	Type	Notes
id	INTEGER PK	
grade_level	INTEGER NOT NULL	
difficulty	TEXT NOT NULL	
batch_index	INTEGER NOT NULL	
theme	TEXT NOT NULL	
cultural_elements_json	TEXT?	
game_type	TEXT?	e.g., memory_match, floor_is_lava
passage_id	TEXT?	FK → passages.passage_key (G4+)
3.8 quiz_questions
Column	Type	Notes
id	INTEGER PK	
batch_id	INTEGER NOT NULL	FK → batches
word_id	INTEGER NOT NULL	FK → words
question_stem	TEXT NOT NULL	
question_type	TEXT NOT NULL	
correct_answer	TEXT NOT NULL	
distractors_json	TEXT NOT NULL	JSON array
show_image	INTEGER DEFAULT 1	
order_index	INTEGER NOT NULL	
3.9 quiz_config
Column	Type	Notes
id	INTEGER PK	
grade_level	INTEGER NOT NULL	
difficulty	TEXT NOT NULL	
quiz_size	INTEGER NOT NULL	
buffer_size	INTEGER NOT NULL DEFAULT 0	
randomized	INTEGER NOT NULL DEFAULT 0	1 for Grade 3+
passing_threshold	INTEGER DEFAULT 70	
3.10 quiz_attempts (replaces deprecated quiz_results)
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	FK → students
batch_id	INTEGER NOT NULL	FK → batches
score	INTEGER NOT NULL	
total_questions	INTEGER NOT NULL	
points_earned	INTEGER NOT NULL	
wrong_word_ids_json	TEXT?	JSON array
completed_at	TEXT NOT NULL	
synced_to_cloud	INTEGER DEFAULT 0	
3.11 quiz_question_responses
Column	Type	Notes
id	INTEGER PK	
attempt_id	INTEGER NOT NULL	FK → quiz_attempts
question_id	INTEGER NOT NULL	FK → quiz_questions
selected_answer	TEXT NOT NULL	
is_correct	INTEGER NOT NULL	
response_time_ms	INTEGER?	
3.12 quiz_results (deprecated — kept for legacy data)
Retained for backward compatibility. All new attempts write to quiz_attempts instead.

3.13 badges
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	FK → students
grade_level	INTEGER NOT NULL	
difficulty	TEXT NOT NULL	
badge_name	TEXT NOT NULL	
points_earned	INTEGER NOT NULL	
earned_at	TEXT NOT NULL	
synced_to_cloud	INTEGER NOT NULL DEFAULT 0	
UNIQUE(student_id, grade_level, difficulty)		
3.14 word_encounters
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	
word_id	INTEGER NOT NULL	
first_seen_at	TEXT NOT NULL	
times_seen	INTEGER DEFAULT 1	
UNIQUE(student_id, word_id)		
3.15 word_mastery
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	
word_id	INTEGER NOT NULL	
correct_count	INTEGER DEFAULT 0	
wrong_count	INTEGER DEFAULT 0	
mastered_at	TEXT?	Set when correct_count reaches 3
UNIQUE(student_id, word_id)		
3.16 starred_words
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	
word_id	INTEGER NOT NULL	
starred_at	TEXT NOT NULL	
UNIQUE(student_id, word_id)		
3.17 batch_visits
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	
batch_id	INTEGER NOT NULL	
first_visit_at	TEXT NOT NULL	
UNIQUE(student_id, batch_id)		
3.18 lesson_progress
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	
batch_id	INTEGER NOT NULL	
current_phase	TEXT NOT NULL	
current_index	INTEGER DEFAULT 0	
last_updated	TEXT NOT NULL	
UNIQUE(student_id, batch_id)		
3.19 daily_word_log
Column	Type	Notes
id	INTEGER PK	
student_id	INTEGER NOT NULL	
word_id	INTEGER NOT NULL	
date_shown	TEXT NOT NULL	YYYY-MM-DD
shown_at	TEXT NOT NULL	
UNIQUE(student_id, date_shown)		
3.20 content_versions
Column	Type	Notes
id	INTEGER PK	
grade_level	INTEGER NOT NULL	
version	TEXT NOT NULL	
imported_at	TEXT NOT NULL	
3.21 login_attempts
Column	Type	Notes
id	INTEGER PK	
identifier	TEXT NOT NULL	username, email, or recovery:{username}
attempt_at	TEXT NOT NULL	
success	INTEGER NOT NULL DEFAULT 0	
Used for: Rate limiting across login, parent/teacher backup code, and student recovery (5 failures → 15-min lockout).

3.22 pin_attempts
Column	Type	Notes
id	INTEGER PK	
student_local_id	INTEGER NOT NULL	
attempt_at	TEXT NOT NULL	
success	INTEGER NOT NULL DEFAULT 0	
Used for: PIN lockout (5 failures → 3-min lockout).

3.23 sync_queue
Column	Type	Notes
id	INTEGER PK	
action_type	TEXT NOT NULL	e.g., quiz_submit, badge_award, profile_update
payload_json	TEXT NOT NULL	Action-specific data
firebase_uid	TEXT NOT NULL	
created_at	TEXT NOT NULL	
retry_count	INTEGER NOT NULL DEFAULT 0	
last_attempt_at	TEXT?	
last_error	TEXT?	
3.24 passages (G4+)
Column	Type	Notes
id	INTEGER PK	
passage_key	TEXT NOT NULL UNIQUE	
grade_level	INTEGER NOT NULL	
difficulty	TEXT NOT NULL	
title	TEXT NOT NULL	
illustration	TEXT NOT NULL	
word_count	INTEGER NOT NULL	
tappable_words_json	TEXT?	For G5/G6 (deferred to G6)
3.25 passage_sentences
Column	Type	Notes
id	INTEGER PK	
passage_id	INTEGER NOT NULL	FK → passages
sentence_index	INTEGER NOT NULL	
text	TEXT NOT NULL	
audio	TEXT NOT NULL	
3.26 passage_questions
Column	Type	Notes
id	INTEGER PK	
passage_id	INTEGER NOT NULL	FK → passages
stem	TEXT NOT NULL	
question_type	TEXT NOT NULL	
correct_answer	TEXT NOT NULL	
distractors_json	TEXT NOT NULL	
show_image	INTEGER DEFAULT 0	
order_index	INTEGER NOT NULL	
stem_audio	TEXT?	
3.27 lesson_intros
Column	Type	Notes
id	INTEGER PK	
grade	INTEGER NOT NULL	
difficulty	TEXT NOT NULL	
header	TEXT NOT NULL	
body	TEXT NOT NULL	
button_label	TEXT NOT NULL	
pose_asset	TEXT NOT NULL	Yse mascot pose
audio_asset	TEXT NOT NULL	
UNIQUE(grade, difficulty)		
3.28 game_intros
Column	Type	Notes
id	INTEGER PK	
game_type	TEXT NOT NULL UNIQUE	e.g., memory_match, drag_drop
header	TEXT NOT NULL	
body	TEXT NOT NULL	
button_label	TEXT NOT NULL	
pose_asset	TEXT NOT NULL	
audio_asset	TEXT NOT NULL	
4. Firestore Security Rules — Summary
Full rules file is maintained separately (firestore.rules).

Key principles:

Rule	Applies To
Users write only their own data	All collections
Students read only their own subcollections	students/{uid}/*
Parents read linked child subcollections	students/{childUid}/* if parentId == request.auth.uid
Teachers read enrolled students' subcollections	students/{studentUid}/* if enrolled in teacher's class
Any authenticated user reads classes (for join lookup)	classes/{classId}
Any authenticated user reads leaderboard	leaderboard/{uid}
Parent/Teacher list restricted to limit == 1	Enables forgot-password check without enumeration
link_codes — no list, only get by exact code	Prevents code enumeration
Write validation on totalPoints (0–100000)	students, leaderboard
Write validation on gradeLevel (1–6)	students, leaderboard
Helper functions used in rules:

isParentOf(studentUid) — checks students/{studentUid}.parentId == request.auth.uid

isTeacherOf(studentUid) — checks enrollment existence + teacher ownership of that class

5. Data Flow Patterns
5.1 Student Signup (solo)
text
User fills form → Terms modal → Firebase Auth creates account (uid)
  → Firestore: create students/{uid}
  → SQLite: insert into students
  → Generate 8-char recovery code → bcrypt hash → SQLite update
  → [MANDATORY] Show recovery code gate (must save + hold 5s)
  → Prompt for PIN setup (local + cloud sync)
  → Home
5.2 Parent Signup (with linked children)
text
User fills form → Terms modal → Firebase Auth creates parent account (parentUid)
  → Firestore: create parents/{parentUid}
  → SQLite: insert parent
  → [MANDATORY] Email verification gate
  → Generate 6-digit backup code → hash + store
  → Dashboard
Adding a child (from Parent Dashboard):

text
Parent fills child form → SQLite: insert child with parent_id, is_linked=1
  → Firestore: create students/{childUid} with parentId=parentUid
  → Set child's initial PIN
5.3 Teacher Signup
text
User fills form → Terms modal → Firebase Auth creates account (teacherUid)
  → Firestore: create teachers/{teacherUid}
  → SQLite: insert teacher
  → [MANDATORY] Email verification gate
  → Generate 6-digit backup code → hash + store
  → Dashboard
5.4 Create Class
text
Teacher fills form (className, gradeLevel)
  → Generate 6-char join code
  → Firestore: create classes/{classId} (flat)
  → Firestore: create teachers/{teacherUid}/classes/{classId} (for teacher's list)
  → SQLite: insert class locally
  → Show join code to teacher
5.5 Student Joins Class
text
Student enters code
  → Query: classes.where(joinCode == code).limit(1)
  → If found:
      a. Firestore: create classes/{classId}/enrollments/{studentUid}
      b. Firestore: update students/{uid}.classId
      c. Update class studentCount (+1)
      d. SQLite: update student's class_firestore_id, class_name
  → Confirm to user
5.6 Teacher Views Class
text
Teacher opens Class Overview
  → Query: classes/{classId}/enrollments
  → Get list of student UIDs
  → For each, fetch students/{uid} for extra info
  → Display ranked list
5.7 Quiz Complete
text
User finishes quiz/game
  → Compute pointsDelta (best-score only)
  → SQLite: insert quiz_attempts
  → SQLite: update student total_points
  → SQLite: update word_mastery, word_encounters
  → SQLite: award badge if passing
  → [Defensive] Wrap Firestore sync in try/catch — always navigate to results
  → If online:
      a. Firestore: add students/{uid}/results/{resultId}
      b. Firestore: update students/{uid}.totalPoints, badgeCount
      c. Firestore: update leaderboard/{uid}
      d. Firestore: sync badges, mastery, encounters, starred
      e. SQLite: mark synced_to_cloud=1
  → Else:
      a. Mark synced_to_cloud=0
      b. Add to sync_queue
  → Navigate to Results screen (always)
5.8 Cross-Device Login (existing account)
text
User enters credentials on new device
  → Firebase Auth signs in → uid
  → Fetch Firestore: students/parents/teachers/{uid}
  → Insert into local SQLite
  → PIN hash is already in the cloud doc — restore locally
  → App ready (no PIN re-setup needed)
5.9 Student Password Recovery (recovery code)
text
Student taps "Forgot your password?"
  → Step 1: Enter username
      → SQLite: read students WHERE username
      → Validate: exists, not linked, has recovery_code_hash, has firebase_uid
  → Step 2: Enter recovery code
      → Normalize input (uppercase, strip non-alphanumeric)
      → BCrypt.checkpw(normalized, storedHash)
      → On fail: record in login_attempts; check rate limit (5/15min)
      → On success: clear login_attempts
  → Step 3: Enter new password
      → flutter_secure_storage: read old credentials
      → Firebase Auth: signIn with old credentials
      → Firebase Auth: updatePassword(new)
      → flutter_secure_storage: save new credentials
      → SQLite: update students.password_hash
      → Firebase Auth: signOut
  → Redirect to /student-signin
5.10 Password Reset (parent/teacher)
text
User taps "Forgot password?"
  → Enter email
  → Firestore: query parents or teachers WHERE email == input, limit(1)
  → If not found: show "No account found" error
  → If found: Firebase Auth: sendPasswordResetEmail
  → Show confirmation modal
  → User clicks email link → Firebase updates cloud password
  → User returns to app, logs in with new password
  → On successful login: local bcrypt hash auto-updates (self-healing)
6. SQLite Version History
Version	Change	Reason
v2	Added quiz_results.wrong_word_ids	Track missed words
v3	Added students.class_firestore_id, class_name	Class enrollment
v4	Added students.last_synced_at, pending_sync	Offline sync tracking
v5	Idempotent quiz_results.wrong_word_ids	Migration safety
v6	Added class_groups.firestore_id	Cloud class tracking
v7	Added quiz_results.synced_to_cloud	Sync flag
v8	Created badges table	Badge system
v9	Created words extensions, batches, quiz_questions, quiz_config, passages, passage_sentences, passage_words, word_encounters, word_mastery, starred_words, batch_visits, lesson_progress, quiz_attempts, quiz_question_responses, daily_word_log, content_versions, lesson_intros, game_intros, opening_frames, story_frames	Full content + progress pipeline
v10	Added words.lesson_cue_audio	Audio cues
v11	Added parent/teacher verification + backup code fields; created login_attempts, pin_attempts, sync_queue	M3.5 auth additions
v12	Added batches.game_type	Game association
v13	Ensured lesson_intros, game_intros exist	Idempotent migration
v14	Added words.sample_sentence_audio	Sentence audio
v15	Created passages (new schema), passage_sentences, passage_questions	G4 passages
v16	Dropped old passages schema, recreated correctly	Schema fix
v17	Ensured lesson_intros + game_intros on upgrade path	Migration fix
v18	Ensured passages trio exists on legacy installs	Migration fix
v19	Added passage_questions.stem_audio	G4+ comprehension audio
v20	Added passages.tappable_words_json	G5 tappable words (deferred to G6)
v21	Dropped opening_frames and story_frames	Deprecated
v22	Added students.avatar_index	Avatar system
v23 ⭐	Added students.recovery_code_hash	Student Recovery Code System
7. What's NOT In This Schema
The following were part of earlier design drafts and are intentionally excluded from the current schema:

Removed/Excluded	Reason
users/{uid} Firestore collection	Superseded by role-specific students/, parents/, teachers/ — see §8.6
opening_frames SQLite table	Replaced by lesson_intros
story_frames SQLite table	Replaced by lesson flow redesign
passage_words SQLite table	Removed (tappable words deferred to G6, clashed with passage audio)
MCQ quiz as primary assessment	Replaced by 8 mini-games; quiz_results retained only for legacy MCQ data
Hangman game	Replaced by "Floor is Lava" (child-safety)
Teacher difficulty override	Removed — teachers focus on analytics/monitoring
Per-child accessibility settings	Removed — device-wide settings
recovery_email / recovery_email_verified on students	Deprecated — replaced by recovery_code_hash (kept for legacy data)
8. Design Decisions & Rationale
8.1 PIN Hash Sync (Change from Capstone 1)
Capstone 1 design: "PIN stays local — 4-digit PIN hashes are NEVER synced to cloud (security)."

Capstone 2 implementation: PIN hashes are synced (as bcrypt hashes, never plaintext) to enable PIN continuity across devices.

Rationale: When a student logs in on a new device via username and password, the new device needs a working PIN. Without the cloud-stored pinHash, the new device would force a PIN re-setup every time — a poor experience for young learners. Syncing the hash preserves the security property (raw PIN never stored or transmitted) while enabling cross-device continuity.

Documented limitation: Bcrypt hashes are computationally expensive to crack (cost factor 10 ≈ 100ms per attempt), but a leak of the PIN hash could theoretically be attacked offline. This is mitigated by PIN lockout (5 attempts → 3-minute lockout) which applies at the app level regardless of where the hash is stored.

8.2 Avatar Index (New)
Added: students/{uid}.avatarIndex (1–12) and leaderboard/{uid}.avatarIndex.

Rationale: The avatar system was added in M11 (Pronunciation + Avatar) to increase learner engagement. 12 preset avatars (3 mascots + 9 animals) provide personalization without moderation risk. Synced to leaderboard and enrollment snapshots so parent/teacher views see the same avatar.

8.3 Backup Code for Parent/Teacher (New)
Added: parents/{uid}.backupCodeHash, backupCodeUsed (and same for teachers).

Rationale: Provides a second-factor recovery path if a user loses access to their phone (which is used for SMS OTP). Backup codes are 6-digit numeric (easier for the user to type from a saved note) and bcrypt-hashed before storage.

8.4 Email Verification Gate (Change from Capstone 1)
Capstone 1 design: Email verification was a soft banner (non-blocking).

Capstone 2 implementation: Mandatory gate for parent/teacher signup. Cannot access dashboard until verified.

Rationale: Ensures every active parent/teacher account has a verified email, which is required for password reset and future notification features.

8.5 Forgot Password Email Existence Check (New)
Added: Before sending a password reset email, validate the email exists in the corresponding collection (parents or teachers) with a limit(1) query.

Rationale: Without validation, users would type in a wrong email, see "sent" confirmation, but never receive anything — leading to confusion and support requests. With validation, they see "No account found" immediately and can correct the email.

Trade-off: This exposes email enumeration — an attacker can probe whether an email is registered. Documented as a limitation. Production recommendation: Cloud Function with hashed email_lookup collection.

Implementation detail: Firestore rules allow list: if request.query.limit == 1 on parents/teachers to enable this query without full collection enumeration.

8.6 No users/{uid} Collection
Earlier draft: Planned a unified users/{uid} collection for cross-role lookups.

Capstone 2 implementation: Never implemented. Role-specific collections (students/, parents/, teachers/) serve all lookups directly. Cross-role identification uses Firebase Auth's uid property directly.

Rationale: A unified collection would duplicate data and create consistency risks. Since roles don't cross-reference each other except through explicit links (e.g., parentId on students), role-specific collections are simpler and faster.

8.7 Recovery Code for Solo Students (New)
Added: 8-character alphanumeric recovery code (format ABCD-EFGH), bcrypt-hashed, shown once at signup, used for password recovery.

Rationale: Solo students use synthetic emails (username@readease.app) which cannot receive Firebase password reset emails. Without a recovery code, a solo student who forgets their password has no recovery path. The recovery code provides a documented, verifiable mechanism that works on the same device (via flutter_secure_storage credentials).

Documented limitation: Recovery only works on the device where the student signed up. If the device is lost or cleared, recovery is unavailable. Linked students are unaffected (parent can reset via Parent Dashboard).

Why 8 chars instead of 6 (like parent/teacher backup codes): A recovery code protects a whole account and may be exposed (students share usernames, are more likely to write on paper). 8 chars from a 31-char alphabet = ~852 billion combinations, which is infeasible to brute-force even without rate limiting.

8.8 MCQ → 8 Mini-Games (Change from Capstone 1)
Capstone 1 design: MCQ quiz after every lesson.

Capstone 2 implementation: 8 mini-games (Memory Match, Bubble Pop, Drag & Drop, Word Scramble, Sentence Builder, Floor is Lava, Word Hunt, Category Sort), each assigned to a specific (grade, difficulty) tier.

Rationale: Literature (AlZuhair & Alkhuzaim 2022; Shofi & Jannah 2022) shows gamified apps produce measurable reading gains. 8 games give variety and target different reading skills. Games are more defensible in ISO "Usability" evaluation.

Retained: quiz_results table exists for legacy MCQ data from before the game layer was built. New attempts use quiz_attempts + quiz_question_responses.

8.9 Content Organised by Grade + Difficulty + Batch
Structure: Each grade has 3 difficulty tiers (Easy, Medium, Hard). Each tier contains one or more batches (themed word groups). Batches reference a game_type and optionally a passage_id (G4+).

Rationale: Aligns with DepEd curriculum (grade level as starting point) and adds gradient within grade (difficulty) to keep learners engaged. Batches provide thematic cohesion (e.g., Grade 2 Easy: "Market Day").

Grade content: G1: 23 words, G2: 36, G3: 39, G4: 39 (+3 passages), G5: 42 (+3 passages), G6: 42 (+3 passages). Total: 221+ words, 9 passages.

9. Changelog
Version	Date	Changes
1.0	Sept 2026	Initial schema. M3 scope: flat classes, student sync, join flow.
2.0	Oct 2026	Full rewrite to reflect deployed implementation. Added: students/{uid}.pinHash, .avatarIndex; full subcollections (mastery, encounters, starred); parent/teacher verification fields; link_codes; 28 SQLite tables (was 9); recovery_code_hash; SQLite version history v2–v23; design decisions section; "What's NOT in schema" section. Removed: users/{uid} (never implemented). Clarified: PIN hash sync rationale (§8.1); MCQ → games (§8.8).
10. How to Use This Document
For ERD: Sections 2.1–2.13 (Firestore) and 3.1–3.28 (SQLite) are the entity definitions. Relationships: students.parentId → parents, class_groups.teacher_id → teachers, class_enrollments.student_id → students, class_enrollments.class_group_id → class_groups, all subcollections belong to parent students/{uid}.

For CFD/DFD: Section 5 (Data Flow Patterns) shows process-level flow. Data stores referenced as D1 (SQLite), D2 (Secure Storage), D3 (Firebase Auth), D4 (Firestore), D5 (Bundled Assets).

For manuscript Chapter 3: Section 8 (Design Decisions) has the rationale for every deviation from Capstone 1.

For Limitations section: Section 8.5 (email enumeration), §8.1 (PIN hash sync), §8.7 (recovery code device-scoping), plus the excluded items in §7.
