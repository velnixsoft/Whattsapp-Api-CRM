import { NextResponse } from "next/server";
import { executeMySQLQuery, type QueryOptions } from "@/lib/db/mysql-engine";

export async function POST(request: Request) {
  try {
    const body: QueryOptions = await request.json();

    const result = await executeMySQLQuery(body);

    if (result.error) {
      return NextResponse.json(
        { error: result.error.message, code: result.error.code },
        { status: 400 }
      );
    }

    return NextResponse.json({
      data: result.data,
      count: result.count,
    });
  } catch (error: unknown) {
    const err = error as Error;
    console.error("[DB Query Route Error]:", err);
    return NextResponse.json(
      { error: err.message || "Query failed", stack: err.stack },
      { status: 500 }
    );
  }
}
