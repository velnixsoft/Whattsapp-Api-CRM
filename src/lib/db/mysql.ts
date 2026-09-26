/* eslint-disable no-var */
import mysql from "mysql2/promise";

declare global {
  var _mysqlPool: mysql.Pool | undefined;
}

/**
 * Creates or retrieves the singleton MySQL connection pool.
 * Configured for local XAMPP MySQL / MariaDB by default.
 */
export function getMySQLPool(): mysql.Pool {
  if (!global._mysqlPool) {
    global._mysqlPool = mysql.createPool({
      host: process.env.MYSQL_HOST || "localhost",
      port: Number(process.env.MYSQL_PORT) || 3306,
      user: process.env.MYSQL_USER || "root",
      password: process.env.MYSQL_PASSWORD || "",
      database: process.env.MYSQL_DATABASE || "wacrm",
      waitForConnections: true,
      connectionLimit: 20,
      maxIdle: 10,
      idleTimeout: 60000,
      queueLimit: 0,
      decimalNumbers: true,
      dateStrings: true,
    });
  }
  return global._mysqlPool;
}

/**
 * Execute a parameterized query against MySQL
 */
export async function query<T = mysql.RowDataPacket>(
  sql: string,
  params?: unknown[] | Record<string, unknown>
): Promise<T[]> {
  const pool = getMySQLPool();
  if (params && Array.isArray(params) && params.length > 0) {
    const cleanParams = params.map((v) => (v === undefined ? null : v));
    const [rows] = await pool.query(sql, cleanParams as (string | number | boolean | null)[]);
    return rows as T[];
  }
  const [rows] = await pool.query(sql);
  return rows as T[];
}

/**
 * Execute an INSERT / UPDATE / DELETE command against MySQL
 */
export async function execute(
  sql: string,
  params?: unknown[] | Record<string, unknown>
): Promise<mysql.ResultSetHeader> {
  const pool = getMySQLPool();
  if (params && Array.isArray(params) && params.length > 0) {
    const cleanParams = params.map((v) => (v === undefined ? null : v));
    const [result] = await pool.execute(sql, cleanParams as (string | number | boolean | null)[]);
    return result as mysql.ResultSetHeader;
  }
  const [result] = await pool.execute(sql);
  return result as mysql.ResultSetHeader;
}

/**
 * Test MySQL connection
 */
export async function testConnection(): Promise<{ success: boolean; message: string }> {
  try {
    const pool = getMySQLPool();
    const connection = await pool.getConnection();
    connection.release();
    return { success: true, message: "Connected to MySQL successfully" };
  } catch (error: unknown) {
    const err = error as Error;
    return { success: false, message: err.message };
  }
}

/**
 * Helper to generate standard UUID v4 for primary keys
 */
export function generateUUID(): string {
  return crypto.randomUUID();
}
