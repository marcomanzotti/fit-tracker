import { sql } from "drizzle-orm";
import { check, date, doublePrecision, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { inList } from "./sql";

const TZ = { withTimezone: true } as const;

export const DISCIPLINES = ["pt", "nutrition", "physio"] as const;
export type Discipline = (typeof DISCIPLINES)[number];

export const SEXES = ["m", "f"] as const;

// What a professional does in the studio; the user role itself is "staff".
export const staffProfile = pgTable(
  "staff_profile",
  {
    userId: uuid("user_id")
      .primaryKey()
      .references(() => user.id, { onDelete: "cascade" }),
    disciplines: text("disciplines").array().notNull(),
    createdAt: timestamp("created_at", TZ).defaultNow().notNull(),
  },
  (t) => [
    check(
      "staff_profile_disciplines_check",
      sql`cardinality(${t.disciplines}) > 0 and ${t.disciplines} <@ array[${sql.raw(inList(DISCIPLINES))}]::text[]`,
    ),
  ],
);

// The client's own data used by the formulas (from the iOS Prefs, minus device flags).
export const clientProfile = pgTable(
  "client_profile",
  {
    userId: uuid("user_id")
      .primaryKey()
      .references(() => user.id, { onDelete: "cascade" }),
    sex: text("sex"),
    birthDate: date("birth_date"),
    heightCm: doublePrecision("height_cm"),
    timezone: text("timezone").notNull().default("Europe/Rome"),
    updatedAt: timestamp("updated_at", TZ)
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (t) => [
    check("client_profile_sex_check", sql`${t.sex} is null or ${t.sex} in (${sql.raw(inList(SEXES))})`),
    check("client_profile_height_check", sql`${t.heightCm} is null or ${t.heightCm} between 100 and 250`),
  ],
);
