/**
 * يُلصَق في وحدة تحكّم المتصفّح (Console) وأنت داخلٌ على المنصّة.
 *
 * ── لماذا في المتصفّح لا في الطرفية ──
 * قاعدة البيانات سليمة — وقد تحقّقنا منها بالجرد. والشاشة تقرأ نسخة
 * المتصفّح لا قاعدةَ البيانات. فبين الاثنين طبقةٌ واحدة يمكن أن تفشل،
 * وهي التحميل الأول؛ ولا يبلغها سكربتٌ يعمل في الطرفية. هذا يعمل حيث
 * العطب: يسأل الخادم بجلستك أنت، ويقارن ما يجيب به بما في جهازك،
 * ويقول أيّهما الناقص، ثم ينسخ نسخة الخادم إلى الجهاز ويُحدّث الصفحة.
 *
 * لا يكتب في قاعدة البيانات شيئاً: قراءةٌ من الخادم وكتابةٌ في جهازك.
 *
 * الاستعمال:
 *   ١. ادخل إلى المنصّة بحساب المشرف (أو المعلّم).
 *   ٢. افتح أدوات المطوّر ← Console.
 *   ٣. الصق محتوى هذا الملف كلّه واضغط Enter.
 *   ٤. اقرأ التقرير. إن قال «الخادم عنده والجهاز لا» فسيُصلح ويُحدّث.
 */

(async () => {
  const HIERARCHY_KEY = "smartEdu_hierarchicalConfigs";
  const GRADES_KEY = "smartEdu_grades";
  const LESSONS_KEY = "smartEdu_lessonConfigs";

  const norm = (v) =>
    String(v ?? "")
      .trim()
      .toLowerCase()
      .replace(/[ً-ْٰـ]/g, "")
      .replace(/[أإآٱ]/g, "ا")
      .replace(/ى/g, "ي")
      .replace(/ة/g, "ه")
      .replace(/\s+/g, " ");

  const ownerOf = (c) => norm(c?.teacher_id ?? c?.teacherId ?? c?.createdBy) || "admin";

  const asArray = (value) => {
    if (Array.isArray(value)) return value;
    if (typeof value === "string" && value.trim()) {
      try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }
    return [];
  };

  /** سطرٌ لكل مادة: مالكها وصفّها وعدد فصولها ووحداتها ودروسها. */
  const summarise = (configs) => {
    const rows = [];
    for (const config of configs) {
      for (const subject of config?.subjects ?? []) {
        const terms = subject?.terms ?? [];
        rows.push({
          "المالك": ownerOf(config),
          "الصف": String(config?.grade ?? ""),
          "المادة": String(subject?.subject ?? ""),
          "فصول": terms.length,
          "وحدات": terms.reduce((s, t) => s + (t?.units?.length ?? 0), 0),
          "دروس": terms.reduce(
            (s, t) => s + Object.values(t?.lessons ?? {}).flat().length,
            0,
          ),
        });
      }
    }
    return rows;
  };

  console.log("%c فحص الشجرة الأكاديمية ", "background:#1e40af;color:#fff;font-size:14px");

  // ── ١. ما في هذا الجهاز ─────────────────────────────────────────────
  const local = asArray(localStorage.getItem(HIERARCHY_KEY));
  console.log(`نسخة الجهاز: ${local.length} مدخلاً`);
  if (local.length) console.table(summarise(local));

  const localLessons = asArray(localStorage.getItem(LESSONS_KEY));
  console.log(`دروس الجهاز: ${localLessons.length} سجلاً`);

  // ── ٢. ما يقوله الخادم بجلستك ───────────────────────────────────────
  let server = [];
  let serverGrades = [];
  try {
    const response = await fetch("/api/supabase/app_kv", { credentials: "include" });
    if (!response.ok) {
      console.error(
        `%c الخادم ردّ ${response.status}. `,
        "background:#b91c1c;color:#fff",
        response.status === 401
          ? "لا جلسة مفتوحة — سجّل الدخول ثم أعد اللصق."
          : await response.text(),
      );
      return;
    }
    const rows = await response.json();
    const byKey = new Map((Array.isArray(rows) ? rows : []).map((r) => [r.key, r.value]));
    server = asArray(byKey.get(HIERARCHY_KEY));
    serverGrades = asArray(byKey.get(GRADES_KEY));
    console.log(`نسخة الخادم: ${server.length} مدخلاً`);
    if (server.length) console.table(summarise(server));
    if (!byKey.has(HIERARCHY_KEY)) {
      console.warn("⚠️ الخادم لم يُرسل مفتاح الشجرة إطلاقاً — الجسر أقدم من الإصلاح.");
    }
  } catch (error) {
    console.error("تعذّر سؤال الخادم:", error);
    return;
  }

  // ── ٣. الحكم ────────────────────────────────────────────────────────
  const count = (list) =>
    summarise(list).reduce((sum, row) => sum + row["دروس"], 0);
  const localLessonsInTree = count(local);
  const serverLessonsInTree = count(server);
  console.log(
    `دروسٌ في شجرة الجهاز: ${localLessonsInTree}   —   في شجرة الخادم: ${serverLessonsInTree}`,
  );

  if (!server.length) {
    console.error(
      "%c الشجرة ناقصة في قاعدة البيانات نفسها. ",
      "background:#b91c1c;color:#fff",
      "شغّل scripts/rebuild-academic-tree.mjs.",
    );
    return;
  }

  if (serverLessonsInTree <= localLessonsInTree && local.length >= server.length) {
    console.log(
      "%c الجهاز ليس أنقص من الخادم. ",
      "background:#065f46;color:#fff",
      "فإن كانت الشاشة فارغة فهي لا تقرأ ما في الجهاز — لا نقصَ في البيانات.",
    );
    return;
  }

  // ── ٤. الإصلاح: نسخة الخادم إلى الجهاز ──────────────────────────────
  console.log("%c يُنسخ ما عند الخادم إلى هذا الجهاز… ", "background:#92400e;color:#fff");
  localStorage.setItem(HIERARCHY_KEY, JSON.stringify(server));
  if (serverGrades.length) localStorage.setItem(GRADES_KEY, JSON.stringify(serverGrades));
  else {
    const grades = Array.from(
      new Map(server.map((c) => [norm(c?.grade), String(c?.grade ?? "")])).values(),
    ).filter(Boolean);
    localStorage.setItem(GRADES_KEY, JSON.stringify(grades));
  }
  console.log("تمّ. تُحدَّث الصفحة بعد ثانية.");
  setTimeout(() => location.reload(), 1000);
})();
