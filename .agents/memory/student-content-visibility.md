---
name: Student content visibility
description: The intended visibility rule for teacher and supervisor managed lessons and videos in the Flutter student app.
---

Lesson explanation is limited to the student's selected academic path (grade, atram, subject, term, and unit). It shows every lesson in that path and every safe explanation clip attached to the selected lesson.

Manara Cinema is independent of lessons. Each video is tied to a grade (`grade_id`), a responsible teacher (`teacher_id`), and the person who added it (`created_by`). A student sees every safe cinema video for their own grade from their teacher, whatever subject or lesson they are browsing. The server decides this in `GET /api/student/cinema` from the student's record, using `lib/cinema.ts`. Videos live in the `cinema_videos` table. If that table is missing, the server falls back to `app_kv/smartEdu_videos`. Legacy `smartEdu_videos` records stay visible until they are edited or deleted.

Student cards can be locked per class or per student (`student_card_permissions`, falling back to `app_kv/smartEdu_cardPermissions`). The student rule overrides the class rule, and anything not mentioned stays open. A locked card shows grey with a lock icon. Tapping it shows: «عذراً، ليس لديك صلاحية لهذه البطاقة، يرجى مراجعة المشرف أو المعلم».

**Why:** The user asked for cinema to be decoupled from lessons, with grade and responsible teacher required when adding a video, and for per-student and per-class card permissions.

**How to apply:**
- Keep the lesson-path filter for lessons only.
- Keep grade plus teacher identities (id, username, or name) for cinema.
- Keep URL safety checks.
- Only `/api/cinema/videos` writes `smartEdu_videos`. The dashboard sync and the bridge skip that key.