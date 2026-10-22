import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { APP } from "@/config";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: APP.name,
  description: APP.description,
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang={APP.defaultLocale}
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
