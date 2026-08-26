import { useState } from "react";
import { ArrowLeft, Eye, EyeOff, KeyRound, LockKeyhole, Sparkles, UserRound } from "lucide-react";
import "./_group.css";

function LearningOrb() {
  return (
    <div className="drift absolute left-8 top-10 hidden h-28 w-28 -rotate-6 items-center justify-center rounded-[30px] border border-white/70 bg-[#e9c76a] shadow-[0_14px_0_#c99a42,0_25px_32px_rgba(78,67,41,.18)] md:flex">
      <div className="absolute inset-3 rounded-[22px] border-2 border-[#f8e7ac]/80" />
      <div className="relative text-center text-[#684b2b]"><KeyRound className="mx-auto h-10 w-10" strokeWidth={1.8} /><span className="mt-1 block text-xs font-extrabold">مفتاح المعرفة</span></div>
    </div>
  );
}

export function StudentLogin3D() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [visible, setVisible] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const showError = submitted && (!username.trim() || !password);

  const submit = () => {
    setSubmitted(true);
    if (username.trim() && password) {
      window.setTimeout(() => setSubmitted(false), 1700);
    }
  };

  return (
    <main className="manara-world min-h-[100dvh] px-4 py-6 sm:px-8 sm:py-10" dir="rtl">
      <div className="world-shell flex min-h-[calc(100dvh-3rem)] items-center justify-center">
        <LearningOrb />
        <div className="absolute right-0 top-3 hidden items-center gap-2 rounded-full border border-[#d8c795] bg-[#fff9e9]/80 px-4 py-2 text-xs font-bold text-[#80652c] shadow-sm md:flex"><Sparkles className="h-4 w-4 text-[#d89d27]" /> مساحة آمنة للتعلّم</div>
        <section className="glass-panel appear relative w-full max-w-[940px] overflow-hidden rounded-[34px] p-2 sm:p-3">
          <div className="grid min-h-[590px] overflow-hidden rounded-[27px] bg-[#fffdf8] lg:grid-cols-[.93fr_1.07fr]">
            <div className="relative flex flex-col justify-between overflow-hidden bg-[#173b50] p-7 text-[#fff8e9] sm:p-10">
              <div className="absolute -bottom-20 -left-20 h-64 w-64 rounded-full border-[28px] border-[#2d6471] opacity-60" />
              <div className="absolute right-[-70px] top-28 h-52 w-52 rounded-full bg-[#dba84f]/20 blur-2xl" />
              <div className="relative">
                <div className="mb-12 flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#edc35f] text-[#173b50] shadow-[0_5px_0_#b48639]"><Sparkles className="h-6 w-6" /></div>
                  <div><div className="text-xl font-black">منارة المعرفة</div><div className="text-xs font-bold text-[#a8d9d7]">تعليم ذكي، معرفة، ومستقبل مشرق</div></div>
                </div>
                <p className="mb-3 text-sm font-bold text-[#8bd0ce]">بوابتك تبدأ من هنا</p>
                <h1 className="max-w-sm text-4xl font-black leading-[1.18] sm:text-5xl">افتح بابك<br /><span className="text-[#f1c664]">للتعلّم</span></h1>
                <p className="mt-5 max-w-xs text-sm font-medium leading-7 text-[#c3dcdb]">كل يوم في منارة يحمل سؤالًا جديدًا، ومهارة صغيرة تجعلك أقوى.</p>
              </div>
              <div className="relative mt-10 flex items-center gap-3 text-xs font-bold text-[#b8d8d5]"><div className="flex -space-x-2 space-x-reverse"><span className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-[#173b50] bg-[#dd7564]">ل</span><span className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-[#173b50] bg-[#7663c7]">م</span><span className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-[#173b50] bg-[#e9c76a] text-[#173b50]">س</span></div><span>انضم إلى أبطال التعلّم</span></div>
            </div>
            <div className="flex items-center p-6 sm:p-12">
              <div className="w-full">
                <div className="mb-8">
                  <div className="mb-3 inline-flex items-center gap-2 rounded-full bg-[#edf5f0] px-3 py-1.5 text-xs font-extrabold text-[#147d83]"><span className="h-2 w-2 rounded-full bg-[#e9ac3e]" /> دخول الطالب</div>
                  <h2 className="text-3xl font-black text-[#183047]">أهلًا يا بطل!</h2>
                  <p className="mt-2 text-sm font-medium text-[#687c83]">سجّل دخولك إلى بوابة الطالب</p>
                </div>
                <div className="space-y-4">
                  <label className="block"><span className="mb-2 block text-sm font-extrabold text-[#284658]">اسم المستخدم</span><div className="relative"><UserRound className="pointer-events-none absolute right-4 top-1/2 h-5 w-5 -translate-y-1/2 text-[#147d83]" /><input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="اكتب اسم المستخدم" className={`world-input w-full rounded-2xl border bg-[#fbfaf5] py-4 pl-4 pr-12 text-right font-bold text-[#183047] placeholder:text-[#9aa9a8] ${showError && !username.trim() ? "border-[#df6d5f]" : "border-[#dbe5df]"}`} /></div>{showError && !username.trim() && <span className="mt-1.5 block text-xs font-bold text-[#bd5148]">اكتب اسم المستخدم للمتابعة</span>}</label>
                  <label className="block"><span className="mb-2 block text-sm font-extrabold text-[#284658]">كلمة المرور</span><div className="relative"><LockKeyhole className="pointer-events-none absolute right-4 top-1/2 h-5 w-5 -translate-y-1/2 text-[#147d83]" /><input type={visible ? "text" : "password"} value={password} onChange={(e) => setPassword(e.target.value)} onKeyDown={(e) => e.key === "Enter" && submit()} placeholder="اكتب كلمة المرور" className={`world-input w-full rounded-2xl border bg-[#fbfaf5] py-4 pl-12 pr-12 text-right font-bold text-[#183047] placeholder:text-[#9aa9a8] ${showError && !password ? "border-[#df6d5f]" : "border-[#dbe5df]"}`} /><button type="button" onClick={() => setVisible((v) => !v)} aria-label={visible ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"} className="absolute left-3 top-1/2 -translate-y-1/2 rounded-lg p-2 text-[#6c8285] hover:bg-[#eaf3ef]">{visible ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}</button></div>{showError && !password && <span className="mt-1.5 block text-xs font-bold text-[#bd5148]">اكتب كلمة المرور للمتابعة</span>}</label>
                </div>
                {submitted && username.trim() && password && <div className="mt-4 rounded-2xl border border-[#9bd6bd] bg-[#eaf8ef] px-4 py-3 text-center text-sm font-extrabold text-[#28714c]">أحسنت! تم التحقق، لنبدأ رحلة التعلّم.</div>}
                <button type="button" onClick={submit} className="primary-action mt-7 flex w-full items-center justify-center gap-3 rounded-2xl bg-[#147d83] py-4 text-base font-black text-white shadow-[0_6px_0_#0b5b68]"><span>ابدأ رحلة التعلم</span><ArrowLeft className="h-5 w-5" /></button>
                <p className="mt-5 text-center text-xs font-bold text-[#849492]">هذا التطبيق مخصص للطلاب فقط</p>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}

export default StudentLogin3D;