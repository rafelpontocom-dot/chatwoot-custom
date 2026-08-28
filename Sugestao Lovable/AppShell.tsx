import { Link, useRouterState } from "@tanstack/react-router";
import {
  Inbox,
  KanbanSquare,
  Workflow,
  Users,
  BarChart3,
  Settings,
  Sparkles,
} from "lucide-react";
import type { ReactNode } from "react";
import { ThemeToggle } from "./ThemeToggle";

const nav = [
  { to: "/", label: "Kanban", icon: KanbanSquare, ready: true },
  { to: "/automacoes", label: "Automações", icon: Workflow, ready: true },
  { to: "/", label: "Caixa de entrada", icon: Inbox, ready: false },
  { to: "/", label: "Contatos", icon: Users, ready: false },
  { to: "/", label: "Relatórios", icon: BarChart3, ready: false },
] as const;


export function AppShell({
  children,
  title,
  subtitle,
  actions,
}: {
  children: ReactNode;
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="flex h-screen w-full overflow-hidden bg-background">
      <aside className="hidden w-[68px] shrink-0 flex-col items-center gap-2 border-r border-border bg-sidebar py-4 md:flex">
        <Link
          to="/"
          className="mb-3 grid h-10 w-10 place-items-center rounded-xl"
          style={{ background: "var(--gradient-brand)" }}
          aria-label="Grow Plataforma"
        >
          <Sparkles className="h-5 w-5 text-primary-foreground" />
        </Link>
        {nav.map((item) => {
          const active = item.ready && pathname === item.to;
          const cls = `group relative grid h-11 w-11 place-items-center rounded-xl transition-colors ${
            active
              ? "bg-sidebar-accent text-primary"
              : "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground"
          } ${item.ready ? "" : "opacity-45"}`;
          const inner = (
            <>
              {active && (
                <span className="absolute -left-[10px] h-6 w-[3px] rounded-full bg-primary" />
              )}
              <item.icon className="h-[18px] w-[18px]" />
            </>
          );
          return item.ready ? (
            <Link key={item.label} to={item.to} title={item.label} className={cls}>
              {inner}
            </Link>
          ) : (
            <span key={item.label} title={`${item.label} (em breve)`} className={cls}>
              {inner}
            </span>
          );
        })}

        <div className="mt-auto grid h-11 w-11 place-items-center rounded-xl text-muted-foreground hover:text-foreground">
          <Settings className="h-[18px] w-[18px]" />
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="grid shrink-0 grid-cols-[minmax(0,1fr)_auto] items-center gap-4 border-b border-border bg-surface/70 px-5 py-3 backdrop-blur sm:flex sm:justify-between">
          <div className="min-w-0">
            <h1 className="truncate font-display text-lg font-semibold">{title}</h1>
            {subtitle && (
              <p className="truncate text-xs text-muted-foreground">{subtitle}</p>
            )}
          </div>
          <div className="flex shrink-0 items-center gap-2">
            {actions}
            <ThemeToggle />
          </div>
        </header>
        <main className="min-h-0 flex-1 overflow-hidden">{children}</main>
      </div>
    </div>
  );
}
