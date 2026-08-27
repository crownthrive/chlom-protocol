import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CHLOM Chain Evidence Fabric",
  description:
    "Governed blockchain RPC, Google Blockchain Analytics, evidence, API, and MCP runtime for CrownThrive CHLOM.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
