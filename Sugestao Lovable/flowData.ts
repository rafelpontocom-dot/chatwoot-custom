import type { Edge, Node } from "@xyflow/react";
import type { FlowNodeData } from "./nodes";

export const initialNodes: Node<FlowNodeData>[] = [
  {
    id: "n1",
    type: "trigger",
    position: { x: 320, y: 0 },
    data: {
      kind: "trigger",
      title: "Conversa entra no Kanban",
      summary: "Dispara quando um card chega na coluna Novos leads.",
      chips: ["coluna: novo", "canal: qualquer"],
      config: {
        evento: "Card criado",
        coluna: "Novos leads",
        canal: "Todos",
        ativo: "sim",
      },
    },
  },
  {
    id: "n2",
    type: "action",
    position: { x: 320, y: 200 },
    data: {
      kind: "action",
      title: "Enviar boas-vindas",
      summary: "Template WhatsApp “grow_boasvindas” com o nome do contato.",
      chips: ["{{contato.nome}}"],
      config: {
        canal: "WhatsApp",
        template: "grow_boasvindas",
        mensagem: "Olá {{contato.nome}}! Obrigado pelo contato 👋",
      },
    },
  },
  {
    id: "n3",
    type: "condition",
    position: { x: 320, y: 400 },
    data: {
      kind: "condition",
      title: "Respondeu em até 15 min?",
      summary: "Avalia a última mensagem recebida do contato.",
      chips: ["último_evento < 15m"],
      config: {
        campo: "contato.ultima_resposta",
        operador: "menor que",
        valor: "15 minutos",
        senao: "seguir ramo Não",
      },
    },
  },
  {
    id: "n4",
    type: "action",
    position: { x: 60, y: 620 },
    data: {
      kind: "action",
      title: "Mover para Qualificação",
      summary: "Atualiza o card e atribui ao time comercial.",
      chips: ["coluna: qualificação"],
      config: {
        coluna: "Qualificação",
        responsavel: "Time comercial",
        tag: "lead-quente",
      },
    },
  },
  {
    id: "n5",
    type: "delay",
    position: { x: 580, y: 620 },
    data: {
      kind: "delay",
      title: "Aguardar 2 horas",
      summary: "Pausa antes do lembrete de follow-up.",
      chips: ["2h", "horário comercial"],
      config: {
        duracao: "2 horas",
        janela: "Somente horário comercial",
        fuso: "America/Sao_Paulo",
      },
    },
  },
  {
    id: "n6",
    type: "action",
    position: { x: 580, y: 820 },
    data: {
      kind: "action",
      title: "Lembrete + notificar atendente",
      summary: "Reenvia mensagem e cria nota interna no card.",
      chips: ["nota interna"],
      config: {
        canal: "WhatsApp",
        mensagem: "Ainda podemos ajudar? 🙂",
        notificar: "Camila",
      },
    },
  },
  {
    id: "n7",
    type: "exit",
    position: { x: 320, y: 1020 },
    data: {
      kind: "exit",
      title: "Encerrar automação",
      summary: "Registra o resultado e libera o card para o time.",
      config: { resultado: "concluída", registrar: "sim" },
    },
  },
];

const base = {
  animated: true,
  style: { stroke: "color-mix(in oklab, var(--foreground) 35%, transparent)" },
};

export const initialEdges: Edge[] = [
  { id: "e1", source: "n1", target: "n2", ...base },
  { id: "e2", source: "n2", target: "n3", ...base },
  {
    id: "e3",
    source: "n3",
    sourceHandle: "yes",
    target: "n4",
    label: "sim",
    ...base,
    style: { stroke: "var(--action)" },
  },
  {
    id: "e4",
    source: "n3",
    sourceHandle: "no",
    target: "n5",
    label: "não",
    ...base,
    style: { stroke: "var(--exit)" },
  },
  { id: "e5", source: "n5", target: "n6", ...base },
  { id: "e6", source: "n4", target: "n7", ...base },
  { id: "e7", source: "n6", target: "n7", ...base },
];
