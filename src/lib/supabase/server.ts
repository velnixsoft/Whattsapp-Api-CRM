import type { SupabaseClient } from "@supabase/supabase-js";
import { executeMySQLQuery, executeMySQLRPC, type QueryOptions } from "@/lib/db/mysql-engine";
import { getSessionUser } from "@/lib/auth/mysql-auth";

class ServerQueryBuilder implements PromiseLike<any> {
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
    return executeMySQLQuery(this.options);
  }

  then<TResult1 = any, TResult2 = never>(
    onfulfilled?: ((value: { data: any; error: any; count?: number | null }) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null
  ): Promise<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }
}

export function createMySQLServerClient(): SupabaseClient {
  const serverClient: any = {
    from: (table: string) => new ServerQueryBuilder(table),
    rpc: async (name: string, params?: Record<string, unknown>): Promise<{ data: any; error: any }> => {
      return executeMySQLRPC(name, params);
    },
    auth: {
      getUser: async (): Promise<{ data: { user: any }; error: any }> => {
        const user = await getSessionUser();
        if (!user) {
          return { data: { user: null }, error: { message: "Not authenticated", name: "AuthSessionMissingError" } };
        }
        return { data: { user }, error: null };
      },
      getSession: async (): Promise<{ data: { session: any }; error: any }> => {
        const user = await getSessionUser();
        if (!user) {
          return { data: { session: null }, error: null };
        }
        return {
          data: {
            session: {
              access_token: "mysql_session",
              user,
            },
          },
          error: null,
        };
      },
      signOut: async (_opts?: any) => ({ error: null }),
    },
    storage: {
      from: (bucket: string) => ({
        upload: async (path: string, _data: unknown, _opts?: any): Promise<{ data: any; error: any }> => {
          return { data: { path: `/uploads/${bucket}/${path}` }, error: null };
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
    },
    channel: (_name: string) => ({
      on: function (
        _event: string,
        _filter: any,
        _callback: (payload: any) => void
      ) {
        return this;
      },
      subscribe: function (cb?: (status: string) => void) {
        cb?.("SUBSCRIBED");
        return this;
      },
      unsubscribe: function () {
        return this;
      },
    }),
    removeChannel: (_channel: unknown) => {},
  };

  return serverClient as unknown as SupabaseClient;
}

export async function createClient(): Promise<SupabaseClient> {
  return createMySQLServerClient();
}

export function createServerClient(
  _url?: string,
  _key?: string,
  _options?: unknown
): SupabaseClient {
  return createMySQLServerClient();
}
