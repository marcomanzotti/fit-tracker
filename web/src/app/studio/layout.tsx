import type { Metadata } from "next";
import { Suspense } from "react";
import { StudioNav } from "@/components/studio-nav";

export const metadata: Metadata = { title: { default: "Studio", template: "%s · Studio" } };

// The professionals' area. Each page checks the session itself (inside Suspense),
// so this shell stays static and renders instantly.
export default function StudioLayout({ children }: LayoutProps<"/studio">) {
  return (
    <div className="flex min-h-dvh flex-col md:flex-row">
      {/* The nav reads the URL to mark the current section: a same-size frame stands in meanwhile. */}
      <Suspense fallback={<div className="h-14 border-b border-seam md:h-dvh md:w-52 md:border-r md:border-b-0" />}>
        <StudioNav />
      </Suspense>
      <main className="min-w-0 flex-1 px-5 py-8 md:px-10 md:py-10">{children}</main>
    </div>
  );
}
