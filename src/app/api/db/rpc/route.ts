import { NextResponse } from "next/server";
import { executeMySQLRPC } from "@/lib/db/mysql-engine";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { name, params } = body;

    if (!name) {
      return NextResponse.json({ error: "RPC name is required" }, { status: 400 });
    }

    const result = await executeMySQLRPC(name, params || {});

    if (result.error) {
      return NextResponse.json(
        { error: result.error.message },
        { status: 400 }
      );
    }

    return NextResponse.json({
      data: result.data,
    });
  } catch (error: unknown) {
    const err = error as Error;
    console.error("[DB RPC Route Error]:", err);
    return NextResponse.json(
      { error: err.message || "RPC failed" },
      { status: 500 }
    );
  }
}
