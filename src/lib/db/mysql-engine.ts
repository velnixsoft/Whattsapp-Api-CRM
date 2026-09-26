import { query, execute, generateUUID, getMySQLPool } from "@/lib/db/mysql";

export interface FilterCondition {
  column: string;
  op:
    | "eq"
    | "neq"
    | "in"
    | "is"
    | "like"
    | "ilike"
    | "gt"
    | "gte"
    | "lt"
    | "lte"
    | "contains"
    | "or";
  value: unknown;
}

export interface OrderCondition {
  column: string;
  ascending?: boolean;
  nullsFirst?: boolean;
}

export interface QueryOptions {
  table: string;
  action: "select" | "insert" | "update" | "delete" | "upsert";
  columns?: string;
  data?: Record<string, unknown> | Record<string, unknown>[];
  filters?: FilterCondition[];
  order?: OrderCondition[];
  limit?: number;
  offset?: number;
  single?: boolean;
  maybeSingle?: boolean;
  count?: "exact" | null;
  head?: boolean;
  onConflict?: string;
}

export interface QueryResult<T = unknown> {
  data: T | null;
  error: { message: string; code?: string; details?: string } | null;
  count?: number | null;
}

/**
 * Parses relation embeds from columns string.
 * Example: "id, name, contact:contacts(*), stage:pipeline_stages(id, name)"
 */
function parseColumnsAndEmbeds(columnsStr: string = "*") {
  const pureColumns: string[] = [];
  const embeds: Array<{ alias: string; targetTable: string; subColumns: string }> = [];

  // Match embedded relations like `contact:contacts(*)` or `pipeline_stages(*)`
  const parts: string[] = [];
  let depth = 0;
  let current = "";

  for (let i = 0; i < columnsStr.length; i++) {
    const char = columnsStr[i];
    if (char === "(") depth++;
    else if (char === ")") depth--;

    if (char === "," && depth === 0) {
      parts.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  if (current.trim()) {
    parts.push(current.trim());
  }

  for (const part of parts) {
    const embedMatch = part.match(/^(?:([a-zA-Z0-9_]+):)?([a-zA-Z0-9_]+)(?:![a-zA-Z0-9_]+)?\((.*)\)$/);
    if (embedMatch) {
      const alias = embedMatch[1] || embedMatch[2];
      const targetTable = embedMatch[2];
      const subColumns = embedMatch[3] || "*";
      embeds.push({ alias, targetTable, subColumns });
    } else {
      pureColumns.push(part);
    }
  }

  return {
    pureColumns: pureColumns.length > 0 ? pureColumns.join(", ") : "*",
    embeds,
  };
}

/**
 * Builds WHERE SQL clause and parameters
 */
function buildWhereClause(filters: FilterCondition[] = []): {
  whereSql: string;
  params: unknown[];
} {
  if (!filters || filters.length === 0) {
    return { whereSql: "", params: [] };
  }

  const clauses: string[] = [];
  const params: unknown[] = [];

  for (const f of filters) {
    const col = f.column.includes("`") ? f.column : `\`${f.column.replace(/`/g, "")}\``;

    switch (f.op) {
      case "eq":
        if (f.value === null) {
          clauses.push(`${col} IS NULL`);
        } else {
          clauses.push(`${col} = ?`);
          params.push(f.value);
        }
        break;
      case "neq":
        if (f.value === null) {
          clauses.push(`${col} IS NOT NULL`);
        } else {
          clauses.push(`${col} != ?`);
          params.push(f.value);
        }
        break;
      case "in": {
        const arr = Array.isArray(f.value) ? f.value : [f.value];
        if (arr.length === 0) {
          clauses.push("1 = 0");
        } else {
          const placeholders = arr.map(() => "?").join(", ");
          clauses.push(`${col} IN (${placeholders})`);
          params.push(...arr);
        }
        break;
      }
      case "is":
        if (f.value === null) {
          clauses.push(`${col} IS NULL`);
        } else if (f.value === true) {
          clauses.push(`${col} IS TRUE`);
        } else if (f.value === false) {
          clauses.push(`${col} IS FALSE`);
        } else {
          clauses.push(`${col} = ?`);
          params.push(f.value);
        }
        break;
      case "like":
      case "ilike":
        clauses.push(`${col} LIKE ?`);
        params.push(f.value);
        break;
      case "gt":
        clauses.push(`${col} > ?`);
        params.push(f.value);
        break;
      case "gte":
        clauses.push(`${col} >= ?`);
        params.push(f.value);
        break;
      case "lt":
        clauses.push(`${col} < ?`);
        params.push(f.value);
        break;
      case "lte":
        clauses.push(`${col} <= ?`);
        params.push(f.value);
        break;
      case "contains":
        clauses.push(`JSON_CONTAINS(${col}, ?)`);
        params.push(JSON.stringify(f.value));
        break;
      case "or":
        // Raw or expression e.g. "status.eq.open,status.eq.pending"
        if (typeof f.value === "string") {
          const orParts = f.value.split(",");
          const subClauses: string[] = [];
          for (const part of orParts) {
            const [orCol, orOp, orVal] = part.split(".");
            if (orCol && orOp) {
              const safeCol = `\`${orCol.replace(/`/g, "")}\``;
              if (orOp === "eq") {
                subClauses.push(`${safeCol} = ?`);
                params.push(orVal === "null" ? null : orVal);
              } else if (orOp === "neq") {
                subClauses.push(`${safeCol} != ?`);
                params.push(orVal === "null" ? null : orVal);
              } else if (orOp === "ilike" || orOp === "like") {
                subClauses.push(`${safeCol} LIKE ?`);
                params.push(orVal);
              }
            }
          }
          if (subClauses.length > 0) {
            clauses.push(`(${subClauses.join(" OR ")})`);
          }
        }
        break;
    }
  }

  return {
    whereSql: clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "",
    params,
  };
}

/**
 * Hydrates relational embeds on result rows
 */
async function hydrateEmbeds(
  table: string,
  rows: Record<string, unknown>[],
  embeds: Array<{ alias: string; targetTable: string; subColumns: string }>
) {
  if (rows.length === 0 || embeds.length === 0) return rows;

  for (const embed of embeds) {
    const { alias, targetTable } = embed;

    // Direct 1-to-many or 1-to-1 relations
    if (targetTable === "contacts" && (table === "conversations" || table === "deals" || table === "broadcast_recipients" || table === "automation_logs" || table === "flow_runs")) {
      const contactIds = Array.from(new Set(rows.map((r) => r.contact_id).filter(Boolean))) as string[];
      if (contactIds.length > 0) {
        const placeholders = contactIds.map(() => "?").join(", ");
        const contacts = await query<Record<string, unknown>>(
          `SELECT * FROM \`contacts\` WHERE \`id\` IN (${placeholders});`,
          contactIds
        );
        const contactMap = new Map(contacts.map((c) => [c.id, c]));

        // Check if contact itself needs tags embedded (e.g. contact_tags(tags(*)))
        if (embed.subColumns.includes("contact_tags") || embed.subColumns.includes("tags")) {
          const cTags = await query<{ contact_id: string; tag_id: string; id: string; name: string; color: string }>(
            `SELECT ct.contact_id, ct.tag_id, t.id, t.name, t.color FROM contact_tags ct JOIN tags t ON t.id = ct.tag_id WHERE ct.contact_id IN (${placeholders});`,
            contactIds
          );
          const tagMap = new Map<string, Array<{ tag: { id: string; name: string; color: string } }>>();
          for (const ct of cTags) {
            if (!tagMap.has(ct.contact_id)) tagMap.set(ct.contact_id, []);
            tagMap.get(ct.contact_id)!.push({ tag: { id: ct.id, name: ct.name, color: ct.color } });
          }
          for (const c of contacts) {
            c.contact_tags = tagMap.get(c.id as string) || [];
          }
        }

        for (const row of rows) {
          row[alias] = contactMap.get(row.contact_id as string) || null;
        }
      } else {
        for (const row of rows) row[alias] = null;
      }
    } else if (targetTable === "pipeline_stages" && table === "deals") {
      const stageIds = Array.from(new Set(rows.map((r) => r.stage_id).filter(Boolean))) as string[];
      if (stageIds.length > 0) {
        const placeholders = stageIds.map(() => "?").join(", ");
        const stages = await query<Record<string, unknown>>(
          `SELECT * FROM \`pipeline_stages\` WHERE \`id\` IN (${placeholders});`,
          stageIds
        );
        const stageMap = new Map(stages.map((s) => [s.id, s]));
        for (const row of rows) {
          row[alias] = stageMap.get(row.stage_id as string) || null;
        }
      } else {
        for (const row of rows) row[alias] = null;
      }
    } else if (targetTable === "profiles" && table === "deals") {
      const userIds = Array.from(new Set(rows.map((r) => r.assigned_to).filter(Boolean))) as string[];
      if (userIds.length > 0) {
        const placeholders = userIds.map(() => "?").join(", ");
        const profiles = await query<Record<string, unknown>>(
          `SELECT * FROM \`profiles\` WHERE \`user_id\` IN (${placeholders}) OR \`id\` IN (${placeholders});`,
          [...userIds, ...userIds]
        );
        const profileMap = new Map(profiles.map((p) => [p.user_id, p]));
        for (const row of rows) {
          row[alias] = profileMap.get(row.assigned_to as string) || null;
        }
      } else {
        for (const row of rows) row[alias] = null;
      }
    } else if (targetTable === "automations" && table === "automation_logs") {
      const autoIds = Array.from(new Set(rows.map((r) => r.automation_id).filter(Boolean))) as string[];
      if (autoIds.length > 0) {
        const placeholders = autoIds.map(() => "?").join(", ");
        const automations = await query<Record<string, unknown>>(
          `SELECT * FROM \`automations\` WHERE \`id\` IN (${placeholders});`,
          autoIds
        );
        const map = new Map(automations.map((a) => [a.id, a]));
        for (const row of rows) {
          row[alias] = map.get(row.automation_id as string) || null;
        }
      } else {
        for (const row of rows) row[alias] = null;
      }
    } else if (targetTable === "pipeline_stages" && table === "pipelines") {
      const pipelineIds = rows.map((r) => r.id as string).filter(Boolean);
      if (pipelineIds.length > 0) {
        const placeholders = pipelineIds.map(() => "?").join(", ");
        const stages = await query<Record<string, unknown>>(
          `SELECT * FROM \`pipeline_stages\` WHERE \`pipeline_id\` IN (${placeholders}) ORDER BY \`position\` ASC;`,
          pipelineIds
        );
        const stagesMap = new Map<string, Record<string, unknown>[]>();
        for (const stage of stages) {
          const pid = stage.pipeline_id as string;
          if (!stagesMap.has(pid)) stagesMap.set(pid, []);
          stagesMap.get(pid)!.push(stage);
        }
        for (const row of rows) {
          row[alias] = stagesMap.get(row.id as string) || [];
        }
      }
    } else if (targetTable === "contact_tags" && table === "contacts") {
      const contactIds = rows.map((r) => r.id as string).filter(Boolean);
      if (contactIds.length > 0) {
        const placeholders = contactIds.map(() => "?").join(", ");
        const cTags = await query<{ contact_id: string; tag_id: string; id: string; name: string; color: string }>(
          `SELECT ct.contact_id, ct.tag_id, t.id, t.name, t.color FROM contact_tags ct JOIN tags t ON t.id = ct.tag_id WHERE ct.contact_id IN (${placeholders});`,
          contactIds
        );
        const tagMap = new Map<string, Array<{ tag: { id: string; name: string; color: string } }>>();
        for (const ct of cTags) {
          if (!tagMap.has(ct.contact_id)) tagMap.set(ct.contact_id, []);
          tagMap.get(ct.contact_id)!.push({ tag: { id: ct.id, name: ct.name, color: ct.color } });
        }
        for (const row of rows) {
          row[alias] = tagMap.get(row.id as string) || [];
        }
      }
    }
  }

  return rows;
}

/**
 * Execute a query definition against MySQL
 */
export async function executeMySQLQuery<T = unknown>(options: QueryOptions): Promise<QueryResult<T>> {
  const { table, action, columns = "*", data, filters = [], order = [], limit, offset, single, maybeSingle, count, head, onConflict } = options;

  const safeTable = `\`${table.replace(/`/g, "")}\``;

  try {
    if (action === "select") {
      const { pureColumns, embeds } = parseColumnsAndEmbeds(columns);
      const { whereSql, params } = buildWhereClause(filters);

      let totalCount: number | null = null;
      if (count === "exact") {
        const countSql = `SELECT COUNT(*) AS total FROM ${safeTable} ${whereSql};`;
        const countRows = await query<{ total: number }>(countSql, params);
        totalCount = countRows[0]?.total ?? 0;

        if (head) {
          return { data: null, error: null, count: totalCount };
        }
      }

      let orderSql = "";
      if (order.length > 0) {
        const orderParts = order.map((o) => {
          const col = o.column.includes("`") ? o.column : `\`${o.column.replace(/`/g, "")}\``;
          return `${col} ${o.ascending === false ? "DESC" : "ASC"}`;
        });
        orderSql = `ORDER BY ${orderParts.join(", ")}`;
      }

      let limitSql = "";
      if (typeof limit === "number") {
        limitSql = `LIMIT ${limit}`;
        if (typeof offset === "number") {
          limitSql += ` OFFSET ${offset}`;
        }
      }

      const selectCols = pureColumns === "*" || pureColumns === "" ? "*" : pureColumns;
      const sql = `SELECT ${selectCols} FROM ${safeTable} ${whereSql} ${orderSql} ${limitSql};`;
      const rawRows = await query<Record<string, unknown>>(sql, params);

      // Hydrate relational embeds if any
      const rows = await hydrateEmbeds(table, rawRows, embeds);

      if (single) {
        if (rows.length === 0) {
          return { data: null, error: { message: "JSON object requested, multiple (or no) rows returned", code: "PGRST116" }, count: totalCount };
        }
        return { data: rows[0] as T, error: null, count: totalCount };
      }

      if (maybeSingle) {
        return { data: (rows[0] ?? null) as T, error: null, count: totalCount };
      }

      return { data: rows as T, error: null, count: totalCount };
    }

    if (action === "insert") {
      const items = Array.isArray(data) ? data : data ? [data] : [];
      if (items.length === 0) {
        return { data: ([] as unknown) as T, error: null };
      }

      const insertedRows: Record<string, unknown>[] = [];

      for (const item of items) {
        const record = { ...item };
        if (!record.id) {
          record.id = generateUUID();
        }

        const keys = Object.keys(record);
        const colNames = keys.map((k) => `\`${k.replace(/`/g, "")}\``).join(", ");
        const placeholders = keys.map(() => "?").join(", ");
        const values = keys.map((k) => {
          const val = record[k];
          if (val !== null && typeof val === "object" && !(val instanceof Date)) {
            return JSON.stringify(val);
          }
          return val;
        });

        const insertSql = `INSERT INTO ${safeTable} (${colNames}) VALUES (${placeholders});`;
        await execute(insertSql, values);
        insertedRows.push(record);
      }

      if (single) {
        return { data: (insertedRows[0] || null) as T, error: null };
      }
      return { data: (Array.isArray(data) ? insertedRows : insertedRows[0]) as T, error: null };
    }

    if (action === "update") {
      const { whereSql, params } = buildWhereClause(filters);
      if (!data || Object.keys(data).length === 0) {
        return { data: null, error: { message: "No update data provided" } };
      }

      const keys = Object.keys(data);
      const setParts = keys.map((k) => `\`${k.replace(/`/g, "")}\` = ?`).join(", ");
      const values = keys.map((k) => {
        const val = (data as Record<string, unknown>)[k];
        if (val !== null && typeof val === "object" && !(val instanceof Date)) {
          return JSON.stringify(val);
        }
        return val;
      });

      const updateSql = `UPDATE ${safeTable} SET ${setParts} ${whereSql};`;
      await execute(updateSql, [...values, ...params]);

      // Select updated records to return
      const selectSql = `SELECT * FROM ${safeTable} ${whereSql};`;
      const updatedRows = await query<Record<string, unknown>>(selectSql, params);

      if (single) {
        return { data: (updatedRows[0] || null) as T, error: null };
      }
      if (maybeSingle) {
        return { data: (updatedRows[0] ?? null) as T, error: null };
      }
      return { data: updatedRows as T, error: null };
    }

    if (action === "delete") {
      const { whereSql, params } = buildWhereClause(filters);
      // Fetch rows before delete so we can return them if requested
      const selectSql = `SELECT * FROM ${safeTable} ${whereSql};`;
      const rowsToDelete = await query<Record<string, unknown>>(selectSql, params);

      const deleteSql = `DELETE FROM ${safeTable} ${whereSql};`;
      await execute(deleteSql, params);

      return { data: rowsToDelete as T, error: null };
    }

    if (action === "upsert") {
      const items = Array.isArray(data) ? data : data ? [data] : [];
      if (items.length === 0) {
        return { data: ([] as unknown) as T, error: null };
      }

      const upsertedRows: Record<string, unknown>[] = [];

      for (const item of items) {
        const record = { ...item };
        if (!record.id && !onConflict) {
          record.id = generateUUID();
        }

        const keys = Object.keys(record);
        const colNames = keys.map((k) => `\`${k.replace(/`/g, "")}\``).join(", ");
        const placeholders = keys.map(() => "?").join(", ");
        const values = keys.map((k) => {
          const val = record[k];
          if (val !== null && typeof val === "object" && !(val instanceof Date)) {
            return JSON.stringify(val);
          }
          return val;
        });

        const updateAssignments = keys
          .filter((k) => k !== "id")
          .map((k) => `\`${k.replace(/`/g, "")}\` = VALUES(\`${k.replace(/`/g, "")}\`)`)
          .join(", ");

        const upsertSql = `INSERT INTO ${safeTable} (${colNames}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE ${updateAssignments || "id = id"};`;
        await execute(upsertSql, values);
        upsertedRows.push(record);
      }

      if (single) {
        return { data: (upsertedRows[0] || null) as T, error: null };
      }
      return { data: (Array.isArray(data) ? upsertedRows : upsertedRows[0]) as T, error: null };
    }

    return { data: null, error: { message: `Unsupported action: ${action}` } };
  } catch (err: unknown) {
    const error = err as Error;
    console.error(`[MySQL Engine] Error in ${action} on ${table}:`, error);
    return { data: null, error: { message: error.message } };
  }
}

/**
 * Execute Stored Procedure / Custom RPC
 */
export async function executeMySQLRPC<T = unknown>(
  name: string,
  params: Record<string, unknown> = {}
): Promise<QueryResult<T>> {
  try {
    switch (name) {
      case "increment_automation_counter":
      case "increment_automation_execution_count": {
        const autoId = (params.p_automation_id || params.automation_id || params.id) as string;
        await execute("CALL increment_automation_counter(?);", [autoId]);
        return { data: (null as unknown) as T, error: null };
      }
      case "increment_flow_counter":
      case "increment_flow_execution_count": {
        const flowId = (params.p_flow_id || params.flow_id || params.id) as string;
        await execute("CALL increment_flow_counter(?);", [flowId]);
        return { data: (null as unknown) as T, error: null };
      }
      case "filter_contacts_by_tags": {
        const accountId = params.p_account_id as string;
        const tagIds = Array.isArray(params.p_tag_ids) ? JSON.stringify(params.p_tag_ids) : (params.p_tag_ids as string);
        const matchAll = Boolean(params.p_match_all);
        const rows = await query<Record<string, unknown>>("CALL filter_contacts_by_tags(?, ?, ?);", [
          accountId,
          tagIds,
          matchAll,
        ]);
        return { data: (rows as unknown) as T, error: null };
      }
      case "touch_presence": {
        const userId = params.p_user_id as string;
        const accountId = params.p_account_id as string;
        const status = (params.p_status || "online") as string;
        const id = generateUUID();
        await execute(
          `INSERT INTO member_presence (id, user_id, account_id, status, last_seen_at, created_at, updated_at)
           VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3))
           ON DUPLICATE KEY UPDATE status = VALUES(status), last_seen_at = CURRENT_TIMESTAMP(3), updated_at = CURRENT_TIMESTAMP(3);`,
          [id, userId, accountId, status]
        );
        return { data: (null as unknown) as T, error: null };
      }
      case "claim_account_invitation":
      case "redeem_invitation": {
        const tokenHash = (params.p_token_hash || params.token_hash) as string;
        const userId = (params.p_user_id || params.user_id) as string;
        await execute("CALL claim_account_invitation(?, ?);", [tokenHash, userId]);
        const invites = await query<{ account_id: string }>("SELECT account_id FROM account_invitations WHERE token_hash = ? LIMIT 1;", [tokenHash]);
        return { data: (invites[0]?.account_id || null) as unknown as T, error: null };
      }
      case "peek_invitation": {
        const tokenHash = (params.p_token_hash || params.token_hash) as string;
        const rows = await query<{ account_name: string; role: string; email: string }>(
          `SELECT a.name AS account_name, i.role, u.email
           FROM account_invitations i
           JOIN accounts a ON a.id = i.account_id
           LEFT JOIN users u ON u.id = i.created_by_user_id
           WHERE i.token_hash = ? AND i.accepted_at IS NULL AND i.expires_at > CURRENT_TIMESTAMP(3)
           LIMIT 1;`,
          [tokenHash]
        );
        return { data: (rows[0] || null) as unknown as T, error: null };
      }
      case "transfer_account_ownership": {
        const accountId = params.p_account_id as string;
        const newOwnerUserId = params.p_new_owner_user_id as string;
        const currentUserId = params.p_current_user_id as string;
        await execute("UPDATE accounts SET owner_user_id = ? WHERE id = ?;", [newOwnerUserId, accountId]);
        await execute("UPDATE profiles SET account_role = 'admin' WHERE user_id = ? AND account_id = ?;", [currentUserId, accountId]);
        await execute("UPDATE profiles SET account_role = 'owner' WHERE user_id = ? AND account_id = ?;", [newOwnerUserId, accountId]);
        return { data: (null as unknown) as T, error: null };
      }
      case "set_member_role": {
        const targetUserId = params.p_target_user_id as string;
        const accountId = params.p_account_id as string;
        const role = params.p_new_role as string;
        await execute("UPDATE profiles SET account_role = ? WHERE user_id = ? AND account_id = ?;", [role, targetUserId, accountId]);
        return { data: (null as unknown) as T, error: null };
      }
      case "remove_account_member": {
        const targetUserId = params.p_target_user_id as string;
        const accountId = params.p_account_id as string;
        await execute("UPDATE profiles SET account_id = NULL, account_role = NULL WHERE user_id = ? AND account_id = ?;", [targetUserId, accountId]);
        return { data: (null as unknown) as T, error: null };
      }
      case "record_webhook_failure": {
        return { data: (null as unknown) as T, error: null };
      }
      default: {
        const paramVals = Object.values(params);
        const placeholders = paramVals.map(() => "?").join(", ");
        const rows = await query(`CALL \`${name.replace(/`/g, "")}\`(${placeholders});`, paramVals);
        return { data: (rows as unknown) as T, error: null };
      }
    }
  } catch (err: unknown) {
    const error = err as Error;
    console.error(`[MySQL Engine] RPC Error in ${name}:`, error);
    return { data: null, error: { message: error.message } };
  }
}
