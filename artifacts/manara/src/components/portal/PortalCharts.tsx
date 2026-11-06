import React from 'react';
import { Area, AreaChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

/** فئاتُ الأداء بألوانها — الألوانُ نفسها في الشارات (`scoreTone`). */
export const SCORE_BANDS = [
  { key: 'excellent', label: 'ممتاز (٩٠٪ فأكثر)', color: '#15803d', test: (v: number) => v >= 90 },
  { key: 'veryGood', label: 'جيد جداً (٧٥–٨٩٪)', color: '#1f4e8c', test: (v: number) => v >= 75 && v < 90 },
  { key: 'good', label: 'جيد (٦٠–٧٤٪)', color: '#b45309', test: (v: number) => v >= 60 && v < 75 },
  { key: 'weak', label: 'يحتاج متابعة (دون ٦٠٪)', color: '#b91c1c', test: (v: number) => v < 60 },
] as const;

/** كم معدّلاً في كل فئة. */
export const scoreBuckets = (averages: number[]) =>
  SCORE_BANDS.map((band) => ({ ...band, value: averages.filter((v) => band.test(v)).length }));

/** عددُ الاختبارات في كل يومٍ من آخر [days] يوماً، الأقدمُ أولاً. */
export const dailyCounts = (dates: string[], days = 14) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const buckets = Array.from({ length: days }, (_, i) => {
    const day = new Date(today);
    day.setDate(today.getDate() - (days - 1 - i));
    return { key: day.getTime(), label: day.toLocaleDateString('ar-SA-u-ca-gregory-nu-latn', { day: 'numeric', month: 'short' }), value: 0 };
  });
  const index = new Map(buckets.map((bucket, i) => [bucket.key, i]));
  dates.forEach((value) => {
    const date = new Date(value);
    if (!Number.isFinite(date.getTime())) return;
    date.setHours(0, 0, 0, 0);
    const i = index.get(date.getTime());
    if (i !== undefined) buckets[i].value += 1;
  });
  return buckets;
};

/**
 * حلقةُ توزيع الأداء: كم طالباً في كل فئة، وفي وسطها العدد الكلي.
 * ومفتاحُ الألوان بجانبها بالأرقام، فلا يُحتاج إلى المرور فوقها لقراءتها.
 */
export const ScoreDonut: React.FC<{ averages: number[]; unit?: string }> = ({ averages, unit = 'طالب' }) => {
  const data = scoreBuckets(averages);
  const total = averages.length;
  return (
    <div className="portal-donut">
      <div className="portal-donut-chart">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={total ? data : [{ key: 'empty', label: '', color: '#e9eef4', value: 1 }]}
              dataKey="value"
              nameKey="label"
              innerRadius="68%"
              outerRadius="100%"
              paddingAngle={total ? 2 : 0}
              stroke="none"
              isAnimationActive
            >
              {(total ? data : [{ color: '#e9eef4' }]).map((entry, i) => (
                <Cell key={i} fill={entry.color} />
              ))}
            </Pie>
            {total > 0 && <Tooltip formatter={(value: number, name: string) => [`${value} ${unit}`, name]} />}
          </PieChart>
        </ResponsiveContainer>
        <div className="portal-donut-center">
          <strong>{total}</strong>
          <span>{unit}</span>
        </div>
      </div>
      <ul className="portal-legend">
        {data.map((band) => (
          <li key={band.key}>
            <i style={{ background: band.color }} aria-hidden="true" />
            <span>{band.label}</span>
            <b>{band.value}</b>
          </li>
        ))}
      </ul>
    </div>
  );
};

/** نشاطُ الاختبارات يوماً بيوم: مساحةٌ بتدرّجٍ هادئ. */
export const ActivityArea: React.FC<{ dates: string[]; days?: number; label?: string }> = ({ dates, days = 14, label = 'اختبارات' }) => {
  const data = dailyCounts(dates, days);
  return (
    <ResponsiveContainer width="100%" height={230}>
      <AreaChart data={data} margin={{ top: 10, right: 6, left: 6, bottom: 0 }}>
        <defs>
          <linearGradient id="portalArea" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#0f766e" stopOpacity={0.28} />
            <stop offset="100%" stopColor="#0f766e" stopOpacity={0.02} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#e3e8ef" vertical={false} />
        <XAxis dataKey="label" tick={{ fontSize: 11, fill: '#94a3b8' }} axisLine={false} tickLine={false} reversed interval="preserveStartEnd" minTickGap={18} />
        <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: '#94a3b8' }} width={28} axisLine={false} tickLine={false} orientation="right" />
        <Tooltip formatter={(value: number) => [`${value} ${label}`, 'العدد']} />
        <Area type="monotone" dataKey="value" stroke="#0f766e" strokeWidth={2.5} fill="url(#portalArea)" />
      </AreaChart>
    </ResponsiveContainer>
  );
};
