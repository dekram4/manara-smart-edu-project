import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { StudentAppearance, StudentInfo } from '../../types';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import {
  getStudentAppearance,
  STUDENT_ACCESSORY_OPTIONS,
  STUDENT_BOTTOM_OPTIONS,
  STUDENT_HAIR_OPTIONS,
  STUDENT_HAIR_COLOR_OPTIONS,
  STUDENT_SHAPE_OPTIONS,
  STUDENT_SHOES_OPTIONS,
  STUDENT_SKIN_OPTIONS,
  STUDENT_TOP_OPTIONS,
} from '../../utils/studentAppearance';
import StudentAvatar from './components/StudentAvatar';

const StudentAvatar3D = React.lazy(() => import('./components/StudentAvatar3D'));

interface StudentPersonalityProps {
  student: StudentInfo;
  onSave: (appearance: StudentAppearance) => void;
}

type CustomizationTab = 'shape' | 'top' | 'bottom' | 'shoes' | 'hair' | 'hairColor' | 'skin' | 'accessory';
type ChoiceOption = {
  readonly value: string;
  readonly label: string;
  readonly swatch?: string;
};

const CUSTOMIZATION_TABS: Array<{
  id: CustomizationTab;
  label: string;
  icon: string;
  hint: string;
  accent: string;
}> = [
  { id: 'shape', label: 'الشخصية', icon: '🙂', hint: 'الملامح والشكل', accent: '#fb7185' },
  { id: 'top', label: 'العلوي', icon: '👕', hint: 'القميص والزي', accent: '#a78bfa' },
  { id: 'bottom', label: 'السفلي', icon: '👖', hint: 'البنطال', accent: '#38bdf8' },
  { id: 'shoes', label: 'الأحذية', icon: '👟', hint: 'خطوات بطلك', accent: '#34d399' },
  { id: 'hair', label: 'الشعر', icon: '🦱', hint: 'تسريحة الرأس', accent: '#fbbf24' },
  { id: 'hairColor', label: 'لون الشعر', icon: '🎨', hint: 'لون التسريحة', accent: '#fb7185' },
  { id: 'skin', label: 'البشرة', icon: '🎨', hint: 'لون البشرة والهالة', accent: '#fb923c' },
  { id: 'accessory', label: 'الإكسسوارات', icon: '✨', hint: 'اللمسة الأخيرة', accent: '#e879f9' },
];

const ChoiceCarousel: React.FC<{
  options: readonly ChoiceOption[];
  selected: string | undefined;
  accent: string;
  onSelect: (value: string) => void;
}> = ({ options, selected, accent, onSelect }) => (
  <div
    className="flex snap-x snap-mandatory gap-3 overflow-x-auto overscroll-x-contain pb-3 pt-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
    role="listbox"
    aria-label="خيارات التخصيص"
  >
    {options.map(option => {
      const isSelected = selected === option.value;
      return (
        <button
          key={option.value}
          type="button"
          role="option"
          aria-selected={isSelected}
          aria-label={option.label}
          onClick={() => onSelect(option.value)}
          className={`group flex min-w-[96px] snap-start flex-col items-center rounded-2xl border-2 bg-white p-2.5 text-center transition-all duration-200 sm:min-w-[112px] ${
            isSelected
              ? 'scale-[1.03] border-transparent shadow-lg'
              : 'border-slate-200 hover:-translate-y-1 hover:border-slate-300 hover:shadow-md'
          }`}
          style={isSelected ? {
            borderColor: accent,
            boxShadow: `0 10px 24px ${accent}33`,
          } : undefined}
        >
          <span
            className="flex h-14 w-14 items-center justify-center rounded-2xl text-4xl leading-none transition-transform group-hover:scale-110"
            style={{
              background: option.swatch
                ? option.swatch
                : `linear-gradient(145deg, ${accent}20, ${accent}08)`,
            }}
          >
            {option.value}
          </span>
          <span className="mt-2 line-clamp-2 min-h-8 text-[11px] font-black leading-4 text-slate-600">
            {option.label}
          </span>
          {isSelected && (
            <span className="mt-1 text-[10px] font-black" style={{ color: accent }}>
              ✓ مختار
            </span>
          )}
        </button>
      );
    })}
  </div>
);

const findLabel = (options: readonly ChoiceOption[], value: string | undefined, fallback: string) =>
  options.find(option => option.value === value)?.label || fallback;

const StudentPersonality: React.FC<StudentPersonalityProps> = ({ student, onSave }) => {
  const [appearance, setAppearance] = useState<StudentAppearance>(() => getStudentAppearance(student));
  const [activeTab, setActiveTab] = useState<CustomizationTab>('shape');
  const [saved, setSaved] = useState(true);

  const choose = (next: Partial<StudentAppearance>) => {
    GameAudioEngine.play('uiSelect');
    setAppearance(current => ({ ...current, ...next }));
    setSaved(false);
  };

  const saveAppearance = () => {
    if (saved) return;
    GameAudioEngine.play('uiSelect');
    // Keep outfit populated for old screens while storing every full-body slot.
    onSave({ ...appearance, outfit: appearance.top || appearance.outfit });
    setSaved(true);
  };

  const selectedTab = CUSTOMIZATION_TABS.find(tab => tab.id === activeTab) || CUSTOMIZATION_TABS[0];
  const tabContent = useMemo(() => {
    switch (activeTab) {
      case 'shape':
        return {
          title: 'اختَر ملامح بطلك',
          description: 'شخصيات متنوعة تظهر مباشرة في المعاينة الكاملة.',
          options: STUDENT_SHAPE_OPTIONS,
          selected: appearance.shape,
          onSelect: (value: string) => choose({ shape: value }),
        };
      case 'top':
        return {
          title: 'الملابس العلوية',
          description: 'غيّر القميص أو الزي ليأخذ بطلك أسلوبًا جديدًا.',
          options: STUDENT_TOP_OPTIONS,
          selected: appearance.top || appearance.outfit,
          onSelect: (value: string) => choose({ top: value, outfit: value }),
        };
      case 'bottom':
        return {
          title: 'الملابس السفلية',
          description: 'اختر البنطال الذي يناسب مغامرة اليوم.',
          options: STUDENT_BOTTOM_OPTIONS,
          selected: appearance.bottom,
          onSelect: (value: string) => choose({ bottom: value }),
        };
      case 'shoes':
        return {
          title: 'الأحذية',
          description: 'خطوات رياضية أو مغامرة أو أنيقة.',
          options: STUDENT_SHOES_OPTIONS,
          selected: appearance.shoes,
          onSelect: (value: string) => choose({ shoes: value }),
        };
      case 'hair':
        return {
          title: 'شعر الرأس',
          description: 'أضف تسريحة أو قبعة مميزة لشخصيتك.',
          options: STUDENT_HAIR_OPTIONS,
          selected: appearance.hair,
          onSelect: (value: string) => choose({ hair: value }),
        };
      case 'hairColor':
        return {
          title: 'لون الشعر',
          description: 'غيّر لون التسريحة وشاهد النتيجة فورًا في المجسم ثلاثي الأبعاد.',
          options: STUDENT_HAIR_COLOR_OPTIONS,
          selected: appearance.hairColor,
          onSelect: (value: string) => choose({ hairColor: value }),
        };
      case 'skin':
        return {
          title: 'لون البشرة والهالة',
          description: 'اختر لون البشرة، ثم لون الطاقة من الدوائر السريعة.',
          options: STUDENT_SKIN_OPTIONS,
          selected: appearance.skinTone,
          onSelect: (value: string) => choose({ skinTone: value }),
        };
      case 'accessory':
        return {
          title: 'الإكسسوارات',
          description: 'أضف لمسة ذكية أو سحرية أو مغامرة.',
          options: STUDENT_ACCESSORY_OPTIONS,
          selected: appearance.accessory,
          onSelect: (value: string) => choose({ accessory: value }),
        };
      default:
        return null;
    }
  }, [activeTab, appearance]);

  const selectedShapeLabel = findLabel(STUDENT_SHAPE_OPTIONS, appearance.shape, 'شخصية مميزة');
  const selectedTopLabel = findLabel(STUDENT_TOP_OPTIONS, appearance.top || appearance.outfit, 'زي خاص');
  const selectedBottomLabel = findLabel(STUDENT_BOTTOM_OPTIONS, appearance.bottom, 'بنطال');
  const selectedShoesLabel = findLabel(STUDENT_SHOES_OPTIONS, appearance.shoes, 'حذاء');

  return (
    <div className="relative min-w-0 overflow-hidden rounded-[38px] border border-rose-200 bg-[#fff8fb] p-2.5 shadow-[0_30px_90px_-28px_rgba(15,23,42,0.75)] sm:p-5 md:p-7">
      <div className="pointer-events-none absolute -right-24 -top-28 h-72 w-72 rounded-full bg-rose-200/60 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-28 -left-24 h-72 w-72 rounded-full bg-cyan-200/60 blur-3xl" />

      <div className="relative z-10 overflow-hidden rounded-[30px] bg-gradient-to-l from-[#172554] via-[#1e1b4b] to-[#312e81] p-4 text-white shadow-2xl sm:p-7">
        <div className="flex flex-col justify-between gap-4 md:flex-row md:items-center">
          <div className="min-w-0">
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-black text-rose-100 backdrop-blur">
              <span>✦</span> استوديو الشخصية الكامل
            </div>
            <h2 className="text-2xl font-black tracking-tight sm:text-4xl">اصنع بطلك من الرأس إلى القدمين</h2>
            <p className="mt-2 max-w-2xl text-sm font-bold leading-7 text-indigo-100">
              بدّل الملامح والملابس والبنطال والأحذية والشعر والإكسسوارات، وشاهد النتيجة فورًا.
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-2 self-start rounded-2xl border border-white/10 bg-white/10 px-3 py-2 text-xs font-black text-cyan-100 md:self-auto">
            <span className={`h-2.5 w-2.5 rounded-full ${saved ? 'bg-emerald-300' : 'animate-pulse bg-amber-300'}`} />
            {saved ? 'محفوظة في حسابك' : 'تعديلات غير محفوظة'}
          </div>
        </div>

        <div className="mt-5 grid min-w-0 gap-5 lg:grid-cols-[minmax(260px,0.72fr)_minmax(0,1.45fr)]">
          <div className="relative min-w-0 overflow-hidden rounded-[28px] border border-white/15 bg-slate-950/55 p-4 shadow-inner lg:sticky lg:top-5 lg:self-start">
            <div
              className="pointer-events-none absolute inset-0 opacity-60"
              style={{
                backgroundImage: 'linear-gradient(rgba(255,255,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.06) 1px, transparent 1px)',
                backgroundSize: '28px 28px',
              }}
            />
            <div className="relative z-10 flex items-center justify-between">
              <span className="text-xs font-black text-indigo-200">المعاينة المباشرة</span>
              <span className="rounded-full bg-emerald-400/15 px-2.5 py-1 text-[10px] font-black text-emerald-200">FULL BODY</span>
            </div>
            <div className="relative z-10 my-5 flex min-h-[230px] items-center justify-center sm:min-h-[280px]">
              <div className="absolute h-52 w-52 rounded-full bg-cyan-400/20 blur-3xl" />
              <React.Suspense
                fallback={
                  <div className="flex min-h-[340px] w-full items-center justify-center rounded-[26px] bg-gradient-to-b from-indigo-950 via-slate-900 to-slate-950">
                    <StudentAvatar appearance={appearance} size="xl" />
                  </div>
                }
              >
                <StudentAvatar3D appearance={appearance} studentName={student.name || 'بطلك'} className="w-full" />
              </React.Suspense>
            </div>
            <div className="relative z-10 rounded-2xl border border-white/10 bg-white/10 p-3 backdrop-blur">
              <p className="truncate text-lg font-black">{student.name || 'بطلي'}</p>
              <p className="mt-1 truncate text-xs font-bold text-indigo-200">{selectedShapeLabel}</p>
              <div className="mt-3 flex flex-wrap gap-2">
                {[selectedTopLabel, selectedBottomLabel, selectedShoesLabel].map(label => (
                  <span key={label} className="rounded-full bg-white/10 px-2.5 py-1 text-[10px] font-black text-cyan-100">
                    {label}
                  </span>
                ))}
              </div>
            </div>
          </div>

          <div className="min-w-0 space-y-4">
            <div className="rounded-[26px] border border-white/10 bg-white/10 p-3 backdrop-blur sm:p-4">
              <div className="mb-3 flex items-center justify-between gap-3">
                <div>
                  <p className="text-xs font-black text-cyan-200">مراحل التخصيص</p>
                  <h3 className="mt-1 text-base font-black text-white">اسحب التبويبات واختر ما يناسبك</h3>
                </div>
                <span className="shrink-0 rounded-xl bg-white/10 px-2.5 py-1 text-[10px] font-black text-indigo-100">
                  {CUSTOMIZATION_TABS.findIndex(tab => tab.id === activeTab) + 1}/{CUSTOMIZATION_TABS.length}
                </span>
              </div>
              <div className="flex snap-x gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden" role="tablist" aria-label="أقسام تخصيص الشخصية">
                {CUSTOMIZATION_TABS.map(tab => {
                  const active = tab.id === activeTab;
                  return (
                    <button
                      key={tab.id}
                      type="button"
                      role="tab"
                      aria-selected={active}
                      onClick={() => {
                        GameAudioEngine.play('uiSelect');
                        setActiveTab(tab.id);
                      }}
                      className={`flex min-w-[105px] snap-start items-center gap-2 rounded-2xl border px-3 py-2 text-right transition-all sm:min-w-[120px] ${
                        active ? 'bg-white text-slate-900 shadow-lg' : 'border-white/10 bg-slate-950/35 text-indigo-100 hover:bg-white/15'
                      }`}
                      style={active ? { borderColor: tab.accent } : undefined}
                    >
                      <span className="text-2xl leading-none">{tab.icon}</span>
                      <span className="min-w-0">
                        <span className="block truncate text-xs font-black">{tab.label}</span>
                        <span className={`mt-0.5 block truncate text-[9px] font-bold ${active ? 'text-slate-500' : 'text-indigo-300'}`}>{tab.hint}</span>
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>

            {tabContent && (
              <section className="min-w-0 rounded-[26px] border border-slate-200 bg-white p-4 shadow-sm sm:p-5" aria-labelledby="customization-panel-title">
                <div className="mb-3 flex items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-black" style={{ color: selectedTab.accent }}>اختيار مباشر</p>
                    <h3 id="customization-panel-title" className="mt-1 text-xl font-black text-slate-900">{tabContent.title}</h3>
                    <p className="mt-1 text-xs font-bold leading-5 text-slate-500">{tabContent.description}</p>
                  </div>
                  <span className="shrink-0 rounded-xl px-2.5 py-1 text-[10px] font-black" style={{ color: selectedTab.accent, backgroundColor: `${selectedTab.accent}18` }}>
                    {tabContent.options.length} خيارات
                  </span>
                </div>
                <ChoiceCarousel
                  options={tabContent.options}
                  selected={tabContent.selected}
                  accent={selectedTab.accent}
                  onSelect={tabContent.onSelect}
                />
              </section>
            )}

            {activeTab === 'skin' && (
              <section className="rounded-[26px] border border-slate-200 bg-white p-4 shadow-sm sm:p-5">
                <div className="mb-3 flex items-center justify-between gap-3">
                  <div>
                    <p className="text-xs font-black text-cyan-600">لون الهوية</p>
                    <h3 className="mt-1 text-base font-black text-slate-900">اختر لون طاقة الشخصية</h3>
                  </div>
                  <span className="text-xs font-bold text-slate-400">يظهر في الإضاءة والبطاقات</span>
                </div>
                <div className="flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                  {['#38bdf8', '#f472b6', '#a78bfa', '#34d399', '#fbbf24', '#fb7185', '#22d3ee', '#818cf8'].map(color => (
                    <button
                      key={color}
                      type="button"
                      aria-label={`لون الطاقة ${color}`}
                      aria-pressed={appearance.color === color}
                      onClick={() => choose({ color })}
                      className={`h-10 w-10 shrink-0 rounded-xl border-2 transition-transform hover:scale-110 ${appearance.color === color ? 'scale-110 border-slate-900 shadow-lg' : 'border-white shadow'}`}
                      style={{ background: `linear-gradient(135deg, ${color}, ${color}99)` }}
                    />
                  ))}
                </div>
              </section>
            )}

            <div className="flex flex-col gap-3 rounded-[26px] border border-slate-200 bg-white p-4 shadow-sm sm:flex-row sm:items-center sm:justify-between">
              <div className="text-center sm:text-right">
                <p className="text-sm font-black text-slate-700">
                  {saved ? 'شخصيتك محفوظة في حسابك 🌟' : 'التغييرات جاهزة — احفظ بطلك الجديد'}
                </p>
                <p className="mt-1 text-[11px] font-bold text-slate-400">يتم حفظ القطع داخل ملف الطالب ومزامنتها مع Supabase.</p>
              </div>
              <motion.button
                type="button"
                whileHover={{ scale: saved ? 1 : 1.03 }}
                whileTap={{ scale: saved ? 1 : 0.96 }}
                onClick={saveAppearance}
                disabled={saved}
                className={`w-full rounded-2xl px-7 py-3.5 text-base font-black shadow-lg transition-all sm:w-auto ${
                  saved
                    ? 'cursor-not-allowed bg-emerald-100 text-emerald-700'
                    : 'cursor-pointer bg-gradient-to-r from-rose-500 to-violet-600 text-white shadow-rose-500/25 hover:from-rose-400 hover:to-violet-500'
                }`}
              >
                {saved ? '✅ تم الحفظ' : '💾 حفظ الشخصية'}
              </motion.button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default StudentPersonality;