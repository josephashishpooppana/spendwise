"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, ArrowLeftRight, BarChart3, Split, Menu, Smartphone } from "lucide-react";
import { cn } from "@/lib/utils";
import { useSidebar } from "@/components/ui/sidebar";

const mobileNavItems = [
  { title: "Home", href: "/dashboard", icon: LayoutDashboard },
  { title: "Transactions", href: "/dashboard/transactions", icon: ArrowLeftRight },
  { title: "Analytics", href: "/dashboard/analytics", icon: BarChart3 },
  { title: "Apps", href: "/dashboard/apps", icon: Smartphone },
  { title: "Splits", href: "/dashboard/splits", icon: Split },
];

export function MobileNav() {
  const pathname = usePathname();
  const { setOpenMobile } = useSidebar();

  function isActive(href: string) {
    if (href === "/dashboard") return pathname === "/dashboard";
    return pathname.startsWith(href);
  }

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex md:hidden border-t bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80">
      {mobileNavItems.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className={cn(
            "flex flex-1 flex-col items-center gap-1 py-2 text-[10px] font-medium transition-colors",
            isActive(item.href)
              ? "text-primary"
              : "text-muted-foreground hover:text-foreground"
          )}
        >
          <item.icon className="h-5 w-5" />
          <span>{item.title}</span>
        </Link>
      ))}
      <button
        onClick={() => setOpenMobile(true)}
        className="flex flex-1 flex-col items-center gap-1 py-2 text-[10px] font-medium text-muted-foreground hover:text-foreground transition-colors"
      >
        <Menu className="h-5 w-5" />
        <span>More</span>
      </button>
    </nav>
  );
}
