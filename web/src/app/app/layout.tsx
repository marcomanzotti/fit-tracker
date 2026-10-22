import type { Metadata } from "next";
import { Suspense } from "react";
import { AppNav } from "@/components/app-nav";

export const metadata: Metadata = { title: { default: "Oggi", template: "%s" } };

// The client app: one column sized for a phone, tabs at the bottom.
export default function ClientLayout({ children }: LayoutProps<"/app">) {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-lg flex-col px-4 pt-6 pb-28">
      {children}
      <Suspense>
        <AppNav />
      </Suspense>
    </div>
  );
}
