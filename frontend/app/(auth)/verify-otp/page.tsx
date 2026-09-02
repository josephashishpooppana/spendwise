"use client";

import { Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { verifyOtp } from "@/lib/api/auth";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { InputOTP, InputOTPGroup, InputOTPSlot } from "@/components/ui/input-otp";
import { IndianRupee, ArrowLeft, Loader2 } from "lucide-react";
import Link from "next/link";

function VerifyOTPContent() {
  const [otp, setOtp] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();
  const searchParams = useSearchParams();
  const email = searchParams.get("email") || "";

  async function handleVerify() {
    if (otp.length !== 6) {
      toast.error("Please enter the full 6-digit code");
      return;
    }
    setIsLoading(true);
    try {
      const res = await verifyOtp(email, otp);
      if (res.success) {
        toast.success("OTP verified! You can now sign in.");
        router.push("/login");
      } else {
        toast.error("Invalid OTP. Try 123456 for demo.");
      }
    } catch {
      toast.error("Verification failed. Try 123456 for demo.");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <>
      <div className="flex items-center gap-2 mb-8 lg:hidden">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground">
          <IndianRupee className="h-5 w-5" />
        </div>
        <span className="text-xl font-bold">FinTrack</span>
      </div>

      <Card className="border-0 shadow-none lg:border lg:shadow-sm">
        <CardHeader className="px-0 lg:px-6">
          <Link href="/forgot-password" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-2 w-fit">
            <ArrowLeft className="h-4 w-4" /> Back
          </Link>
          <CardTitle className="text-2xl font-bold">Verify OTP</CardTitle>
          <CardDescription>
            Enter the 6-digit code sent to {email || "your email"}
          </CardDescription>
        </CardHeader>
        <CardContent className="px-0 lg:px-6 flex flex-col items-center gap-6">
          <InputOTP maxLength={6} value={otp} onChange={setOtp}>
            <InputOTPGroup>
              <InputOTPSlot index={0} />
              <InputOTPSlot index={1} />
              <InputOTPSlot index={2} />
              <InputOTPSlot index={3} />
              <InputOTPSlot index={4} />
              <InputOTPSlot index={5} />
            </InputOTPGroup>
          </InputOTP>

          <Button onClick={handleVerify} className="w-full" disabled={isLoading || otp.length !== 6}>
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Verify
          </Button>

          <div className="rounded-lg bg-muted p-3 text-xs text-muted-foreground w-full">
            <p className="font-medium mb-1">Demo Mode</p>
            <p>Use code <span className="font-mono font-bold">123456</span> to verify.</p>
          </div>
        </CardContent>
      </Card>
    </>
  );
}

export default function VerifyOTPPage() {
  return (
    <Suspense fallback={
      <div className="flex items-center justify-center p-12">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    }>
      <VerifyOTPContent />
    </Suspense>
  );
}
