import { sql } from "drizzle-orm";
import { bigint, boolean, check, index, pgTable, text, timestamp, uniqueIndex, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { DISCIPLINES } from "./people";
import { inList } from "./sql";

const TZ = { withTimezone: true } as const;

// What part of a client's data a professional may read (ADR-0005).
export const SCOPES = ["training", "nutrition", "body", "sleep", "vitals", "notes"] as const;
export type Scope = (typeof SCOPES)[number];

export const INVITATION_KINDS = ["staff", "admin", "client"] as const;
export type InvitationKind = (typeof INVITATION_KINDS)[number];

export const ASSIGNMENT_STATUSES = ["pending", "active", "ended"] as const;
export type AssignmentStatus = (typeof ASSIGNMENT_STATUSES)[number];

export const CONSENT_PURPOSES = [
  "health_processing",
  "staff_sharing",
  "aggregate_insights",
  "research",
  "marketing",
] as const;
export type ConsentPurpose = (typeof CONSENT_PURPOSES)[number];

const scopesCheck = (column: unknown) =>
  sql`${column} <@ array[${sql.raw(inList(SCOPES))}]::text[]`;

// A link sent by email. Only the SHA-256 of the token is stored.
export const invitation = pgTable(
  "invitation",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    email: text("email").notNull(),
    kind: text("kind").notNull(),
    // kind = staff: what the professional does.
    disciplines: text("disciplines").array(),
    // kind = client invited by a professional: the assignment created on acceptance.
    assignmentRole: text("assignment_role"),
    scopes: text("scopes").array(),
    invitedBy: uuid("invited_by")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    tokenHash: text("token_hash").notNull().unique(),
    expiresAt: timestamp("expires_at", TZ).notNull(),
    acceptedAt: timestamp("accepted_at", TZ),
    acceptedBy: uuid("accepted_by").references(() => user.id, { onDelete: "set null" }),
    revokedAt: timestamp("revoked_at", TZ),
    createdAt: timestamp("created_at", TZ).defaultNow().notNull(),
  },
  (t) => [
    index("invitation_email_idx").on(t.email),
    check("invitation_kind_check", sql`${t.kind} in (${sql.raw(inList(INVITATION_KINDS))})`),
    check("invitation_email_lower_check", sql`${t.email} = lower(${t.email})`),
    check(
      "invitation_assignment_role_check",
      sql`${t.assignmentRole} is null or ${t.assignmentRole} in (${sql.raw(inList(DISCIPLINES))})`,
    ),
    check("invitation_scopes_check", sql`${t.scopes} is null or ${scopesCheck(t.scopes)}`),
  ],
);

// A professional following a client. Becomes active only when the client consents.
export const careAssignment = pgTable(
  "care_assignment",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    clientId: uuid("client_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    staffId: uuid("staff_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    role: text("role").notNull(),
    scopes: text("scopes").array().notNull(),
    status: text("status").notNull().default("pending"),
    createdBy: uuid("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at", TZ).defaultNow().notNull(),
    activatedAt: timestamp("activated_at", TZ),
    endedAt: timestamp("ended_at", TZ),
    endedBy: uuid("ended_by").references(() => user.id, { onDelete: "set null" }),
  },
  (t) => [
    uniqueIndex("care_assignment_open_unique")
      .on(t.clientId, t.staffId, t.role)
      .where(sql`${t.status} <> 'ended'`),
    index("care_assignment_staff_idx").on(t.staffId).where(sql`${t.status} = 'active'`),
    index("care_assignment_client_idx").on(t.clientId),
    check("care_assignment_role_check", sql`${t.role} in (${sql.raw(inList(DISCIPLINES))})`),
    check("care_assignment_status_check", sql`${t.status} in (${sql.raw(inList(ASSIGNMENT_STATUSES))})`),
    check("care_assignment_scopes_check", sql`cardinality(${t.scopes}) > 0 and ${scopesCheck(t.scopes)}`),
    check("care_assignment_not_self_check", sql`${t.clientId} <> ${t.staffId}`),
  ],
);

// Append-only history: the newest row per (user, purpose, ref) is the current state.
export const consent = pgTable(
  "consent",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    purpose: text("purpose").notNull(),
    // staff_sharing: the care_assignment; research: the study.
    refId: uuid("ref_id"),
    granted: boolean("granted").notNull(),
    policyVersion: text("policy_version").notNull(),
    ipAddress: text("ip_address"),
    userAgent: text("user_agent"),
    // clock_timestamp, not now(): two rows written in one transaction (grant, then
    // revoke) must still sort in the order they happened.
    createdAt: timestamp("created_at", TZ).default(sql`clock_timestamp()`).notNull(),
  },
  (t) => [
    index("consent_user_purpose_idx").on(t.userId, t.purpose, t.createdAt),
    check("consent_purpose_check", sql`${t.purpose} in (${sql.raw(inList(CONSENT_PURPOSES))})`),
  ],
);

// Every read or write of a client's data by a professional (ADR-0005).
export const auditLog = pgTable(
  "audit_log",
  {
    id: bigint("id", { mode: "number" }).primaryKey().generatedAlwaysAsIdentity(),
    actorId: uuid("actor_id").references(() => user.id, { onDelete: "set null" }),
    clientId: uuid("client_id").references(() => user.id, { onDelete: "set null" }),
    action: text("action").notNull(),
    resource: text("resource").notNull(),
    resourceId: text("resource_id"),
    ipAddress: text("ip_address"),
    at: timestamp("at", TZ).defaultNow().notNull(),
  },
  (t) => [
    index("audit_log_client_idx").on(t.clientId, t.at),
    index("audit_log_actor_idx").on(t.actorId, t.at),
    check("audit_log_action_check", sql`${t.action} in ('read', 'write')`),
  ],
);
