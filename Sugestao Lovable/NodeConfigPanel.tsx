import { X, Trash2, Copy, Play } from "lucide-react";
import type { Node } from "@xyflow/react";
import { kindMeta, type FlowNodeData } from "./nodes";

const fieldOptions: Record<string, string[]> = {
  canal: ["WhatsApp", "Instagram", "E-mail", "Webchat"],
  coluna: ["Novos leads", "Qualificação", "Proposta enviada", "Ganhos"],
  operador: ["igual a", "diferente de", "menor que", "maior que", "contém"],
  ativo: ["sim", "não"],
  registrar: ["sim", "não"],
};

export function NodeConfigPanel({
  node,
  onClose,
  onChange,
  onDelete,
}: {
  node: Node<FlowNodeData>;
  onClose: () => void;
  onChange: (id: string, patch: Partial<FlowNodeData>) => void;
  onDelete: (id: string) => void;
}) {
  const meta = kindMeta[node.data.kind];
  const Icon = meta.icon;

  const setConfig = (key: string, value: string) =>
    onChange(node.id, { config: { ...node.data.config, [key]: value } });

  return (
    <aside className="panel scroll-slim absolute right-0 top-0 z-20 flex h-full w-full max-w-[360px] flex-col overflow-y-auto rounded-l-2xl">
      <header className="sticky top-0 z-10 grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 border-b border-border bg-surface/95 px-4 py-3 backdrop-blur">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className="grid h-8 w-8 shrink-0 place-items-center rounded-lg"
            style={{
              background: `color-mix(in oklab, ${meta.color} 22%, transparent)`,
              color: meta.color,
            }}
          >
            <Icon className="h-4 w-4" />
          </span>
          <div className="min-w-0">
            <p
              className="text-[10px] font-semibold uppercase tracking-[0.14em]"
              style={{ color: meta.color }}
            >
              {meta.label}
            </p>
            <p className="truncate text-sm font-medium">{node.data.title}</p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="grid h-8 w-8 shrink-0 place-items-center rounded-lg text-muted-foreground hover:bg-secondary hover:text-foreground"
          aria-label="Fechar configuração"
        >
          <X className="h-4 w-4" />
        </button>
      </header>

      <div className="flex flex-1 flex-col gap-5 p-4">
        <section className="space-y-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Identificação
          </p>
          <label className="block space-y-1.5">
            <span className="text-xs text-muted-foreground">Nome do bloco</span>
            <input
              value={node.data.title}
              onChange={(e) => onChange(node.id, { title: e.target.value })}
              className="w-full rounded-lg border border-input bg-background px-3 py-2 text-sm outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25"
            />
          </label>
          <label className="block space-y-1.5">
            <span className="text-xs text-muted-foreground">Descrição</span>
            <textarea
              rows={2}
              value={node.data.summary}
              onChange={(e) => onChange(node.id, { summary: e.target.value })}
              className="w-full resize-none rounded-lg border border-input bg-background px-3 py-2 text-sm outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25"
            />
          </label>
        </section>

        <section className="space-y-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Parâmetros
          </p>
          {Object.entries(node.data.config).map(([key, value]) => {
            const options = fieldOptions[key];
            return (
              <label key={key} className="block space-y-1.5">
                <span className="text-xs capitalize text-muted-foreground">{key}</span>
                {options ? (
                  <select
                    value={value}
                    onChange={(e) => setConfig(key, e.target.value)}
                    className="w-full rounded-lg border border-input bg-background px-3 py-2 text-sm outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25"
                  >
                    {options.map((o) => (
                      <option key={o} value={o}>
                        {o}
                      </option>
                    ))}
                  </select>
                ) : key === "mensagem" ? (
                  <textarea
                    rows={3}
                    value={value}
                    onChange={(e) => setConfig(key, e.target.value)}
                    className="w-full resize-none rounded-lg border border-input bg-background px-3 py-2 font-mono text-xs outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25"
                  />
                ) : (
                  <input
                    value={value}
                    onChange={(e) => setConfig(key, e.target.value)}
                    className="w-full rounded-lg border border-input bg-background px-3 py-2 text-sm outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25"
                  />
                )}
              </label>
            );
          })}
        </section>

        <section className="space-y-2 rounded-xl border border-border bg-surface-2/60 p-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Variáveis disponíveis
          </p>
          <div className="flex flex-wrap gap-1.5">
            {["{{contato.nome}}", "{{card.coluna}}", "{{conversa.canal}}", "{{agente}}"].map(
              (v) => (
                <span
                  key={v}
                  className="rounded-md bg-secondary px-2 py-1 font-mono text-[10px] text-muted-foreground"
                >
                  {v}
                </span>
              ),
            )}
          </div>
        </section>

        <div className="mt-auto flex flex-wrap gap-2 border-t border-border pt-4">
          <button className="inline-flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-primary px-3 py-2 text-sm font-medium text-primary-foreground transition hover:opacity-90">
            <Play className="h-3.5 w-3.5" /> Testar bloco
          </button>
          <button className="grid h-9 w-9 place-items-center rounded-lg border border-border text-muted-foreground hover:text-foreground">
            <Copy className="h-4 w-4" />
          </button>
          <button
            onClick={() => onDelete(node.id)}
            className="grid h-9 w-9 place-items-center rounded-lg border border-border text-destructive hover:bg-destructive/10"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      </div>
    </aside>
  );
}
