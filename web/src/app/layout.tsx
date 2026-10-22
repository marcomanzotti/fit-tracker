import type { Metadata, Viewport } from "next";
import { Archivo } from "next/font/google";
import { APP } from "@/config";
import "./globals.css";

// One family with a width axis: normal width for text, condensed for numbers
// and program cells (the .condensed class).
const archivo = Archivo({
  variable: "--font-archivo",
  subsets: ["latin"],
  axes: ["wdth"],
});

export const metadata: Metadata = {
  title: { default: APP.name, template: `%s · ${APP.name}` },
  description: APP.description,
  appleWebApp: { capable: true, title: APP.name, statusBarStyle: "black-translucent" },
};

export const viewport: Viewport = {
  themeColor: "#0b0b0d",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang={APP.defaultLocale} className={`${archivo.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  );
}
