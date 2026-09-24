import type { Metadata } from "next";
import { Inter } from "next/font/google";
import Script from "next/script";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Payflux Recharge Portal - Firebase Live Credit Auto-Sync",
  description:
    "Recharge credits and mobile plans online via Payflux Payment Gateway with instant Firebase realtime account balance auto-sync.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={inter.className}>
      <head>
        <Script
          src="https://fampay-merchant-api.onrender.com/payflux.js"
          strategy="beforeInteractive"
        />
      </head>
      <body className="min-h-screen bg-[#0B0F17] text-slate-100 antialiased">
        {children}
      </body>
    </html>
  );
}
