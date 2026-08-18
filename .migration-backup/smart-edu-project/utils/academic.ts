import { HierarchicalConfig } from '../types';
import { getRecordTeacherId, normalizeScopeValue } from './scope';

const cleanName = (value: unknown): string => String(value ?? '').trim();

const uniqueNames = (values: unknown[]): string[] => {
  const seen = new Set<string>();
  const result: string[] = [];
  values.forEach(value => {
    const name = cleanName(value);
    const key = normalizeScopeValue(name);
    if (!name || seen.has(key)) return;
    seen.add(key);
    result.push(name);
  });
  return result;
};

/**
 * Merge duplicate copies of the same academic configuration without merging
 * separate teacher-owned configurations. This also repairs duplicate nested
 * terms, subjects, and units created by older versions of the settings screen.
 */
export const dedupeHierarchicalConfigs = (value: unknown): HierarchicalConfig[] => {
  if (!Array.isArray(value)) return [];

  const grouped = new Map<string, HierarchicalConfig>();
  value.forEach((rawConfig: any) => {
    if (!rawConfig || typeof rawConfig !== 'object') return;
    const grade = cleanName(rawConfig.grade);
    if (!grade) return;

    const owner = getRecordTeacherId(rawConfig);
    const key = `${owner || 'admin'}::${normalizeScopeValue(grade)}`;
    const existing = grouped.get(key);
    if (!existing) {
      grouped.set(key, {
        ...rawConfig,
        grade,
        atrams: [],
      });
    }

    const target = grouped.get(key)!;
    const atrams = Array.isArray(rawConfig.atrams) ? rawConfig.atrams : [];
    const targetAtrams = Array.isArray(target.atrams) ? target.atrams : [];

    atrams.forEach((rawAtram: any) => {
      const atramName = cleanName(rawAtram?.atram);
      if (!atramName) return;
      let targetAtram = targetAtrams.find(
        item => normalizeScopeValue(item.atram) === normalizeScopeValue(atramName),
      );
      if (!targetAtram) {
        targetAtram = { atram: atramName, subjects: [] };
        targetAtrams.push(targetAtram);
      }

      const subjects = Array.isArray(rawAtram?.subjects) ? rawAtram.subjects : [];
      const targetSubjects = Array.isArray(targetAtram.subjects) ? targetAtram.subjects : [];
      subjects.forEach((rawSubject: any) => {
        const subjectName = cleanName(rawSubject?.subject);
        if (!subjectName) return;
        let targetSubject = targetSubjects.find(
          item => normalizeScopeValue(item.subject) === normalizeScopeValue(subjectName),
        );
        if (!targetSubject) {
          targetSubject = { subject: subjectName, terms: [] };
          targetSubjects.push(targetSubject);
        }

        const terms = Array.isArray(rawSubject?.terms) ? rawSubject.terms : [];
        const targetTerms = Array.isArray(targetSubject.terms) ? targetSubject.terms : [];
        terms.forEach((rawTerm: any) => {
          const termName = cleanName(rawTerm?.term);
          if (!termName) return;
          let targetTerm = targetTerms.find(
            item => normalizeScopeValue(item.term) === normalizeScopeValue(termName),
          );
          if (!targetTerm) {
            targetTerm = { term: termName, units: [] };
            targetTerms.push(targetTerm);
          }
          targetTerm.units = uniqueNames([
            ...(targetTerm.units || []),
            ...(Array.isArray(rawTerm?.units) ? rawTerm.units : []),
          ]);
        });
        targetSubject.terms = targetTerms;
      });
      targetAtram.subjects = targetSubjects;
    });

    target.atrams = targetAtrams;
  });

  return Array.from(grouped.values());
};