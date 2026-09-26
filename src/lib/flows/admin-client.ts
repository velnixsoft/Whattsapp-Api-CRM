import { createMySQLServerClient } from "@/lib/supabase/server";

export function supabaseAdmin(): any {
  return createMySQLServerClient();
}
