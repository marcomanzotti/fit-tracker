"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect } from "react";
import { pendingCount, pushMutations } from "@/lib/sync-queue";

const TABS = [
  { href: "/app", label: "Oggi" },
  { href: "/app/corpo", label: "Corpo" },
  { href: "/app/profilo", label: "Profilo" },
];

// The client app's tab bar, at the thumb on phones. It also sends anything left
// in the offline queue whenever the app opens or the connection comes back.
export function AppNav() {
  const pathname = usePathname();

  useEffect(() => {
    const flush = () => {
      if (pendingCount() > 0) pushMutations().catch(() => undefined);
    };
    flush();
    window.addEventListener("online", flush);
    return () => window.removeEventListener("online", flush);
  }, []);

  return (
    <nav
      aria-label="App"
      className="fixed inset-x-0 bottom-0 z-30 border-t border-seam bg-ink/95 pb-[env(safe-area-inset-bottom)] backdrop-blur"
    >
      <ul className="mx-auto flex max-w-lg">
        {TABS.map((tab) => {
          const active = tab.href === "/app" ? pathname === "/app" || pathname.startsWith("/app/allenamento") : pathname.startsWith(tab.href);
          return (
            <li key={tab.href} className="flex-1">
              <Link
                href={tab.href}
                aria-current={active ? "page" : undefined}
                className="flex min-h-14 flex-col items-center justify-center text-sm font-medium text-ash aria-[current=page]:text-signal"
              >
                {tab.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
