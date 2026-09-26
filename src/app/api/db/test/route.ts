import { NextResponse } from "next/server";
import { testConnection, query } from "@/lib/db/mysql";

export async function GET() {
  const connTest = await testConnection();

  if (!connTest.success) {
    return NextResponse.json(
      {
        status: "error",
        message: "Failed to connect to MySQL (XAMPP). Make sure MySQL is running in XAMPP Control Panel.",
        error: connTest.message,
      },
      { status: 500 }
    );
  }

  try {
    const tables = await query<{ Tables_in_wacrm: string }>("SHOW TABLES;");
    const userCount = await query<{ count: number }>("SELECT COUNT(*) AS count FROM users;");
    const accountCount = await query<{ count: number }>("SELECT COUNT(*) AS count FROM accounts;");

    return NextResponse.json({
      status: "success",
      message: "Connected to MySQL successfully!",
      database: process.env.MYSQL_DATABASE || "wacrm",
      total_tables: tables.length,
      users_count: userCount[0]?.count ?? 0,
      accounts_count: accountCount[0]?.count ?? 0,
      tables: tables.map((t) => Object.values(t)[0]),
    });
  } catch (error: unknown) {
    const err = error as Error;
    return NextResponse.json(
      {
        status: "error",
        message: "Connected to MySQL, but encountered an error querying tables. Have you imported wacrm_mysql_xampp.sql in phpMyAdmin?",
        error: err.message,
      },
      { status: 500 }
    );
  }
}
