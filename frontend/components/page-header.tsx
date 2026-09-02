"use client";

import { SidebarTrigger } from "@/components/ui/sidebar";
import { Separator } from "@/components/ui/separator";
import { Breadcrumb, BreadcrumbItem, BreadcrumbLink, BreadcrumbList, BreadcrumbPage, BreadcrumbSeparator } from "@/components/ui/breadcrumb";

interface PageHeaderProps {
  title: string;
  breadcrumbs?: { label: string; href?: string }[];
  actions?: React.ReactNode;
}

export function PageHeader({ title, breadcrumbs, actions }: PageHeaderProps) {
  return (
    <header className="flex h-14 md:h-16 shrink-0 items-center gap-2 border-b px-4 md:px-6">
      <SidebarTrigger className="-ml-1 hidden md:flex" />
      <Separator orientation="vertical" className="mr-2 h-4 hidden md:block" />
      <div className="flex flex-1 items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          {breadcrumbs && breadcrumbs.length > 0 ? (
            <Breadcrumb>
              <BreadcrumbList>
                {breadcrumbs.map((bc, i) => (
                  <span key={bc.label} className="contents">
                    {i > 0 && <BreadcrumbSeparator />}
                    <BreadcrumbItem>
                      {bc.href ? (
                        <BreadcrumbLink href={bc.href}>{bc.label}</BreadcrumbLink>
                      ) : (
                        <BreadcrumbPage>{bc.label}</BreadcrumbPage>
                      )}
                    </BreadcrumbItem>
                  </span>
                ))}
              </BreadcrumbList>
            </Breadcrumb>
          ) : (
            <h1 className="text-lg font-semibold">{title}</h1>
          )}
        </div>
        {actions && <div className="flex items-center gap-2">{actions}</div>}
      </div>
    </header>
  );
}
