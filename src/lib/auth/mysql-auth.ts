import bcrypt from "bcryptjs";
import * as jose from "jose";
import { query, execute, generateUUID } from "@/lib/db/mysql";
import { cookies } from "next/headers";

export const SESSION_COOKIE_NAME = "wacrm_session";
const JWT_SECRET_STRING =
  process.env.AUTH_SECRET ||
  process.env.ENCRYPTION_KEY ||
  "wacrm-default-local-jwt-secret-key-32chars";

const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_STRING);

export interface AuthUser {
  id: string;
  email: string;
  user_metadata?: {
    full_name?: string;
    [key: string]: unknown;
  };
  created_at?: string;
}

export interface AuthSession {
  access_token: string;
  token_type: string;
  expires_in: number;
  user: AuthUser;
}

/**
 * Hash a plain text password with bcrypt
 */
export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

/**
 * Compare password with bcrypt hash
 */
export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  if (!hash) return false;
  try {
    return await bcrypt.compare(password, hash);
  } catch {
    return false;
  }
}

/**
 * Sign a JWT token for a user session
 */
export async function signJWT(user: { id: string; email: string; full_name?: string }): Promise<string> {
  return new jose.SignJWT({
    sub: user.id,
    email: user.email,
    name: user.full_name || "",
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(JWT_SECRET);
}

/**
 * Verify a JWT token
 */
export async function verifyJWT(token: string): Promise<{ sub: string; email: string; name?: string } | null> {
  try {
    const { payload } = await jose.jwtVerify(token, JWT_SECRET);
    if (!payload.sub || typeof payload.sub !== "string") return null;
    return {
      sub: payload.sub,
      email: (payload.email as string) || "",
      name: (payload.name as string) || "",
    };
  } catch {
    return null;
  }
}

/**
 * Authenticate user with email and password
 */
export async function loginWithEmailPassword(
  email: string,
  password: string
): Promise<{ user: AuthUser; session: AuthSession } | { error: string }> {
  const users = await query<{
    id: string;
    email: string;
    password_hash: string;
    raw_user_meta_data: string | object | null;
    created_at: string;
  }>("SELECT id, email, password_hash, raw_user_meta_data, created_at FROM users WHERE email = ? LIMIT 1;", [
    email.trim().toLowerCase(),
  ]);

  if (!users || users.length === 0) {
    return { error: "Invalid email or password" };
  }

  const userRow = users[0];
  const isValid = await verifyPassword(password, userRow.password_hash);
  if (!isValid) {
    return { error: "Invalid email or password" };
  }

  let metadata: { full_name?: string } = {};
  if (userRow.raw_user_meta_data) {
    try {
      metadata =
        typeof userRow.raw_user_meta_data === "string"
          ? JSON.parse(userRow.raw_user_meta_data)
          : (userRow.raw_user_meta_data as { full_name?: string });
    } catch {
      metadata = {};
    }
  }

  const user: AuthUser = {
    id: userRow.id,
    email: userRow.email,
    user_metadata: metadata,
    created_at: userRow.created_at,
  };

  const token = await signJWT({
    id: user.id,
    email: user.email,
    full_name: metadata.full_name,
  });

  const session: AuthSession = {
    access_token: token,
    token_type: "bearer",
    expires_in: 30 * 24 * 60 * 60,
    user,
  };

  return { user, session };
}

/**
 * Register a new user, account, profile, pipeline, stages, and tags
 */
export async function signUpWithEmailPassword(
  email: string,
  password: string,
  fullName: string = ""
): Promise<{ user: AuthUser; session: AuthSession } | { error: string }> {
  const cleanEmail = email.trim().toLowerCase();

  const existing = await query<{ id: string }>(
    "SELECT id FROM users WHERE email = ? LIMIT 1;",
    [cleanEmail]
  );

  if (existing && existing.length > 0) {
    return { error: "A user with this email already exists" };
  }

  const userId = generateUUID();
  const accountId = generateUUID();
  const profileId = generateUUID();
  const pipelineId = generateUUID();
  const passwordHash = await hashPassword(password);
  const metadata = { full_name: fullName };

  try {
    // 1. Create user
    await execute(
      "INSERT INTO users (id, email, password_hash, raw_user_meta_data, email_confirmed_at, created_at, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3));",
      [userId, cleanEmail, passwordHash, JSON.stringify(metadata)]
    );

    // 2. Create primary account
    const accountName = fullName ? `${fullName}'s Organization` : "Primary Organization";
    await execute(
      "INSERT INTO accounts (id, name, owner_user_id, default_currency, created_at, updated_at) VALUES (?, ?, ?, 'USD', CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3));",
      [accountId, accountName, userId]
    );

    // 3. Create profile
    await execute(
      "INSERT INTO profiles (id, user_id, account_id, account_role, full_name, email, role, created_at, updated_at) VALUES (?, ?, ?, 'owner', ?, ?, 'admin', CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3));",
      [profileId, userId, accountId, fullName || cleanEmail.split("@")[0], cleanEmail]
    );

    // 4. Create default pipeline
    await execute(
      "INSERT INTO pipelines (id, user_id, account_id, name, created_at, updated_at) VALUES (?, ?, ?, 'Sales Pipeline', CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3));",
      [pipelineId, userId, accountId]
    );

    // 5. Create default pipeline stages
    const defaultStages = [
      { id: generateUUID(), name: "Lead / Inbound", pos: 0, color: "#3b82f6" },
      { id: generateUUID(), name: "Contacted", pos: 1, color: "#8b5cf6" },
      { id: generateUUID(), name: "Proposal Sent", pos: 2, color: "#eab308" },
      { id: generateUUID(), name: "Negotiation", pos: 3, color: "#f97316" },
      { id: generateUUID(), name: "Won", pos: 4, color: "#22c55e" },
      { id: generateUUID(), name: "Lost", pos: 5, color: "#ef4444" },
    ];

    for (const stage of defaultStages) {
      await execute(
        "INSERT INTO pipeline_stages (id, pipeline_id, name, position, color, created_at, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3));",
        [stage.id, pipelineId, stage.name, stage.pos, stage.color]
      );
    }

    // 6. Create default tags
    const defaultTags = [
      { id: generateUUID(), name: "VIP", color: "#e11d48" },
      { id: generateUUID(), name: "High Priority", color: "#f59e0b" },
      { id: generateUUID(), name: "Customer", color: "#10b981" },
    ];

    for (const tag of defaultTags) {
      await execute(
        "INSERT INTO tags (id, user_id, account_id, name, color, created_at, updated_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3), CURRENT_TIMESTAMP(3));",
        [tag.id, userId, accountId, tag.name, tag.color]
      );
    }

    const user: AuthUser = {
      id: userId,
      email: cleanEmail,
      user_metadata: metadata,
    };

    const token = await signJWT({
      id: user.id,
      email: user.email,
      full_name: fullName,
    });

    const session: AuthSession = {
      access_token: token,
      token_type: "bearer",
      expires_in: 30 * 24 * 60 * 60,
      user,
    };

    return { user, session };
  } catch (err: unknown) {
    const error = err as Error;
    console.error("[signUpWithEmailPassword] Error:", error);
    return { error: error.message || "Failed to create user account" };
  }
}

/**
 * Read the current session user from the Next.js cookies store
 */
export async function getSessionUser(): Promise<AuthUser | null> {
  try {
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get(SESSION_COOKIE_NAME);
    if (!sessionCookie?.value) return null;

    const verified = await verifyJWT(sessionCookie.value);
    if (!verified?.sub) return null;

    const users = await query<{
      id: string;
      email: string;
      raw_user_meta_data: string | object | null;
      created_at: string;
    }>("SELECT id, email, raw_user_meta_data, created_at FROM users WHERE id = ? LIMIT 1;", [
      verified.sub,
    ]);

    if (!users || users.length === 0) return null;

    const userRow = users[0];
    let metadata: { full_name?: string } = {};
    if (userRow.raw_user_meta_data) {
      try {
        metadata =
          typeof userRow.raw_user_meta_data === "string"
            ? JSON.parse(userRow.raw_user_meta_data)
            : (userRow.raw_user_meta_data as { full_name?: string });
      } catch {
        metadata = {};
      }
    }

    return {
      id: userRow.id,
      email: userRow.email,
      user_metadata: metadata,
      created_at: userRow.created_at,
    };
  } catch {
    return null;
  }
}
