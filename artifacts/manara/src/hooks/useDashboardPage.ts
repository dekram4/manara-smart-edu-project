import { useEffect, useState } from 'react';

import { readDashboardRoute, writeDashboardRoute, type DashboardRole } from '../utils/dashboardRoute';

/**
 * `useState` لصفحة اللوحة، تبدأ من العنوان وتُكتب فيه.
 * و`params` ما يُحفظ معها (ابنٌ مختار، مادة…)، تُقرأ أوّلَ مرّةٍ بـ`readDashboardRoute`.
 */
export function useDashboardPage<T extends string>(
  role: DashboardRole,
  pages: readonly T[],
  fallback: T,
  params: ReadonlyArray<string | null | undefined> = [],
): [T, (page: T) => void] {
  const [page, setPage] = useState<T>(() => readDashboardRoute(role, pages, fallback).page);
  const paramsKey = params.map((param) => param ?? '').join('\u0000');
  useEffect(() => {
    writeDashboardRoute(role, page, params);
    // ‏`paramsKey` يمثّل `params`؛ المصفوفةُ نفسُها جديدةٌ في كل بناء.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [role, page, paramsKey]);
  return [page, setPage];
}
