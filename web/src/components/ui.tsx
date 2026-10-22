import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from "react";

// The small set of building blocks every screen uses (tokens in globals.css).
// Hierarchy comes from borders and radius, not shadows: panels 14px, controls 8px.

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "quiet" | "danger" };

const BUTTON: Record<NonNullable<ButtonProps["variant"]>, string> = {
  primary: "bg-signal text-ink hover:bg-amber",
  quiet: "bg-steel text-chalk hover:bg-seam border border-seam",
  danger: "bg-transparent text-alert border border-alert/50 hover:bg-alert/10",
};

export function Button({ variant = "quiet", className = "", ...props }: ButtonProps) {
  return (
    <button
      className={`inline-flex min-h-11 items-center justify-center gap-2 rounded-[var(--radius-control)] px-4 text-sm font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${BUTTON[variant]} ${className}`}
      {...props}
    />
  );
}

export function Input({ className = "", ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={`min-h-11 w-full rounded-[var(--radius-control)] border border-seam bg-graphite px-3 text-chalk placeholder:text-ash/70 focus:border-signal focus:outline-none ${className}`}
      {...props}
    />
  );
}

type FieldProps = { label: string; hint?: string; error?: string | null; htmlFor: string; children: ReactNode };

export function Field({ label, hint, error, htmlFor, children }: FieldProps) {
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={htmlFor} className="text-sm font-medium text-chalk">
        {label}
      </label>
      {children}
      {error ? (
        <p role="alert" className="text-sm text-alert">
          {error}
        </p>
      ) : hint ? (
        <p className="text-sm text-ash">{hint}</p>
      ) : null}
    </div>
  );
}

type PanelProps = { title?: string; actions?: ReactNode; children: ReactNode; className?: string };

export function Panel({ title, actions, children, className = "" }: PanelProps) {
  return (
    <section className={`rounded-[var(--radius-panel)] border border-seam bg-graphite p-5 ${className}`}>
      {(title || actions) && (
        <header className="mb-4 flex items-center justify-between gap-4">
          {title && <h2 className="text-lg font-semibold">{title}</h2>}
          {actions}
        </header>
      )}
      {children}
    </section>
  );
}

const NOTICE = {
  info: "border-seam text-chalk",
  success: "border-go/50 text-go",
  error: "border-alert/50 text-alert",
};

export function Notice({ tone = "info", children }: { tone?: keyof typeof NOTICE; children: ReactNode }) {
  return (
    <p role={tone === "error" ? "alert" : "status"} className={`rounded-[var(--radius-control)] border px-4 py-3 text-sm ${NOTICE[tone]}`}>
      {children}
    </p>
  );
}

export function PageTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <h1 className="condensed text-4xl font-bold leading-none tracking-tight">{children}</h1>
      {aside}
    </div>
  );
}

// A quiet placeholder while a section that depends on the session streams in.
export function Loading({ label = "Caricamento" }: { label?: string }) {
  return (
    <p className="text-sm text-ash" aria-busy="true">
      {label}…
    </p>
  );
}
