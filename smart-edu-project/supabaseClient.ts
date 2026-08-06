import { createClient } from "@supabase/supabase-js";

const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL || "").trim();
const supabaseAnonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY || "").trim();
const hasRealSupabaseConfig = Boolean(
  supabaseUrl &&
  supabaseAnonKey &&
  !supabaseUrl.includes("placeholder") &&
  !supabaseUrl.includes("example")
);

if (!hasRealSupabaseConfig) {
  console.warn(
    "تنبيه: مفاتيح Supabase غير معرفة أو غير صالحة، سيتم تعطيل المزامنة الخارجية مؤقتاً."
  );
}

const noopSupabase = {
  from: () => ({
    select: async () => ({ data: [], error: null }),
    upsert: async () => ({ data: [], error: null }),
    delete: () => ({
      in: async () => ({ data: [], error: null }),
    }),
  }),
};

export const supabase = hasRealSupabaseConfig
  ? createClient(supabaseUrl, supabaseAnonKey)
  : (noopSupabase as any);
