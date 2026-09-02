"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { forgotPassword } from "@/lib/api/auth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { IndianRupee, ArrowLeft, Loader2 } from "lucide-react";

const schema = z.object({
  email: z.string().email("Enter a valid email address"),
});

type FormData = z.infer<typeof schema>;

export default function ForgotPasswordPage() {
  const [sent, setSent] = useState(false);
  const router = useRouter();

  const { register, handleSubmit, formState: { errors, isSubmitting }, getValues } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  async function onSubmit(data: FormData) {
    try {
      await forgotPassword(data.email);
      setSent(true);
      toast.success("OTP sent to your email");
    } catch {
      toast.error("Failed to send OTP. Please try again.");
    }
  }

  if (sent) {
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
            <CardTitle className="text-2xl font-bold">Check your email</CardTitle>
            <CardDescription>
              We sent a 6-digit verification code to {getValues("email")}
            </CardDescription>
          </CardHeader>
          <CardContent className="px-0 lg:px-6 flex flex-col gap-4">
            <Button onClick={() => router.push(`/verify-otp?email=${encodeURIComponent(getValues("email"))}`)} className="w-full">
              Enter OTP
            </Button>
            <Button variant="ghost" onClick={() => setSent(false)} className="w-full">
              Resend code
            </Button>
          </CardContent>
        </Card>
      </>
    );
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
          <Link href="/login" className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground mb-2 w-fit">
            <ArrowLeft className="h-4 w-4" /> Back to login
          </Link>
          <CardTitle className="text-2xl font-bold">Forgot password</CardTitle>
          <CardDescription>{"Enter your email and we'll send you a verification code"}</CardDescription>
        </CardHeader>
        <CardContent className="px-0 lg:px-6">
          <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" placeholder="arjun@example.com" {...register("email")} aria-invalid={!!errors.email} />
              {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
            </div>
            <Button type="submit" className="w-full mt-2" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Send verification code
            </Button>
          </form>
        </CardContent>
      </Card>
    </>
  );
}
