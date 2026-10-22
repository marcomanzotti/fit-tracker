"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { APP } from "@/config";
import { authClient } from "@/lib/auth-client";

const LINKS = [
  { href: "/studio", label: "Clienti" },
  { href: "/studio/template", label: "Template" },
  { href: "/studio/sicurezza", label: "Sicurezza" },
];

// The studio's left rail (top bar on phones). The current section is the one
// on a raised surface; yellow stays reserved for the primary action.
export function StudioNav() {
  const pathname = usePathname();
  const router = useRouter();
  const isActive = (href: string) =>
    href === "/studio" ? pathname === "/studio" || pathname.startsWith("/studio/clienti") : pathname.startsWith(href);

  async function signOut() {
    await authClient.signOut();
    router.replace("/accedi");
  }

  return (
    <nav aria-label="Studio" className="flex items-center gap-1 border-b border-seam px-4 py-3 md:h-dvh md:w-52 md:flex-col md:items-stretch md:gap-1 md:border-r md:border-b-0 md:py-6">
      <Link href="/studio" className="mr-3 flex items-center gap-2 md:mr-0 md:mb-8 md:px-3">
        <Image src="/icon-192.png" alt="" width={28} height={28} className="rounded-[7px]" />
        <span className="condensed hidden text-xl font-bold sm:inline">{APP.name}</span>
      </Link>
      {LINKS.map((link) => (
        <Link
          key={link.href}
          href={link.href}
          aria-current={isActive(link.href) ? "page" : undefined}
          className="rounded-[var(--radius-control)] px-3 py-2 text-sm font-medium text-ash hover:text-chalk aria-[current=page]:bg-steel aria-[current=page]:text-chalk"
        >
          {link.label}
        </Link>
      ))}
      <button
        type="button"
        onClick={signOut}
        className="ml-auto rounded-[var(--radius-control)] px-3 py-2 text-left text-sm text-ash hover:text-chalk md:mt-auto md:ml-0"
      >
        Esci
      </button>
    </nav>
  );
}
