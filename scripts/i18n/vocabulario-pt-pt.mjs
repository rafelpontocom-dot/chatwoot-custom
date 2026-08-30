/**
 * Raevo — vocabulário pt-BR → pt-PT.
 *
 * O catálogo `pt` do Chatwoot tem um terço das frases ainda em inglês. Copiar
 * de `pt_BR` fecha esse buraco, mas copiar sem adaptar entrega português do
 * Brasil a uma clínica portuguesa. Este mapa cobre as divergências que aparecem
 * em interface — não é tradução literária, é o vocabulário que o utilizador lê.
 *
 * Regra: só entra aqui par cuja troca é sempre correta no contexto de produto.
 * Palavra ambígua (ex.: "ligar", que é tanto telefonar como ativar) fica de fora.
 */
export const VOCABULARIO = [
  ['usuário', 'utilizador'],
  ['usuários', 'utilizadores'],
  ['contato', 'contacto'],
  ['contatos', 'contactos'],
  ['arquivo', 'ficheiro'],
  ['arquivos', 'ficheiros'],
  ['arquivar', 'arquivar'],
  ['tela', 'ecrã'],
  ['telas', 'ecrãs'],
  ['time', 'equipa'],
  ['times', 'equipas'],
  ['gerenciar', 'gerir'],
  ['gerenciamento', 'gestão'],
  ['gerenciado', 'gerido'],
  ['gerenciada', 'gerida'],
  ['excluir', 'eliminar'],
  ['excluído', 'eliminado'],
  ['excluída', 'eliminada'],
  ['deletar', 'eliminar'],
  ['aplicativo', 'aplicação'],
  ['aplicativos', 'aplicações'],
  ['cadastro', 'registo'],
  ['cadastrar', 'registar'],
  ['registro', 'registo'],
  ['registros', 'registos'],
  ['celular', 'telemóvel'],
  ['bate-papo', 'conversa'],
  ['planilha', 'folha de cálculo'],
  ['baixar', 'transferir'],
  ['tela cheia', 'ecrã inteiro'],
  ['atualizar', 'atualizar'],
  ['salvar', 'guardar'],
  ['salvo', 'guardado'],
  ['salva', 'guardada'],
  ['salvas', 'guardadas'],
  ['salvos', 'guardados'],
  ['apelido', 'nome curto'],
];

const preservaCaixa = (original, substituto) => {
  if (original === original.toUpperCase() && original.length > 1) {
    return substituto.toUpperCase();
  }
  if (original[0] === original[0].toUpperCase()) {
    return substituto[0].toUpperCase() + substituto.slice(1);
  }
  return substituto;
};

/** Aplica o vocabulário respeitando limites de palavra e a caixa original. */
export const paraPortugalDePortugal = texto => {
  let saida = texto;
  // Ordena por tamanho: "gerenciamento" antes de "gerenciar".
  const pares = [...VOCABULARIO].sort((a, b) => b[0].length - a[0].length);
  pares.forEach(([de, para]) => {
    if (de === para) return;
    const padrao = new RegExp(`(?<![\\p{L}])${de}(?![\\p{L}])`, 'giu');
    saida = saida.replace(padrao, encontrado =>
      preservaCaixa(encontrado, para)
    );
  });
  return saida;
};
