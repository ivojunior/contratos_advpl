# Especificação de Dicionário de Dados — Contratos de Fornecedores

Este documento substitui um antigo fonte `UPDDICT.prw` que manipulava
diretamente as tabelas `SX2`/`SX3`/`SIX` via `RecLock`. Esse padrão é
**reprovado pela TOTVS CodeAnalysis (regra CA2004-2 — "Direct Access not
allowed in data dictionary")** e não substitui a criação física das
tabelas no banco, que só ocorre quando feita pela própria ferramenta.

Por isso, as tabelas `ZC1`, `ZC2` e `ZC3` devem ser criadas manualmente
(ou por importação de pacote de dicionário exportado por ela) através do
**Configurador (SIGACFG) > Base de Dados > Dicionário de Dados**. As
tabelas abaixo trazem todos os atributos necessários para o cadastro.

## Tabela ZC1 — Contratos de Fornecedores (cabeçalho)

**SX2**: Modo = Exclusivo por filial

| Campo | Tipo | Tam. | Dec. | Título | Descrição | Picture | F3 | Obrigatório |
|---|---|---|---|---|---|---|---|---|
| ZC1_FILIAL | C | 8 | - | Filial | Filial | @! | - | Não* |
| ZC1_CONTRA | C | 10 | - | Contrato | Número do Contrato | @! | - | Sim |
| ZC1_DESCR | C | 40 | - | Descricao | Descrição/objeto do contrato | @! | - | Sim |
| ZC1_FORNEC | C | 6 | - | Fornecedor | Código do Fornecedor | @! | SA2 | Sim |
| ZC1_LOJA | C | 2 | - | Loja | Loja do Fornecedor | @! | - | Sim |
| ZC1_DTINI | D | 8 | - | Dt.Inicio | Data de início da vigência | - | - | Sim |
| ZC1_DTFIM | D | 8 | - | Dt.Fim | Data de término da vigência | - | - | Sim |
| ZC1_VALOR | N | 17 | 2 | Vl.Mensal | Valor da mensalidade vigente | @E 999,999,999.99 | - | Sim |
| ZC1_VALORI | N | 17 | 2 | Vl.Original | Valor mensal original do contrato | @E 999,999,999.99 | - | Não |
| ZC1_CONDPG | C | 3 | - | Cond.Pagto | Condição de pagamento | @! | SE4 | Sim |
| ZC1_INDICE | C | 6 | - | Indice | Índice de reajuste (ZC3) | @! | - | Não |
| ZC1_PERREA | N | 3 | 0 | Period.Reaj. | Periodicidade do reajuste (meses) | 999 | - | Não |
| ZC1_DTULTR | D | 8 | - | Dt.Ult.Reaj. | Data do último reajuste aplicado | - | - | Não |
| ZC1_PRODUT | C | 15 | - | Produto | Produto/serviço usado no pedido | @! | SB1 | Sim |
| ZC1_UM | C | 2 | - | UM | Unidade de medida | @! | - | Sim |
| ZC1_CC | C | 9 | - | Cent.Custo | Centro de custo | @! | CTT | Sim |
| ZC1_COMPRA | C | 6 | - | Comprador | Código do comprador | @! | SY1 | Não |
| ZC1_TES | C | 3 | - | TES | Tipo de entrada/saída | @! | SF4 | Não |
| ZC1_QTDPAR | N | 3 | 0 | Qtd.Parcelas | Total de mensalidades previstas | 999 | - | Não (calculado) |
| ZC1_QTDEMI | N | 3 | 0 | Qtd.Emitidas | Mensalidades/pedidos já emitidos | 999 | - | Não (calculado) |
| ZC1_QTDFAL | N | 3 | 0 | Qtd.Faltam | Mensalidades restantes até o fim | 999 | - | Não (calculado) |
| ZC1_COMPET | C | 6 | - | Ult.Compet. | Última competência gerada AAAAMM | 999999 | - | Não (calculado) |
| ZC1_DTULGE | D | 8 | - | Dt.Ult.Ger. | Data da última geração de pedido | - | - | Não (calculado) |
| ZC1_STATUS | C | 1 | - | Status | 1=Ativo 2=Suspenso 3=Encerrado 4=Cancelado | @! | - | Sim |
| ZC1_OBS | M | 10** | - | Observacao | Observações do contrato | - | - | Não |

\* preenchido automaticamente pelo framework (`xFilial`).
\*\* campo Memo: tamanho 10 corresponde ao ponteiro de bloco no DBF; ajustar conforme padrão do RDBMS em uso.

**Índice (SIX) 1**: `ZC1_FILIAL+ZC1_CONTRA` (único) — descrição "Filial+Contrato"

## Tabela ZC2 — Histórico de Pedidos Gerados por Contrato

**SX2**: Modo = Exclusivo por filial

| Campo | Tipo | Tam. | Dec. | Título | Descrição | Picture | F3 | Obrigatório |
|---|---|---|---|---|---|---|---|---|
| ZC2_FILIAL | C | 8 | - | Filial | Filial | @! | - | Não* |
| ZC2_CONTRA | C | 10 | - | Contrato | Número do Contrato (ZC1) | @! | ZC1*** | Sim |
| ZC2_SEQ | C | 4 | - | Sequencia | Sequência da parcela gerada | 9999 | - | Sim |
| ZC2_COMPET | C | 6 | - | Competenc. | Competência AAAAMM | 999999 | - | Sim |
| ZC2_NUMPC | C | 6 | - | Num.Pedido | Número do Pedido de Compra (SC7) | @! | SC7 | Sim |
| ZC2_VALOR | N | 17 | 2 | Valor | Valor gerado na parcela | @E 999,999,999.99 | - | Sim |
| ZC2_DTGER | D | 8 | - | Dt.Geracao | Data em que o pedido foi gerado | - | - | Sim |
| ZC2_USUARI | C | 20 | - | Usuario | Usuário/job que gerou o pedido | @! | - | Sim |
| ZC2_STATUS | C | 1 | - | Status | P=Pedido Gerado C=Cancelado | @! | - | Sim |

\*\*\* o F3 de `ZC1` precisa ser configurado no Configurador (aba "Índice/Consulta Padrão") junto com a criação da tabela; não existe consulta pronta para tabelas customizadas.

**Índice (SIX) 1**: `ZC2_FILIAL+ZC2_CONTRA+ZC2_SEQ` (único) — descrição "Filial+Contrato+Sequencia"

## Tabela ZC3 — Índices de Reajuste

**SX2**: Modo = Compartilhado entre filiais

| Campo | Tipo | Tam. | Dec. | Título | Descrição | Picture | Obrigatório |
|---|---|---|---|---|---|---|---|
| ZC3_FILIAL | C | 8 | - | Filial | Filial | @! | Não* |
| ZC3_INDICE | C | 6 | - | Indice | Código do índice (ex: IGPM) | @! | Sim |
| ZC3_DESCR | C | 30 | - | Descricao | Descrição do índice | @! | Não |
| ZC3_COMPET | C | 6 | - | Competenc. | Competência AAAAMM | 999999 | Sim |
| ZC3_PERC | N | 7 | 4 | Percentual | Percentual do índice no mês | @E 999.9999 | Sim |

**Índice (SIX) 1**: `ZC3_FILIAL+ZC3_INDICE+ZC3_COMPET` (único) — descrição "Filial+Indice+Competencia"

## Passo a passo no Configurador

1. **Base de Dados > Dicionário de Dados > Tabelas** — criar `ZC1`, `ZC2` e `ZC3`, com os modos indicados acima.
2. Dentro de cada tabela, cadastrar os campos exatamente como especificado (nome, tipo, tamanho, decimal, título, descrição, picture, obrigatoriedade e F3 quando indicado).
3. Cadastrar os índices (SIX) listados para cada tabela.
4. Confirmar a criação/gravação para que o Configurador execute a materialização física das tabelas no RDBMS.
5. Repetir o procedimento em todos os ambientes (desenvolvimento, homologação, produção) — ou exportar o dicionário criado em desenvolvimento (menu de exportação do próprio Configurador) e importar nos demais ambientes, mantendo esse arquivo exportado versionado neste repositório como origem de verdade reprodutível.
