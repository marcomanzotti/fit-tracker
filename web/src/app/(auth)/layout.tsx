import Image from "next/image";
import Link from "next/link";
import { APP } from "@/config";

// Sign-in, sign-up and invitation pages: one narrow column, the brand mark on top.
export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col gap-10 px-5 py-12 sm:py-20">
      <Link href="/" className="flex items-center gap-3 self-start">
        <Image src="/icon-192.png" alt="" width={40} height={40} className="rounded-[10px]" priority />
        <span className="condensed text-2xl font-bold tracking-tight">{APP.name}</span>
      </Link>
      {children}
    </main>
  );
}
