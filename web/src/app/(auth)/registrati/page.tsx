import type { Metadata } from "next";
import { Suspense } from "react";
import { Loading } from "@/components/ui";
import { SignUpForm } from "./sign-up-form";

export const metadata: Metadata = { title: "Registrati" };

export default function SignUpPage() {
  return (
    <section className="flex flex-col gap-8">
      <div className="flex flex-col gap-3">
        <h1 className="condensed text-4xl font-bold leading-none">Crea il tuo account</h1>
        <p className="text-ash">Se il tuo studio ti ha mandato un invito, apri prima il link nella mail.</p>
      </div>
      <Suspense fallback={<Loading />}>
        <SignUpForm />
      </Suspense>
    </section>
  );
}
