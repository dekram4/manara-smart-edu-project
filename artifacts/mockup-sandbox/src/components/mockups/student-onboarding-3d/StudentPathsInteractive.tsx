import { useState } from "react";
import { Atom, BookOpen, Check, ChevronLeft, GraduationCap, Sparkles, Star, Trophy } from "lucide-react";
import "./_group.css";
import "./StudentPathsInteractive.css";

const paths = [
  { id: "primary", title: "المرحلة الابتدائية", subtitle: "اكتشف الأساسيات بفضول", meta: "الصف الرابع · 6 مواد", icon: BookOpen, color: "#147d83", wash: "#e5f4ef", level: "بداية المغامرة" },
  { id: "middle", title: "المرحلة الإعدادية", subtitle: "ابنِ مهاراتك بثقة", meta: "الصف السابع · 7 مواد", icon: Atom, color: "#7663c7", wash: "#eeeafb", level: "خطوة أعمق" },
  { id: "secondary", title: "المرحلة الثانوية", subtitle: "اقترب من حلمك الكبير", meta: "الصف الأول الثانوي · 8 مواد", icon: GraduationCap, color: "#d47750", wash: "#fff0e5", level: "نحو الهدف" },
];

export function StudentPathsInteractive() {
  const [selected, setSelected] = useState("primary");
  const [continued, setContinued] = useState(false);
  const choice = paths.find((path) => path.id === selected) ?? paths[0];

  return (
    <main className="manara-world paths-interactive min-h-[100dvh] px-4 py-6 sm:px-8 sm:py-10" dir="rtl">
      <div className="world-shell">
        <header className="mb-7 flex items-center justify-between">
          <div className="flex items-center gap-3"><div className="paths-mark flex h-11 w-11 items-center justify-center rounded-2xl bg-[#173b50] text-[#f1c664]"><Sparkles className="h-5 w-5" /></div><div><div className="text-lg font-black text-[#183047]">منارة المعرفة</div><div className="text-xs font-bold text-[#758683]">منصة الطالب</div></div></div>
          <div className="flex items-center gap-2 rounded-full border border-[#d9dfd6] bg-[#fffdf7]/75 px-3 py-2 text-xs font-extrabold text-[#657976]"><span className="h-2 w-2 rounded-full bg-[#e9ac3e]" /> خطوة ١ من ٢</div>
        </header>
        <section className="glass-panel paths-panel relative overflow-hidden rounded-[34px] p-6 sm:p-10">
          <div className="paths-sun" />
          <div className="relative mx-auto max-w-3xl text-center">
            <div className="paths-trophy mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-[22px] bg-[#173b50] text-[#f1c664]"><Trophy className="h-8 w-8" /></div>
            <p className="mb-2 text-sm font-extrabold text-[#147d83]">أهلًا بك يا سامي</p>
            <h1 className="text-3xl font-black text-[#183047] sm:text-4xl">اختر رحلتك التعليمية</h1>
            <p className="mx-auto mt-3 max-w-md text-sm font-medium leading-7 text-[#71827f]">اختر بوصلتك الآن، وسنرتّب لك الدروس التي تناسب مستواك.</p>
          </div>
          <div className="relative mt-9 grid gap-4 md:grid-cols-3">
            {paths.map((path, index) => {
              const Icon = path.icon;
              const active = selected === path.id;
              return (
                <button key={path.id} type="button" onClick={() => { setSelected(path.id); setContinued(false); }} className={`path-card lift appear relative overflow-hidden rounded-[25px] border-2 p-5 text-right ${active ? "path-card-active border-[#147d83] bg-[#f7fffb] shadow-[0_9px_0_rgba(20,125,131,.16)]" : "border-[#e3e5dc] bg-[#fffdf8]"}`} style={{ animationDelay: `${index * 90}ms` }}>
                  <div className="path-card-glow absolute -left-7 -top-7 h-24 w-24 rounded-full opacity-50" style={{ background: path.wash }} />
                  <div className="relative flex items-start justify-between"><div className="flex h-14 w-14 items-center justify-center rounded-2xl shadow-[0_4px_0_rgba(24,48,71,.13)]" style={{ background: path.wash, color: path.color }}><Icon className="h-7 w-7" /></div><span className={`flex h-7 w-7 items-center justify-center rounded-full border-2 ${active ? "border-[#147d83] bg-[#147d83] text-white" : "border-[#d8ded8] text-transparent"}`}><Check className="h-4 w-4" strokeWidth={3} /></span></div>
                  <div className="relative mt-6"><span className="mb-2 inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wide" style={{ color: path.color }}><Star className="h-3 w-3 fill-current" /> {path.level}</span><h2 className="text-lg font-black text-[#183047]">{path.title}</h2><p className="mt-1 text-sm font-bold" style={{ color: path.color }}>{path.subtitle}</p><p className="mt-4 text-xs font-bold text-[#87928f]">{path.meta}</p></div>
                  {active && <div className="path-card-check absolute bottom-0 right-0 h-1 w-full bg-[#147d83]" />}
                </button>
              );
            })}
          </div>
          <div className="relative mt-8 flex flex-col items-center justify-between gap-4 rounded-2xl border border-[#e7dfc5] bg-[#fff9e9] px-5 py-4 sm:flex-row">
            <div className="flex items-center gap-3"><div className="flex h-10 w-10 items-center justify-center rounded-xl bg-[#f3df9a] text-[#8a6929]"><BookOpen className="h-5 w-5" /></div><div><p className="text-sm font-black text-[#5d4c2e]">مسارك المختار</p><p className="text-xs font-bold text-[#8a7750]">{choice.title} · {choice.meta.split("·")[0]}</p></div></div><div className="text-xs font-extrabold text-[#8a7750]">يمكنك التغيير لاحقًا</div>
          </div>
          {continued && <div className="paths-success mt-4 flex items-center justify-center gap-2 rounded-2xl border border-[#9bd6bd] bg-[#eaf8ef] px-4 py-3 text-sm font-extrabold text-[#28714c]"><Check className="h-5 w-5" /> رائع! نجهّز لك دروس {choice.title}</div>}
          <button type="button" onClick={() => setContinued(true)} className="primary-action relative mt-6 flex w-full items-center justify-center gap-3 rounded-2xl bg-[#147d83] py-4 text-base font-black text-white shadow-[0_6px_0_#0b5b68]">الدخول إلى لوحة الطالب<ChevronLeft className="h-5 w-5" /></button>
        </section>
      </div>
    </main>
  );
}

export default StudentPathsInteractive;