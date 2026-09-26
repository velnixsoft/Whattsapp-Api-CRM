import type { SupabaseClient, AuthChangeEvent, Session, RealtimeChannel } from "@supabase/supabase-js";
import type { QueryOptions } from "@/lib/db/mysql-engine";

type AuthListener = (event: AuthChangeEvent, session: Session | null) => void;
const authListeners: Set<AuthListener> = new Set();

function emitAuthChange(event: AuthChangeEvent, session: Session | null) {
  authListeners.forEach((listener) => {
    try {
      listener(event, session);
    } catch (e) {
      console.error("[AuthListener Error]", e);
    }
  });
}

class ClientQueryBuilder implements PromiseLike<any> {
  private options: QueryOptions;

  constructor(table: string) {
    this.options = {
      table,
      action: "select",
      columns: "*",
      filters: [],
      order: [],
    };
  }

  select(columns: string = "*", opts?: { count?: "exact"; head?: boolean }): this {
    this.options.action = "select";
    this.options.columns = columns;
    if (opts?.count) this.options.count = opts.count;
    if (opts?.head) this.options.head = opts.head;
    return this;
  }

  insert(data: any): this {
    this.options.action = "insert";
    this.options.data = data;
    return this;
  }

  update(data: any): this {
    this.options.action = "update";
    this.options.data = data;
    return this;
  }

  delete(): this {
    this.options.action = "delete";
    return this;
  }

  upsert(data: any, opts?: { onConflict?: string }): this {
    this.options.action = "upsert";
    this.options.data = data;
    if (opts?.onConflict) this.options.onConflict = opts.onConflict;
    return this;
  }

  eq(column: string, value: any): this {
    this.options.filters!.push({ column, op: "eq", value });
    return this;
  }

  neq(column: string, value: any): this {
    this.options.filters!.push({ column, op: "neq", value });
    return this;
  }

  in(column: string, value: any[]): this {
    this.options.filters!.push({ column, op: "in", value });
    return this;
  }

  is(column: string, value: any): this {
    this.options.filters!.push({ column, op: "is", value });
    return this;
  }

  like(column: string, value: any): this {
    this.options.filters!.push({ column, op: "like", value });
    return this;
  }

  ilike(column: string, value: any): this {
    this.options.filters!.push({ column, op: "ilike", value });
    return this;
  }

  gt(column: string, value: any): this {
    this.options.filters!.push({ column, op: "gt", value });
    return this;
  }

  gte(column: string, value: any): this {
    this.options.filters!.push({ column, op: "gte", value });
    return this;
  }

  lt(column: string, value: any): this {
    this.options.filters!.push({ column, op: "lt", value });
    return this;
  }

  lte(column: string, value: any): this {
    this.options.filters!.push({ column, op: "lte", value });
    return this;
  }

  contains(column: string, value: any): this {
    this.options.filters!.push({ column, op: "contains", value });
    return this;
  }

  or(value: string): this {
    this.options.filters!.push({ column: "", op: "or", value });
    return this;
  }

  order(column: string, opts?: { ascending?: boolean; nullsFirst?: boolean }): this {
    this.options.order!.push({
      column,
      ascending: opts?.ascending !== false,
      nullsFirst: opts?.nullsFirst,
    });
    return this;
  }

  limit(count: number): this {
    this.options.limit = count;
    return this;
  }

  range(from: number, to: number): this {
    this.options.offset = from;
    this.options.limit = to - from + 1;
    return this;
  }

  single(): this {
    this.options.single = true;
    return this;
  }

  maybeSingle(): this {
    this.options.maybeSingle = true;
    return this;
  }

  async execute(): Promise<{ data: any; error: any; count?: number | null }> {
    try {
      const res = await fetch("/api/db/query", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(this.options),
      });

      const json = await res.json();
      if (!res.ok || json.error) {
        return {
          data: null,
          error: { message: json.error || "Query failed", code: json.code },
          count: null,
        };
      }

      return {
        data: json.data,
        error: null,
        count: json.count,
      };
    } catch (err: unknown) {
      const error = err as Error;
      return {
        data: null,
        error: { message: error.message || "Network error" },
        count: null,
      };
    }
  }

  then<TResult1 = any, TResult2 = never>(
    onfulfilled?: ((value: { data: any; error: any; count?: number | null }) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): Promise<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }
}

class BrowserMySQLClient {
  supabaseUrl: string = process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000";
  supabaseKey: string = "mysql-client-key";

  from(table: string): any {
    return new ClientQueryBuilder(table);
  }

  async rpc(name: string, params?: Record<string, unknown>): Promise<{ data: any; error: any }> {
    try {
      const res = await fetch("/api/db/rpc", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, params }),
      });
      const json = await res.json();
      if (!res.ok || json.error) {
        return { data: null, error: { message: json.error || "RPC call failed" } };
      }
      return { data: json.data, error: null };
    } catch (err: unknown) {
      const error = err as Error;
      return { data: null, error: { message: error.message } };
    }
  }

  auth = {
    signInWithPassword: async ({ email, password }: { email: string; password: string }): Promise<{ data: any; error: any }> => {
      try {
        const res = await fetch("/api/auth/login", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email, password }),
        });
        const data = await res.json();
        if (!res.ok || data.error) {
          return { data: null, error: { message: data.error || "Sign in failed" } };
        }
        emitAuthChange("SIGNED_IN" as AuthChangeEvent, data.session);
        return { data, error: null };
      } catch (err: unknown) {
        const error = err as Error;
        return { data: null, error: { message: error.message } };
      }
    },

    signUp: async ({
      email,
      password,
      options,
    }: {
      email: string;
      password: string;
      options?: { data?: { full_name?: string }; emailRedirectTo?: string };
    }): Promise<{ data: any; error: any }> => {
      try {
        const res = await fetch("/api/auth/signup", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            email,
            password,
            full_name: options?.data?.full_name || "",
          }),
        });
        const data = await res.json();
        if (!res.ok || data.error) {
          return { data: null, error: { message: data.error || "Sign up failed" } };
        }
        emitAuthChange("SIGNED_IN" as AuthChangeEvent, data.session);
        return { data, error: null };
      } catch (err: unknown) {
        const error = err as Error;
        return { data: null, error: { message: error.message } };
      }
    },

    signOut: async (_options?: any): Promise<{ error: any }> => {
      try {
        await fetch("/api/auth/logout", { method: "POST" });
        emitAuthChange("SIGNED_OUT" as AuthChangeEvent, null);
        return { error: null };
      } catch (err: unknown) {
        const error = err as Error;
        return { error: { message: error.message } };
      }
    },

    getSession: async (): Promise<{ data: { session: Session | null }; error: any }> => {
      try {
        const res = await fetch("/api/auth/session");
        const data = await res.json();
        return {
          data: {
            session: data.session || null,
          },
          error: null,
        };
      } catch {
        return { data: { session: null }, error: null };
      }
    },

    getUser: async (): Promise<{ data: { user: any }; error: any }> => {
      try {
        const res = await fetch("/api/auth/session");
        const data = await res.json();
        return {
          data: {
            user: data.user || null,
          },
          error: null,
        };
      } catch {
        return { data: { user: null }, error: null };
      }
    },

    onAuthStateChange: (
      callback: (event: AuthChangeEvent, session: Session | null) => void
    ): { data: { subscription: { unsubscribe: () => void } } } => {
      const listener: AuthListener = (event, session) => {
        callback(event, session);
      };
      authListeners.add(listener);

      return {
        data: {
          subscription: {
            unsubscribe: () => {
              authListeners.delete(listener);
            },
          },
        },
      };
    },

    resetPasswordForEmail: async (_email: string, _opts?: unknown): Promise<{ data: any; error: any }> => {
      return { data: {}, error: null };
    },

    updateUser: async (_attributes: Record<string, unknown>): Promise<{ data: any; error: any }> => {
      return { data: {}, error: null };
    },
  };

  storage = {
    from: (bucket: string): any => ({
      upload: async (path: string, file: File | Blob, _opts?: any): Promise<{ data: any; error: any }> => {
        try {
          const formData = new FormData();
          formData.append("file", file);
          formData.append("bucket", bucket);
          formData.append("path", path);

          const res = await fetch("/api/storage/upload", {
            method: "POST",
            body: formData,
          });
          const data = await res.json();
          if (!res.ok || data.error) {
            return { data: null, error: { message: data.error || "Upload failed" } };
          }
          return { data: { path: data.path }, error: null };
        } catch (err: unknown) {
          const error = err as Error;
          return { data: null, error: { message: error.message } };
        }
      },
      getPublicUrl: (path: string) => {
        return { data: { publicUrl: `/uploads/${bucket}/${path}` } };
      },
      download: async (_path: string): Promise<{ data: any; error: any }> => {
        return { data: null, error: null };
      },
      remove: async (_paths: string[]): Promise<{ data: any; error: any }> => {
        return { data: null, error: null };
      },
    }),
  };

  channel(_name: string): RealtimeChannel {
    const channelObj: any = {
      on: function (
        _event: string,
        _filter: any,
        _callback: (payload: any) => void
      ) {
        return channelObj;
      },
      subscribe: function (cb?: (status: string) => void) {
        if (cb) setTimeout(() => cb("SUBSCRIBED"), 10);
        return channelObj;
      },
      unsubscribe: function () {},
    };
    return channelObj as unknown as RealtimeChannel;
  }

  removeChannel(_channel: unknown) {}
}

let browserClient: BrowserMySQLClient | undefined;

export function createClient(): SupabaseClient {
  if (!browserClient) {
    browserClient = new BrowserMySQLClient();
  }
  return browserClient as unknown as SupabaseClient;
}

export function createBrowserClient(_url?: string, _key?: string): SupabaseClient {
  return createClient();
}
