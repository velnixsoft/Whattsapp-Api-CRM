import { NextResponse } from "next/server";
import { getSessionUser, SESSION_COOKIE_NAME } from "@/lib/auth/mysql-auth";
import { cookies } from "next/headers";

export async function GET() {
  const user = await getSessionUser();
  if (!user) {
    return NextResponse.json({ user: null, session: null });
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value || "";

  return NextResponse.json({
    user,
    session: {
      access_token: token,
      token_type: "bearer",
      user,
    },
  });
}
