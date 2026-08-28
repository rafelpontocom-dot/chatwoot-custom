import { Moon, Sun } from "lucide-react";
import { useEffect, useState } from "react";

/**
 * O tema segue o Chatwoot: quando o Chatwoot aplica a classe `dark` no <html>,
 * a UI fica escura; caso contrário, fica clara. Este botão apenas alterna a
 * mesma classe, então funciona embutido no Chatwoot ou isolado.
 */
export function ThemeToggle() {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    const root = document.documentElement;
    const sync = () => setDark(root.classList.contains("dark"));
    sync();
    const obs = new MutationObserver(sync);
    obs.observe(root, { attributes: true, attributeFilter: ["class"] });
    return () => obs.disconnect();
  }, []);

  return (
    <button
      type="button"
      onClick={() => document.documentElement.classList.toggle("dark")}
      aria-label={dark ? "Usar tema claro" : "Usar tema escuro"}
      title={dark ? "Tema claro" : "Tema escuro"}
      className="grid h-9 w-9 place-items-center rounded-lg border border-border bg-surface text-muted-foreground transition-colors hover:text-foreground"
    >
      {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
    </button>
  );
}
