import { useMemo, useState } from "react";
import { Plus, Clock, Zap, MoreHorizontal, GripVertical } from "lucide-react";
import {
  initialColumns,
  channelTone,
  priorityTone,
  brl,
  type Card,
  type Column,
} from "./data";

function timeLabel(min: number) {
  if (min < 60) return `${min}m`;
  return `${Math.floor(min / 60)}h`;
}

function KanbanCard({
  card,
  onDragStart,
  dragging,
}: {
  card: Card;
  onDragStart: () => void;
  dragging: boolean;
}) {
  return (
    <article
      draggable
      onDragStart={onDragStart}
      className={`group cursor-grab rounded-xl border border-border bg-card p-3 transition-all hover:border-primary/40 hover:shadow-[var(--shadow-node)] active:cursor-grabbing ${
        dragging ? "opacity-40" : ""
      }`}
    >
      <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-2">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className="grid h-8 w-8 shrink-0 place-items-center rounded-lg text-[11px] font-semibold"
            style={{
              background: `color-mix(in oklab, ${channelTone[card.channel]} 22%, transparent)`,
              color: channelTone[card.channel],
            }}
          >
            {card.initials}
          </span>
          <div className="min-w-0">
            <p className="truncate text-sm font-medium">{card.contact}</p>
            <p className="truncate text-[11px] text-muted-foreground">{card.channel}</p>
          </div>
        </div>
        <GripVertical className="mt-1 h-4 w-4 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
      </div>

      <p className="mt-2 line-clamp-2 text-xs leading-relaxed text-muted-foreground">
        “{card.preview}”
      </p>

      {card.automated && (
        <div className="mt-2 inline-flex items-center gap-1.5 rounded-md bg-primary/12 px-2 py-1 text-[11px] text-primary">
          <Zap className="h-3 w-3" />
          {card.automated}
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-1.5">
        {card.tags.map((t) => (
          <span
            key={t}
            className="rounded-md bg-secondary px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-muted-foreground"
          >
            {t}
          </span>
        ))}
      </div>

      <div className="mt-3 flex items-center justify-between border-t border-border/70 pt-2 text-[11px]">
        <span className="font-mono font-medium text-foreground">{brl(card.value)}</span>
        <div className="flex items-center gap-2 text-muted-foreground">
          <span
            className="inline-flex items-center gap-1 rounded-md px-1.5 py-0.5"
            style={{
              background: `color-mix(in oklab, ${priorityTone[card.priority]} 18%, transparent)`,
              color: priorityTone[card.priority],
            }}
          >
            {card.priority}
          </span>
          <span className="inline-flex items-center gap-1">
            <Clock className="h-3 w-3" />
            {timeLabel(card.waitingMin)}
          </span>
        </div>
      </div>
    </article>
  );
}

export function KanbanBoard() {
  const [columns, setColumns] = useState<Column[]>(initialColumns);
  const [dragging, setDragging] = useState<{ cardId: string; from: string } | null>(null);
  const [over, setOver] = useState<string | null>(null);

  const totals = useMemo(
    () =>
      Object.fromEntries(
        columns.map((c) => [c.id, c.cards.reduce((s, x) => s + x.value, 0)]),
      ) as Record<string, number>,
    [columns],
  );

  function drop(to: string) {
    if (!dragging) return;
    if (dragging.from !== to) {
      setColumns((cols) => {
        const card = cols
          .find((c) => c.id === dragging.from)!
          .cards.find((x) => x.id === dragging.cardId)!;
        return cols.map((c) => {
          if (c.id === dragging.from)
            return { ...c, cards: c.cards.filter((x) => x.id !== card.id) };
          if (c.id === to) return { ...c, cards: [card, ...c.cards] };
          return c;
        });
      });
    }
    setDragging(null);
    setOver(null);
  }

  return (
    <div className="scroll-slim flex h-full gap-4 overflow-x-auto p-5">
      {columns.map((col) => (
        <section
          key={col.id}
          onDragOver={(e) => {
            e.preventDefault();
            setOver(col.id);
          }}
          onDragLeave={() => setOver((o) => (o === col.id ? null : o))}
          onDrop={() => drop(col.id)}
          className={`flex h-full w-[310px] shrink-0 flex-col rounded-2xl border bg-surface/60 transition-colors ${
            over === col.id ? "border-primary/60 bg-primary/5" : "border-border"
          }`}
        >
          <header className="shrink-0 border-b border-border/70 px-3.5 py-3">
            <div className="flex items-center gap-2">
              <span
                className="h-2.5 w-2.5 rounded-full"
                style={{ background: col.accent }}
              />
              <h2 className="min-w-0 flex-1 truncate text-sm font-semibold">{col.title}</h2>
              <span className="rounded-md bg-secondary px-1.5 py-0.5 text-[11px] text-muted-foreground">
                {col.cards.length}
              </span>
              <MoreHorizontal className="h-4 w-4 text-muted-foreground" />
            </div>
            <div className="mt-1 flex items-center justify-between text-[11px] text-muted-foreground">
              <span>{col.hint}</span>
              <span className="font-mono">{brl(totals[col.id] ?? 0)}</span>
            </div>
          </header>

          <div className="scroll-slim flex min-h-0 flex-1 flex-col gap-2.5 overflow-y-auto p-3">
            {col.cards.map((card) => (
              <KanbanCard
                key={card.id}
                card={card}
                dragging={dragging?.cardId === card.id}
                onDragStart={() => setDragging({ cardId: card.id, from: col.id })}
              />
            ))}
            <button className="flex items-center justify-center gap-1.5 rounded-xl border border-dashed border-border py-2 text-xs text-muted-foreground transition-colors hover:border-primary/50 hover:text-primary">
              <Plus className="h-3.5 w-3.5" /> Adicionar conversa
            </button>
          </div>
        </section>
      ))}
    </div>
  );
}
