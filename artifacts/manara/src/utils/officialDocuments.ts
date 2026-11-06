/**
 * المستنداتُ الرسمية: الشهادة وتقريرُ أداء الطالب.
 *
 * كان لكلّ شاشةٍ قالبُها: شهادةٌ بخلفية بنفسجية متدرّجة ورموزٍ تعبيرية بحجم
 * ٢٠٠ بكسل، وتقريرٌ بظلالٍ وزوايا مستديرة تُطبع رمادية. والمطبوعُ يُعلَّق
 * ويُحفظ في ملفّ الطالب، فيجب أن يبدو مستنداً رسمياً لا صفحةَ ويب.
 *
 * فصار قالبٌ واحد: مقاسُ A4 محسوب بالمليمتر، وإطارٌ كحليّ وذهبيّ، وشعارُ
 * المنصّة، وتوقيعات، ورقمُ شهادة وتاريخان (هجري وميلادي). والمعاينةُ على
 * الشاشة تعرض المستندَ نفسه في إطار، فما يُرى هو ما يُطبع.
 */

import type { CertificateRecord, QuizResult, StudentInfo } from '../types';
import { html, SafeHtml } from './printHtml';
import { getQuizResultPercentage } from './quizScoring';

export type CertificateType = CertificateRecord['type'];

export const CERTIFICATE_TYPES: Record<CertificateType, { title: string; short: string }> = {
  excellence: { title: 'شهادة التفوّق', short: 'تفوّق' },
  appreciation: { title: 'شهادة الشكر والتقدير', short: 'شكر وتقدير' },
  participation: { title: 'شهادة المشاركة الفعّالة', short: 'مشاركة' },
};

const PLATFORM = 'منصة منارة المعرفة التعليمية';

const logoUrl = () =>
  typeof window === 'undefined' ? '/manara-logo-emblem.png' : new URL('/manara-logo-emblem.png', window.location.origin).href;

const hijri = (value: string | Date) =>
  new Date(value).toLocaleDateString('ar-SA-u-ca-islamic-umalqura-nu-latn', { day: 'numeric', month: 'long', year: 'numeric' });

const gregorian = (value: string | Date) =>
  new Date(value).toLocaleDateString('ar-SA-u-ca-gregory-nu-latn', { day: 'numeric', month: 'long', year: 'numeric' });

/** رقمٌ ثابت لكل شهادة من معرّفها: يُكتب عليها ويُطابَق به عند السؤال. */
export const certificateNumber = (cert: Pick<CertificateRecord, 'id' | 'date'>): string => {
  let hash = 0;
  for (const ch of `${cert.id}`) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  const year = new Date(cert.date).getFullYear() || new Date().getFullYear();
  return `MNR-${year}-${String(hash % 1000000).padStart(6, '0')}`;
};

/**
 * مَن يوقّع الشهادة: من أصدرها فعلاً — المعلم أو المشرف المسجّل حينها
 * (`issuedBy`). والشهاداتُ الأقدم من الحقل يوقّعها معلّمُها كما كانت.
 */
export const issuerOf = (cert: CertificateRecord): { name: string; role: string } =>
  cert.issuedBy
    ? { name: cert.issuedBy, role: cert.issuedByRole === 'admin' ? 'المشرف' : 'معلّم/ة المادة' }
    : { name: cert.teacherName || '', role: 'معلّم/ة المادة' };

/**
 * نصُّ الشهادة — الصيغُ المعتمدة من إدارة المدرسة بحروفها. لا تذكر المنصّة:
 * المنصّةُ تعتمد الشهادة في أسفلها، والنصُّ تهنئةٌ للطالب.
 * والنسبةُ في شهادة التفوّق وحدها.
 */
const certificateMessage = (cert: CertificateRecord): SafeHtml => {
  const student = html`<b class="student">${cert.studentName}</b>`;
  // ‏«بالصف [الصف]»: أسماءُ الصفوف تبدأ بكلمة «الصف» فلا تتكرّر.
  const grade = html`<b>${(cert.grade || '—').replace(/^الصف\s+/, '')}</b>`;
  const subject = html`<b>${cert.subject}</b>`;
  switch (cert.type) {
    case 'excellence': {
      const hasAverage = typeof cert.average === 'number' && Number.isFinite(cert.average);
      return html`يسعدنا أن نتقدم بخالص الشكر والتقدير للطالب/ـة ${student} بالصف ${grade}، وذلك نظير تفوقه المتميز والملحوظ في مادة ${subject}${hasAverage ? html`، حيث حقق نسبة <b>${Math.round(cert.average)}%</b> في اختبار المادة` : ''}، متمنين له دوام التقدم والنجاح.`;
    }
    case 'appreciation':
      return html`تتقدم إدارة المدرسة بخالص الشكر والتقدير للطالب/ـة ${student} بالصف ${grade}، وذلك تقديراً لجهوده المبذولة وانضباطه المستمر في مادة ${subject}، مع تمنياتنا له بمزيد من التميز.`;
    default:
      return html`تُمنح هذه الشهادة للطالب/ـة ${student} بالصف ${grade}، تقديراً لمشاركته الفعالة وتفاعله الإيجابي في أنشطة مادة ${subject}، مع خالص الشكر والتقدير.`;
  }
};

const FONT = html`@import url('https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&family=Amiri:wght@700&display=swap');`;

/** الشهادة: صفحةُ A4 أفقية بإطارٍ مزدوج، جاهزةٌ للطباعة بلا هوامش متصفّح. */
export function certificateDocument(cert: CertificateRecord): SafeHtml {
  const type = CERTIFICATE_TYPES[cert.type] ?? CERTIFICATE_TYPES.participation;
  const number = certificateNumber(cert);
  return html`<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<title>${type.title} — ${cert.studentName}</title>
<style>
${FONT}
@page { size: A4 landscape; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: #e9edf2; }
body { font-family: 'Tajawal', sans-serif; color: #13243a; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.sheet { position: relative; width: 297mm; height: 210mm; margin: 0 auto; padding: 9mm; background: #fff; overflow: hidden; }
.frame { position: absolute; inset: 9mm; border: 1.6mm solid #15335c; }
.frame-inner { position: absolute; inset: 12.5mm; border: 0.4mm solid #b08d3c; }
.corner { position: absolute; width: 16mm; height: 16mm; border-color: #b08d3c; border-style: solid; }
.c1 { top: 15mm; right: 15mm; border-width: 0.9mm 0.9mm 0 0; }
.c2 { top: 15mm; left: 15mm; border-width: 0.9mm 0 0 0.9mm; }
.c3 { bottom: 15mm; right: 15mm; border-width: 0 0.9mm 0.9mm 0; }
.c4 { bottom: 15mm; left: 15mm; border-width: 0 0 0.9mm 0.9mm; }
.watermark { position: absolute; top: 50%; left: 50%; width: 105mm; height: 105mm; transform: translate(-50%, -46%); opacity: 0.05; object-fit: contain; }
.content { position: relative; height: 100%; padding: 13mm 26mm 11mm; display: flex; flex-direction: column; align-items: center; text-align: center; }
.brand { display: flex; align-items: center; gap: 4mm; }
.brand img { width: 19mm; height: 19mm; object-fit: contain; }
.brand div { text-align: right; }
.brand strong { display: block; font-size: 14pt; font-weight: 800; color: #15335c; }
.brand span { display: block; font-size: 9.5pt; font-weight: 700; color: #6b7a90; }
.title { margin-top: 8mm; font-family: 'Amiri', 'Tajawal', serif; font-size: 34pt; font-weight: 700; color: #15335c; line-height: 1.25; }
.rule { display: flex; align-items: center; gap: 3mm; margin: 2.5mm 0 5mm; color: #b08d3c; font-size: 9pt; }
.rule::before, .rule::after { content: ''; width: 34mm; height: 0.35mm; background: #b08d3c; }
.message { max-width: 220mm; margin-top: auto; font-size: 16pt; font-weight: 500; line-height: 2.15; color: #334155; }
.message b { font-weight: 800; color: #15335c; }
.message b.student { padding: 0 1.5mm; font-size: 21pt; font-weight: 900; color: #13243a; border-bottom: 0.4mm solid #d9c79a; }
.note { margin-top: 2mm; max-width: 190mm; font-size: 12pt; font-weight: 700; color: #8a6a24; }
.footer { margin-top: auto; width: 100%; display: grid; grid-template-columns: 1fr auto 1fr; align-items: end; gap: 10mm; }
.sign { text-align: center; }
.sign small { display: block; margin-bottom: 1mm; font-size: 8.5pt; font-weight: 700; color: #8a6a24; letter-spacing: 0.3mm; }
.sign strong { display: block; min-height: 6mm; font-size: 12pt; font-weight: 800; color: #13243a; }
.sign .line { width: 58mm; margin: 2mm auto 1.5mm; border-top: 0.35mm solid #334155; }
.sign span { font-size: 10pt; font-weight: 700; color: #6b7a90; }
.seal { width: 30mm; height: 30mm; border-radius: 50%; border: 0.9mm solid #b08d3c; display: flex; align-items: center; justify-content: center; }
.seal div { width: 24mm; height: 24mm; border-radius: 50%; border: 0.3mm solid #b08d3c; display: flex; flex-direction: column; align-items: center; justify-content: center; color: #8a6a24; }
.seal img { width: 11mm; height: 11mm; object-fit: contain; }
.seal span { font-size: 6.5pt; font-weight: 800; }
.meta { position: absolute; bottom: 4.2mm; left: 0; right: 0; display: flex; justify-content: space-between; padding: 0 30mm; font-size: 8.5pt; font-weight: 700; color: #6b7a90; }
@media screen { body { padding: 8mm 0; } .sheet { box-shadow: 0 2mm 8mm rgb(15 31 53 / 0.18); } }
@media print { html, body { background: #fff; } .sheet { margin: 0; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="frame"></div>
  <div class="frame-inner"></div>
  <div class="corner c1"></div><div class="corner c2"></div><div class="corner c3"></div><div class="corner c4"></div>
  <img class="watermark" src="${logoUrl()}" alt="">
  <div class="content">
    <div class="brand">
      <img src="${logoUrl()}" alt="">
      <div><strong>${PLATFORM}</strong><span>تعليمٌ ذكي، معرفة، ومستقبلٌ مشرق</span></div>
    </div>
    <h1 class="title">${type.title}</h1>
    <div class="rule">◆</div>
    <p class="message">${certificateMessage(cert)}</p>
    ${cert.note ? html`<p class="note">${cert.note}</p>` : ''}
    <div class="footer">
      <div class="sign"><small>المُصدِر</small><strong>${issuerOf(cert).name}</strong><div class="line"></div><span>${issuerOf(cert).role}</span></div>
      <div class="seal"><div><img src="${logoUrl()}" alt=""><span>منارة المعرفة</span></div></div>
      <div class="sign"><small>الاعتماد</small><strong>إدارة منصة منارة المعرفة</strong><div class="line"></div><span>الختم والاعتماد</span></div>
    </div>
  </div>
  <div class="meta"><span>رقم الشهادة: ${number}</span><span>تاريخ الإصدار: ${hijri(cert.date)} — ${gregorian(cert.date)} م</span></div>
</div>
</body>
</html>`;
}

/* ───────────────────────── تقرير أداء الطالب ───────────────────────── */

export interface StudentReportInput {
  student: StudentInfo;
  results: QuizResult[];
  certificates: CertificateRecord[];
  parentName?: string;
  teacherName?: string;
  /** مؤشّرات التقدّم (`getStudentProgressSummary`). */
  progress: {
    level: number;
    xp: number;
    gems: number;
    streak: number;
    totalLessons: number;
    totalGames: number;
    averageScore: number;
    loginCount: number | null;
    lastLoginAt?: string;
  };
  /** يُعرض كما هو تحت «ملاحظات المعلم»؛ وإلا تُترك أسطرٌ فارغة للكتابة. */
  notes?: string;
}

const grade = (percentage: number) =>
  percentage >= 90 ? 'ممتاز' : percentage >= 75 ? 'جيد جداً' : percentage >= 60 ? 'جيد' : 'يحتاج متابعة';

const scoreColor = (percentage: number) =>
  percentage >= 90 ? '#15803d' : percentage >= 75 ? '#1f4e8c' : percentage >= 60 ? '#b45309' : '#b91c1c';

/** تقريرُ أداءٍ شامل على صفحات A4 عمودية: الملخّص، والمواد، والاختبارات، والشهادات. */
export function studentReportDocument(input: StudentReportInput): SafeHtml {
  const { student, progress } = input;
  const results = [...input.results]
    .map((result) => ({ ...result, percentage: getQuizResultPercentage(result) }))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  const average = results.length
    ? Math.round(results.reduce((sum, result) => sum + result.percentage, 0) / results.length)
    : progress.averageScore || 0;

  const bySubject = new Map<string, number[]>();
  results.forEach((result) => {
    const key = result.subject || 'غير محدّدة';
    bySubject.set(key, [...(bySubject.get(key) || []), result.percentage]);
  });
  const subjects = Array.from(bySubject.entries()).map(([subject, scores]) => ({
    subject,
    count: scores.length,
    average: Math.round(scores.reduce((sum, value) => sum + value, 0) / scores.length),
    best: Math.round(Math.max(...scores)),
    worst: Math.round(Math.min(...scores)),
  }));

  const kpis: [string, string][] = [
    ['المعدّل العام', results.length ? `${average}%` : '—'],
    ['الاختبارات المنجزة', String(results.length)],
    ['المستوى', String(progress.level || 0)],
    ['النقاط (XP)', String(progress.xp || 0)],
    ['الجواهر', String(progress.gems || 0)],
    ['مرّات الدخول', progress.loginCount === null ? '—' : String(progress.loginCount)],
    ['الدروس المكتملة', String(progress.totalLessons || 0)],
    ['أيام متتالية', String(progress.streak || 0)],
  ];

  const today = new Date();
  return html`<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<title>تقرير أداء — ${student.name}</title>
<style>
${FONT}
@page { size: A4 portrait; margin: 14mm 13mm 16mm; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Tajawal', sans-serif; color: #13243a; font-size: 10.5pt; line-height: 1.6; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
@media screen { body { max-width: 210mm; margin: 0 auto; padding: 12mm; background: #fff; } }
header { display: flex; align-items: center; gap: 4mm; padding-bottom: 4mm; border-bottom: 0.8mm solid #15335c; }
header img { width: 16mm; height: 16mm; object-fit: contain; }
header .who { flex: 1; }
header strong { display: block; font-size: 13pt; font-weight: 800; color: #15335c; }
header span { display: block; font-size: 9pt; font-weight: 700; color: #6b7a90; }
header .doc { text-align: left; }
header .doc strong { font-size: 15pt; }
h2 { margin: 6mm 0 2.5mm; padding-right: 2.5mm; border-right: 1.2mm solid #0f766e; font-size: 12pt; font-weight: 800; color: #15335c; }
.info { display: grid; grid-template-columns: repeat(4, 1fr); margin-top: 4mm; border: 0.3mm solid #dfe5ec; border-radius: 1.5mm; overflow: hidden; }
.info div { padding: 2.2mm 3mm; border-left: 0.3mm solid #dfe5ec; }
.info div:nth-child(4n) { border-left: 0; }
.info div:nth-child(n+5) { border-top: 0.3mm solid #dfe5ec; }
.info small, .kpi small { display: block; font-size: 8.5pt; font-weight: 700; color: #6b7a90; }
.info strong { font-size: 10.5pt; font-weight: 800; }
.kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 2.5mm; }
.kpi { padding: 2.5mm 3mm; border: 0.3mm solid #dfe5ec; border-radius: 1.5mm; background: #f8fafc; }
.kpi strong { display: block; font-size: 15pt; font-weight: 900; color: #15335c; }
table { width: 100%; border-collapse: collapse; }
th { background: #eef2f7; color: #334155; font-size: 9pt; font-weight: 800; text-align: right; padding: 2mm 2.5mm; border: 0.3mm solid #dfe5ec; }
td { padding: 1.8mm 2.5mm; border: 0.3mm solid #e6ebf1; font-size: 9.5pt; }
tr { break-inside: avoid; }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; }
.pill { display: inline-block; padding: 0.3mm 2.2mm; border-radius: 10mm; font-size: 8.5pt; font-weight: 800; color: #fff; }
.empty { padding: 4mm; text-align: center; color: #6b7a90; border: 0.3mm dashed #cfd8e3; border-radius: 1.5mm; }
.notes { min-height: 26mm; padding: 3mm; border: 0.3mm solid #dfe5ec; border-radius: 1.5mm; white-space: pre-wrap; }
.notes .lines { height: 22mm; background: repeating-linear-gradient(to bottom, transparent 0, transparent 6.6mm, #dfe5ec 6.6mm, #dfe5ec 6.9mm); }
.signs { display: grid; grid-template-columns: 1fr 1fr; gap: 20mm; margin-top: 10mm; break-inside: avoid; }
.signs div { text-align: center; }
.signs .line { margin: 9mm 8mm 1.5mm; border-top: 0.35mm solid #334155; }
.signs span { font-size: 9pt; font-weight: 700; color: #6b7a90; }
footer { margin-top: 8mm; padding-top: 2.5mm; border-top: 0.3mm solid #dfe5ec; display: flex; justify-content: space-between; font-size: 8.5pt; color: #6b7a90; }
</style>
</head>
<body>
<header>
  <img src="${logoUrl()}" alt="">
  <div class="who"><strong>${PLATFORM}</strong><span>تعليمٌ ذكي، معرفة، ومستقبلٌ مشرق</span></div>
  <div class="doc"><strong>تقرير أداء الطالب</strong><span>${hijri(today)} — ${gregorian(today)} م</span></div>
</header>

<div class="info">
  <div><small>اسم الطالب</small><strong>${student.name}</strong></div>
  <div><small>الصف</small><strong>${student.primaryGrade || student.grade || '—'}</strong></div>
  <div><small>ولي الأمر</small><strong>${input.parentName || '—'}</strong></div>
  <div><small>المعلم</small><strong>${input.teacherName || '—'}</strong></div>
  <div><small>اسم المستخدم</small><strong>${student.username || '—'}</strong></div>
  <div><small>تاريخ التسجيل</small><strong>${student.createdAt ? gregorian(student.createdAt) : '—'}</strong></div>
  <div><small>آخر دخول</small><strong>${progress.lastLoginAt ? gregorian(progress.lastLoginAt) : student.lastActivity ? gregorian(student.lastActivity) : '—'}</strong></div>
  <div><small>التقدير العام</small><strong>${results.length ? grade(average) : '—'}</strong></div>
</div>

<h2>ملخّص المؤشّرات</h2>
<div class="kpis">${kpis.map(([label, value]) => html`<div class="kpi"><small>${label}</small><strong>${value}</strong></div>`)}</div>

<h2>الأداء حسب المادة</h2>
${subjects.length === 0 ? html`<p class="empty">لا نتائج اختبارات مسجّلة بعد.</p>` : html`
<table>
  <thead><tr><th>المادة</th><th>عدد الاختبارات</th><th>المعدّل</th><th>أعلى درجة</th><th>أدنى درجة</th><th>التقدير</th></tr></thead>
  <tbody>${subjects.map((row) => html`<tr><td><b>${row.subject}</b></td><td class="num">${row.count}</td><td class="num"><b style="color:${scoreColor(row.average)}">${row.average}%</b></td><td class="num">${row.best}%</td><td class="num">${row.worst}%</td><td>${grade(row.average)}</td></tr>`)}</tbody>
</table>`}

<h2>سجلّ الاختبارات</h2>
${results.length === 0 ? html`<p class="empty">لا اختبارات بعد.</p>` : html`
<table>
  <thead><tr><th>الاختبار</th><th>المادة</th><th>الوحدة</th><th>الدرجة</th><th>النسبة</th><th>التاريخ</th></tr></thead>
  <tbody>${results.slice(0, 40).map((result) => html`<tr><td>${result.quizTitle || result.quizType || 'اختبار'}</td><td>${result.subject || '—'}</td><td>${result.unit || '—'}</td><td class="num">${result.score ?? '—'} / ${result.total ?? '—'}</td><td class="num"><span class="pill" style="background:${scoreColor(result.percentage)}">${Math.round(result.percentage)}%</span></td><td class="num">${gregorian(result.createdAt)}</td></tr>`)}</tbody>
</table>`}

<h2>الشهادات</h2>
${input.certificates.length === 0 ? html`<p class="empty">لا شهادات صادرة بعد.</p>` : html`
<table>
  <thead><tr><th>الشهادة</th><th>المادة</th><th>الفصل</th><th>المعلم</th><th>رقم الشهادة</th><th>التاريخ</th></tr></thead>
  <tbody>${input.certificates.map((cert) => html`<tr><td><b>${(CERTIFICATE_TYPES[cert.type] ?? CERTIFICATE_TYPES.participation).title}</b></td><td>${cert.subject}</td><td>${cert.term || '—'}</td><td>${cert.teacherName || '—'}</td><td class="num">${certificateNumber(cert)}</td><td class="num">${gregorian(cert.date)}</td></tr>`)}</tbody>
</table>`}

<h2>ملاحظات المعلم</h2>
<div class="notes">${input.notes ? input.notes : html`<div class="lines"></div>`}</div>

<div class="signs">
  <div><div class="line"></div><span>توقيع المعلم</span></div>
  <div><div class="line"></div><span>توقيع ولي الأمر</span></div>
</div>

<footer><span>${PLATFORM}</span><span>صدر هذا التقرير آلياً من المنصّة</span></footer>
</body>
</html>`;
}
