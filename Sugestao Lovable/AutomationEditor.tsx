import { useCallback, useMemo, useState } from "react";
import {
  ReactFlow,
  Background,
  BackgroundVariant,
  Controls,
  MiniMap,
  addEdge,
  useNodesState,
  useEdgesState,
  type Connection,
  type Edge,
  type Node,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { Plus } from "lucide-react";
import { nodeTypes, kindMeta, type FlowKind, type FlowNodeData } from "./nodes";
import { initialNodes, initialEdges } from "./flowData";
import { NodeConfigPanel } from "./NodeConfigPanel";

const palette: { kind: FlowKind; hint: string }[] = [
  { kind: "trigger", hint: "Inicia o fluxo" },
  { kind: "condition", hint: "Ramifica sim / não" },
  { kind: "action", hint: "Mensagem, tag, coluna" },
  { kind: "delay", hint: "Aguarda um tempo" },
  { kind: "exit", hint: "Finaliza o fluxo" },
];

let seq = 100;

export function AutomationEditor() {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node<FlowNodeData>>(
    initialNodes as Node<FlowNodeData>[],
  );
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>(initialEdges);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const selected = useMemo(
    () => nodes.find((n) => n.id === selectedId) ?? null,
    [nodes, selectedId],
  );

  const onConnect = useCallback(
    (c: Connection) =>
      setEdges((eds) =>
        addEdge(
          {
            ...c,
            animated: true,
            style: {
              stroke:
                c.sourceHandle === "yes"
                  ? "var(--action)"
                  : c.sourceHandle === "no"
                    ? "var(--exit)"
                    : "color-mix(in oklab, var(--foreground) 35%, transparent)",
            },
          },
          eds,
        ),
      ),
    [setEdges],
  );

  const patchNode = useCallback(
    (id: string, patch: Partial<FlowNodeData>) =>
      setNodes((ns) =>
        ns.map((n) => (n.id === id ? { ...n, data: { ...n.data, ...patch } } : n)),
      ),
    [setNodes],
  );

  const removeNode = useCallback(
    (id: string) => {
      setNodes((ns) => ns.filter((n) => n.id !== id));
      setEdges((es) => es.filter((e) => e.source !== id && e.target !== id));
      setSelectedId(null);
    },
    [setNodes, setEdges],
  );

  const addNode = useCallback(
    (kind: FlowKind) => {
      const id = `n${++seq}`;
      setNodes((ns) => [
        ...ns,
        {
          id,
          type: kind,
          position: { x: 700 + Math.random() * 80, y: 120 + ns.length * 40 },
          data: {
            kind,
            title: `Novo bloco de ${kindMeta[kind].label.toLowerCase()}`,
            summary: "Clique para configurar este bloco.",
            config:
              kind === "condition"
                ? { campo: "contato.tag", operador: "igual a", valor: "" }
                : kind === "delay"
                  ? { duracao: "30 minutos", janela: "Sempre" }
                  : { canal: "WhatsApp", mensagem: "" },
          },
        } as Node<FlowNodeData>,
      ]);
      setSelectedId(id);
    },
    [setNodes],
  );

  return (
    <div className="relative flex h-full min-h-0">
      <div className="hidden w-[212px] shrink-0 flex-col gap-2 border-r border-border bg-surface/60 p-3 lg:flex">
        <p className="px-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Blocos
        </p>
        {palette.map(({ kind, hint }) => {
          const meta = kindMeta[kind];
          const Icon = meta.icon;
          return (
            <button
              key={kind}
              onClick={() => addNode(kind)}
              className="group flex items-center gap-2.5 rounded-xl border border-border bg-card px-2.5 py-2 text-left transition hover:border-primary/50"
            >
              <span
                className="grid h-8 w-8 shrink-0 place-items-center rounded-lg"
                style={{
                  background: `color-mix(in oklab, ${meta.color} 20%, transparent)`,
                  color: meta.color,
                }}
              >
                <Icon className="h-4 w-4" />
              </span>
              <span className="min-w-0">
                <span className="block truncate text-[13px] font-medium">{meta.label}</span>
                <span className="block truncate text-[11px] text-muted-foreground">
                  {hint}
                </span>
              </span>
              <Plus className="ml-auto h-3.5 w-3.5 shrink-0 text-muted-foreground opacity-0 group-hover:opacity-100" />
            </button>
          );
        })}
        <div className="mt-auto rounded-xl border border-border bg-surface-2/60 p-3 text-[11px] leading-relaxed text-muted-foreground">
          Arraste dos pontos de conexão para ligar blocos. O ramo{" "}
          <span style={{ color: "var(--action)" }}>Sim</span> sai à esquerda e{" "}
          <span style={{ color: "var(--exit)" }}>Não</span> à direita.
        </div>
      </div>

      <div className="grid-canvas relative min-w-0 flex-1">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodeClick={(_, n) => setSelectedId(n.id)}
          onPaneClick={() => setSelectedId(null)}
          fitView
          proOptions={{ hideAttribution: true }}
          defaultEdgeOptions={{ type: "smoothstep" }}
          className="[&_.react-flow__edge-text]:fill-muted-foreground [&_.react-flow__edge-text]:text-[10px]"
        >
          <Background
            variant={BackgroundVariant.Dots}
            gap={22}
            size={1.4}
            color="color-mix(in oklab, var(--foreground) 14%, transparent)"
          />
          <Controls
            showInteractive={false}
            className="!rounded-xl !border !border-border !bg-surface !shadow-none [&_button]:!border-border [&_button]:!bg-surface [&_button]:!text-foreground [&_button:hover]:!bg-secondary"
          />
          <MiniMap
            pannable
            zoomable
            maskColor="color-mix(in oklab, var(--background) 78%, transparent)"
            className="!rounded-xl !border !border-border !bg-surface"
            nodeColor={(n) =>
              kindMeta[(n.data as FlowNodeData).kind]?.color ?? "var(--muted-foreground)"
            }
          />
        </ReactFlow>

        {selected && (
          <NodeConfigPanel
            node={selected}
            onClose={() => setSelectedId(null)}
            onChange={patchNode}
            onDelete={removeNode}
          />
        )}
      </div>
    </div>
  );
}
