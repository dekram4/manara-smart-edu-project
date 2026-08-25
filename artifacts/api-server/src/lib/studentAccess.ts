import crypto from "node:crypto";

export type StudentActor = {
  id: string;
  name: string;
  username: string;
  password: unknown;
  teacherId: string;
  grade: string;
  atram: string;
  subject: string;
  term: string;
  unit: string;
  canAccessChat: boolean;
};

export type StudentSupabaseConfig = { url: string; key: string };

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalize(value: unknown): string {
  return text(value).toLowerCase();
}

function config(): StudentSupabaseConfig | null {
  const url = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim() ||
    process.env.SUPABASE_ANON_KEY?.trim();
  return url && key ? { url, key } : null;
}

async function readStudents(filter: string): Promise<Array<{ id?: unknown; data?: unknown }>> {
  const settings = config();
  if (!settings) throw new Error("Supabase credentials are required");
  const response = await fetch(`${settings.url}/rest/v1/students?select=id,data&${filter}`, {
    headers: { apikey: settings.key, Authorization: `Bearer ${settings.key}` },
  });
  if (!response.ok) throw new Error(`Student lookup failed (${response.status})`);
  const rows = await response.json();
  return Array.isArray(rows) ? rows : [];
}

function fromRow(row: { id?: unknown; data?: unknown }): StudentActor | null {
  const data = row.data && typeof row.data === "object"
    ? row.data as Record<string, unknown>
    : {};
  const id = text(data.id) || text(row.id);
  if (!id) return null;
  const role = normalize(data.role);
  if (role && role !== "student" && role !== "طالب") return null;
  return {
    id,
    name: text(data.name) || text(data.fullName) || "طالب منارة",
    username: text(data.username),
    password: data.password,
    teacherId: normalize(data.teacherId ?? data.teacher_id),
    grade: text(data.grade),
    atram: text(data.atram),
    subject: text(data.subject),
    term: text(data.term),
    unit: text(data.unit),
    canAccessChat: data.canAccessChat !== false && data.can_access_chat !== false,
  };
}

export async function findStudentByUsername(username: string): Promise<StudentActor | null> {
  const safeUsername = text(username);
  if (!safeUsername) return null;
  const rows = await readStudents(`data->>username=eq.${encodeURIComponent(safeUsername)}`);
  const direct = rows.map(fromRow).find((student): student is StudentActor =>
    Boolean(student && student.username === safeUsername),
  );
  if (direct) return direct;
  // The legacy dashboard permits a student number in the username field.
  // Keep that convenience, but resolve it only on the trusted server.
  const allRows = await readStudents("limit=500");
  return allRows.map((row) => {
    const student = fromRow(row);
    const data = row.data && typeof row.data === "object" ? row.data as Record<string, unknown> : {};
    return text(data.studentIdNumber) === safeUsername || text(data.student_id_number) === safeUsername
      ? student
      : null;
  }).find((student): student is StudentActor => Boolean(student)) ?? null;
}

export async function findStudentById(id: string): Promise<StudentActor | null> {
  const safeId = text(id);
  if (!safeId) return null;
  const rows = await readStudents(`id=eq.${encodeURIComponent(safeId)}`);
  // Flutter's profile intentionally uses the stable table row id. Some legacy
  // records also have a different id inside their JSON data, which becomes the
  // canonical actor id after lookup. Either identifier must resolve this row.
  const direct = rows.map((row) => {
    const student = fromRow(row);
    return student && (text(row.id) === safeId || student.id === safeId)
      ? student
      : null;
  }).find((student): student is StudentActor => Boolean(student));
  if (direct) return direct;
  const dataRows = await readStudents(`data->>id=eq.${encodeURIComponent(safeId)}`);
  return dataRows.map(fromRow).find((student): student is StudentActor =>
    Boolean(student && student.id === safeId),
  ) ?? null;
}

export async function findStudentsInScope(
  grade: string,
  teacherId: string,
): Promise<StudentActor[]> {
  const rows = await readStudents("limit=500");
  return rows.map(fromRow).filter((student): student is StudentActor =>
    Boolean(student && normalize(student.grade) === normalize(grade) &&
      normalize(student.teacherId) === normalize(teacherId) && student.canAccessChat),
  );
}

export function passwordsMatch(input: string, stored: unknown): boolean {
  if (typeof stored !== "string" || !stored) return false;
  // Existing student records may use either a SHA-256 digest or the legacy
  // plaintext format used by the original Supabase student login.
  if (!/^[a-f0-9]{64}$/i.test(stored)) return input === stored;
  const expected = stored.toLowerCase();
  const received = crypto.createHash("sha256").update(input).digest("hex");
  return crypto.timingSafeEqual(Buffer.from(expected, "utf8"), Buffer.from(received, "utf8"));
}

export function matchesStudentScope(
  record: Record<string, unknown>,
  student: StudentActor,
): boolean {
  const owner = normalize(record.teacher_id ?? record.teacherId ?? record.createdBy);
  if (owner && owner !== "admin" && owner !== "supervisor" && owner !== student.teacherId) {
    return false;
  }
  for (const key of ["grade", "atram", "subject", "term", "unit"] as const) {
    const expected = normalize(student[key]);
    const actual = normalize(record[key]);
    if (expected && actual && expected !== actual) return false;
  }
  return true;
}

export function studentToken(studentId: string, ttlSeconds = 60 * 60 * 12): string {
  const secret = process.env.SESSION_SECRET;
  if (!secret) throw new Error("SESSION_SECRET is required");
  const encoded = Buffer.from(JSON.stringify({
    role: "student",
    studentId,
    expiresAt: Date.now() + ttlSeconds * 1000,
  })).toString("base64url");
  const signature = crypto.createHmac("sha256", secret).update(encoded).digest("base64url");
  return `${encoded}.${signature}`;
}

export function verifyStudentToken(value: string): string | null {
  const secret = process.env.SESSION_SECRET;
  const [encoded, signature] = String(value || "").split(".");
  if (!secret || !encoded || !signature) return null;
  const expected = crypto.createHmac("sha256", secret).update(encoded).digest("base64url");
  if (signature.length !== expected.length ||
      !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) return null;
  try {
    const payload = JSON.parse(Buffer.from(encoded, "base64url").toString("utf8"));
    const studentId = text(payload?.studentId);
    return payload?.role === "student" && studentId && Number(payload?.expiresAt) > Date.now()
      ? studentId
      : null;
  } catch {
    return null;
  }
}

export function apiSupabaseConfig(): StudentSupabaseConfig | null {
  return config();
}