# WACRM - MySQL & XAMPP Database Setup Guide

This guide walks you through migrating and running **WACRM** on a local **MySQL / MariaDB database via XAMPP**, completely independent of Supabase.

---

## 🚀 Quick Start with XAMPP

### 1. Start XAMPP Services
1. Open the **XAMPP Control Panel**.
2. Click **Start** next to **Apache**.
3. Click **Start** next to **MySQL**.

---

### 2. Import the Database into phpMyAdmin

1. Open your browser and navigate to:
   ```
   http://localhost/phpmyadmin/
   ```
2. Click on the **Import** tab in the top navigation bar.
3. Click **Choose File** and select:
   ```
   mysql/wacrm_mysql_xampp.sql
   ```
4. Scroll down and click **Import** (or **Go**).
5. The `wacrm` database will be created with all **37 tables**, indexes, foreign keys, triggers, stored procedures, and initial seed data.

#### *Alternative: Import via Command Prompt (Terminal)*
```powershell
mysql -u root -p < "mysql/wacrm_mysql_xampp.sql"
```
*(Press Enter if your XAMPP root password is blank)*

---

## 🔑 Default Seed Account Credentials

The schema script includes a ready-to-use admin account and initialized pipeline:

| Field | Value |
|---|---|
| **Email** | `admin@wacrm.local` |
| **Password** | `password123` |
| **Role** | `owner` / `admin` |
| **Account** | `Primary Organization` |
| **Default Pipeline** | Standard Sales Pipeline (6 stages) |
| **Default Tags** | `VIP`, `High Priority`, `Customer` |

---

## ⚙️ Environment Configuration (`.env.local`)

Add the following variables to your `.env.local` file in the project root:

```env
# Database (XAMPP MySQL)
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=
MYSQL_DATABASE=wacrm

# Application URL
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

To install the MySQL client driver in the Next.js app:
```bash
npm install mysql2
```

---

## 📊 Supabase to MySQL Conversion Mapping

| Feature | Supabase (PostgreSQL) | MySQL (XAMPP / MariaDB) | Notes |
|---|---|---|---|
| **Primary Keys** | `UUID DEFAULT uuid_generate_v4()` | `VARCHAR(36)` | Generated in JS via `crypto.randomUUID()` |
| **JSON Data** | `JSONB` | `JSON` | Native MySQL JSON functions (`JSON_EXTRACT`, `JSON_CONTAINS`) |
| **Timestamps** | `TIMESTAMPTZ DEFAULT NOW()` | `DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3)` | Millisecond precision with `ON UPDATE CURRENT_TIMESTAMP(3)` |
| **Auth System** | `auth.users` + Supabase Auth | `users` table | Password hashing with `bcryptjs` / JWT session cookies |
| **Tenancy Isolation** | Row Level Security (RLS) policies | App-layer query scoping | Scoped with `account_id = ?` in backend query layer |
| **Custom Enums** | `CREATE TYPE ... AS ENUM` | `ENUM(...)` | Direct MySQL native ENUM columns |
| **Phone Deduplication** | `phone_normalized STORED` | `phone_normalized STORED` | `REGEXP_REPLACE(phone, '[^0-9]', '') STORED` |
| **RPC Functions** | PL/pgSQL Functions | MySQL Stored Procedures | `CALL procedure_name(...)` |
| **File Storage** | Supabase Storage Buckets | Local storage / `public/uploads` | Uploads served via Next.js `/public/uploads/` |
| **Realtime Updates** | Supabase Realtime (Postgres WAL) | Server-Sent Events (SSE) / Polling | Polling or lightweight SSE endpoint |

---

## 🗄️ Database Tables Overview (37 Tables)

1. **Authentication & Multi-Tenancy**: `users`, `accounts`, `account_invitations`, `profiles`, `member_presence`, `api_keys`
2. **Contacts & CRM Data**: `contacts`, `tags`, `contact_tags`, `custom_fields`, `contact_custom_values`, `contact_notes`
3. **Conversations & Messaging**: `conversations`, `messages`, `message_reactions`, `quick_replies`, `whatsapp_config`, `message_templates`
4. **Sales Pipelines & Deals**: `pipelines`, `pipeline_stages`, `deals`
5. **Broadcasts**: `broadcasts`, `broadcast_recipients`
6. **Automations Engine**: `automations`, `automation_steps`, `automation_logs`, `automation_pending_executions`
7. **Flows (Chatbot Builder)**: `flows`, `flow_nodes`, `flow_runs`, `flow_run_events`
8. **AI Assistant & Knowledge Base**: `ai_configs`, `ai_knowledge_documents`, `ai_knowledge_chunks`, `ai_usage_log`
9. **Integrations & Alerts**: `notifications`, `webhook_endpoints`
