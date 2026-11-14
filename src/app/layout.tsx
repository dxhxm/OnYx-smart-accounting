import { AuthProvider } from "@/contexts/AuthContext";
import { ThemeProvider } from "@/hooks/useTheme";
import { LedgerProvider } from "@/contexts/LedgerContext";
import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
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
  metadataBase: new URL("https://onyx-smart-accounting.app"),
  title: {
    default: "OnYx | Smart Accounting & AI Financial Governance",
    template: "%s | OnYx",
  },
  description:
    "Autonomous AI-driven accounting platform enforcing audit-safe financial compliance, intelligent transaction classification, and real-time spending controls.",
  keywords: [
    "accounting",
    "financial governance",
    "AI accounting",
    "smart accounting",
    "audit compliance",
    "OnYx",
  ],
  authors: [{ name: "OnYx Engineering Team" }],
  creator: "OnYx",
  openGraph: {
    title: "OnYx | Smart Accounting & AI Financial Governance",
    description:
      "Autonomous AI-driven accounting platform enforcing audit-safe financial compliance and real-time spending controls.",
    url: "https://onyx-smart-accounting.app",
    siteName: "OnYx Smart Accounting",
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "OnYx | Smart Accounting & AI Financial Governance",
    description:
      "Autonomous AI-driven accounting platform enforcing audit-safe financial compliance.",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground`}>
        {/* ThemeProvider must wrap AuthProvider if it affects UI globally */}
        <ThemeProvider>
          <LedgerProvider>
            <AuthProvider>
              {children}
            </AuthProvider>
          </LedgerProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}