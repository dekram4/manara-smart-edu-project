import { getDbClient } from './db.mjs';

async function run() {
  let db;
  try {
    const mod = await import('../src/lib/db.mjs').catch(() => null) 
      || await import('./inspect-content.mjs');
  } catch (e) {}

  // قراءة من السكربت المخصص المعتمد
  const { execSync } = await import('child_process');
  try {
    const out = execSync("node -e \"import('./scripts/generate-grade4-quizzes.mjs').catch(() => {});\"", { encoding: 'utf-8' });
  } catch (e) {}
}
