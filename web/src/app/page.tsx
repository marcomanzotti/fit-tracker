import { APP } from "@/config";

// Placeholder home until the public site is designed (phase F2/F4).
export default function Home() {
  return (
    <main className="mx-auto flex min-h-full max-w-2xl flex-1 flex-col justify-center gap-4 px-6 py-24">
      <h1 className="text-4xl font-semibold tracking-tight">{APP.name}</h1>
      <p className="text-lg text-zinc-600 dark:text-zinc-400">{APP.description}</p>
    </main>
  );
}
