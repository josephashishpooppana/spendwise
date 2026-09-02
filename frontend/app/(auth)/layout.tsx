"use client";

import { useAuth } from "@/lib/context/auth-context";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { IndianRupee } from "lucide-react";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.replace("/");
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <div className="flex min-h-svh items-center justify-center bg-background">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
      </div>
    );
  }

  if (isAuthenticated) return null;

  return (
    <div className="flex min-h-svh">
      {/* Left panel - branding (hidden on mobile) */}
      <div className="hidden lg:flex lg:w-1/2 flex-col items-center justify-center bg-primary p-12 text-primary-foreground">
        <div className="flex flex-col items-center gap-6 max-w-md text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary-foreground/15 backdrop-blur">
            <IndianRupee className="h-8 w-8" />
          </div>
          <h1 className="text-4xl font-bold tracking-tight text-balance">FinTrack</h1>
          <p className="text-lg leading-relaxed text-primary-foreground/80">
            Your complete personal finance tracker. Track income, expenses, UPI payments, credit cards, split bills, and get smart analytics.
          </p>
          <div className="mt-8 grid grid-cols-2 gap-4 text-sm text-primary-foreground/70">
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-primary-foreground/50" />
              UPI & Card Tracking
            </div>
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-primary-foreground/50" />
              Bill Splitting
            </div>
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-primary-foreground/50" />
              Smart Analytics
            </div>
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-primary-foreground/50" />
              Cashback Insights
            </div>
          </div>
        </div>
      </div>
      {/* Right panel - form */}
      <div className="flex flex-1 items-center justify-center p-6 md:p-12">
        <div className="w-full max-w-md">{children}</div>
      </div>
    </div>
  );
}
