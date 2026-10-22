import type { Metadata } from "next";
import { Suspense } from "react";
import { Loading } from "@/components/ui";
import { SignInForm } from "./sign-in-form";

export const metadata: Metadata = { title: "Accedi" };

export default function SignInPage() {
  return (
    <section className="flex flex-col gap-8">
      <h1 className="condensed text-4xl font-bold leading-none">Accedi</h1>
      <Suspense fallback={<Loading />}>
        <SignInForm />
      </Suspense>
    </section>
  );
}
