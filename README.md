# contratos_advpl

Gestão de contratos de fornecedor — rotina em ADVPL para TOTVS Protheus.

## Visão geral

A solução é composta por 3 tabelas customizadas e 3 rotinas:

| Tabela | Descrição |
|---|---|
| `ZC1` | Cabeçalho do contrato de fornecedor (fornecedor, vigência, valor da mensalidade, condição de pagamento, índice/periodicidade de reajuste, produto/CC usados no pedido, contadores de mensalidades) |
| `ZC2` | Histórico de pedidos de compra gerados por contrato (uma linha por mensalidade emitida) |
| `ZC3` | Índices de reajuste — percentual mensal de cada índice (ex: IGPM, IPCA, INPC), alimentado manualmente ou por integração |

| Fonte | Rotina | Descrição |
|---|---|---|
| `src/dictionary/UPDDICT.prw` | `U_UPDDICT()` | Cria os campos/tabelas/índices no dicionário de dados (SX2/SX3/SIX) |
| `src/contratos/ZCT010.prw` | `ZCT010` | Cadastro (MVC) dos contratos de fornecedores |
| `src/contratos/ZCT030.prw` | `ZCT030` | Cadastro auxiliar dos índices de reajuste (ZC3) |
| `src/contratos/ZCT020.prw` | `ZCT020` / `U_ZCT020JOB()` | Geração mensal dos pedidos de compra referentes à mensalidade vigente |
| `src/contratos/ZCTFUN.prw` | — | Funções utilitárias compartilhadas (cálculo de parcelas, cálculo de reajuste, geração do pedido via `MSExecAuto`) |

## Como instalar

1. Compilar todos os fontes de `src/` no RPO do ambiente (via TDS/AppServer).
2. Executar `U_UPDDICT()` uma única vez para gravar a estrutura das tabelas `ZC1`, `ZC2` e `ZC3` no dicionário de dados.
3. Acessar o **Configurador (SIGACFG) > Base de Dados > Dicionário de Dados** e rodar a atualização/materialização de base para que as tabelas sejam criadas fisicamente no RDBMS.
4. Incluir `ZCT010` (Contratos), `ZCT030` (Índices) e `ZCT020` (Geração Mensal) no menu do módulo desejado (ex: Compras/SIGACOM), associando os respectivos `CtrlClass`/programas no **Configurador > Ambiente > Cadastros > Menu**.
5. (Opcional) Cadastrar `U_ZCT020JOB()` no **Agendador de Tarefas (Schedule)** do Configurador para rodar automaticamente todo início de mês, dispensando execução manual.

## Fluxo de uso

1. **Cadastrar o contrato** (`ZCT010`): fornecedor/loja, início e fim de vigência, valor da mensalidade, condição de pagamento, índice e periodicidade de reajuste (em meses; deixe vazio se o contrato não tiver reajuste), produto/serviço, UM, centro de custo e comprador que serão usados na emissão do pedido. Ao gravar, o sistema calcula automaticamente a quantidade total de mensalidades previstas (`ZC1_QTDPAR`) e inicializa os contadores de emitidas (`ZC1_QTDEMI`) e faltantes (`ZC1_QTDFAL`).
2. **Alimentar os índices** (`ZCT030`), quando o contrato tiver reajuste: cadastrar mês a mês o percentual do índice utilizado.
3. **Gerar as mensalidades** (`ZCT020`, mensalmente ou via job agendado): a rotina localiza todos os contratos ativos vigentes na competência informada e ainda não processados nela, verifica se é o mês de reajuste (com base em `ZC1_PERREA` e nos percentuais cadastrados em `ZC3`, aplicando o percentual acumulado sobre o valor vigente), gera o pedido de compra (`SC7`) via `MSExecAuto`/`MATA120` e:
   - incrementa `ZC1_QTDEMI` (mensalidades emitidas);
   - recalcula `ZC1_QTDFAL` (mensalidades restantes até o fim do contrato);
   - grava a competência e a data da última geração;
   - grava uma linha em `ZC2` com o número do pedido gerado;
   - encerra automaticamente o contrato (`ZC1_STATUS = "3"`) quando não restarem mensalidades ou a vigência tiver terminado.

A rotina pode ser executada em modo simulação (sem gerar pedidos, apenas exibindo o valor que seria faturado, inclusive já considerando reajuste) antes da geração efetiva.

## Observações de implementação

- O fonte `UPDDICT.prw` grava a definição das tabelas diretamente no SX2/SX3/SIX; ele não substitui a etapa de materialização física da tabela no banco (feita pelo próprio Protheus/Configurador).
- Os nomes de rotina (`ZCT010`, `ZCT020`, `ZCT030`) e os campos (`ZC1_*`, `ZC2_*`, `ZC3_*`) seguem a faixa reservada a customizações (`Z*`); ajuste os prefixos se já existir convenção própria no ambiente.
- A geração do pedido usa `MATA120` via `MSExecAuto` (inclusão, tipo `3`); campos adicionais obrigatórios no ambiente (ex: natureza, tipo de pedido) podem precisar ser incluídos em `ZCTGeraPC()` conforme a parametrização de Compras da empresa.
- Este código foi desenvolvido como referência funcional seguindo os padrões MVC do Protheus 12; pequenos ajustes de API podem ser necessários conforme a versão exata do `TOTVS Application Server`/build em uso.
