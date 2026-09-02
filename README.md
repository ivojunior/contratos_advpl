# contratos_advpl

Gestão de contratos de fornecedor — rotina em ADVPL para TOTVS Protheus.

## Visão geral

A solução é composta por 4 tabelas customizadas e 4 rotinas:

| Tabela | Descrição |
|---|---|
| `ZC1` | Cabeçalho do contrato de fornecedor (fornecedor, vigência, valor da mensalidade, condição de pagamento, índice/periodicidade de reajuste, produto/CC/natureza usados no pedido e na previsão financeira, contadores de mensalidades) |
| `ZC2` | Histórico de pedidos de compra gerados por contrato (uma linha por mensalidade emitida) |
| `ZC3` | Índices de reajuste — percentual mensal de cada índice (ex: IGPM, IPCA, INPC), alimentado manualmente ou por integração |
| `ZC4` | Controle das previsões financeiras (títulos "PR") geradas no Contas a Pagar por contrato/parcela |

| Fonte | Rotina | Descrição |
|---|---|---|
| `src/dictionary/especificacao_dicionario.md` | — | Especificação das tabelas/campos/índices `ZC1`, `ZC2`, `ZC3` e `ZC4` para cadastro no Configurador (ver observação abaixo) |
| `src/contratos/ZCT010.prw` | `ZCT010` | Cadastro (MVC) dos contratos de fornecedores |
| `src/contratos/ZCT030.prw` | `ZCT030` | Cadastro auxiliar dos índices de reajuste (ZC3) |
| `src/contratos/ZCT020.prw` | `ZCT020` / `U_ZCT020JOB()` | Geração mensal dos pedidos de compra referentes à mensalidade vigente |
| `src/contratos/ZCT040.prw` | `ZCT040` | Previsão financeira: gera/baixa títulos "PR" no Contas a Pagar para as parcelas futuras do contrato |
| `src/contratos/ZCTFUN.prw` | — | Funções utilitárias compartilhadas (cálculo de parcelas, cálculo de reajuste, geração do pedido via `MSExecAuto`) |

## Como instalar

1. Criar as tabelas `ZC1`, `ZC2`, `ZC3` e `ZC4` (campos e índices) pelo **Configurador (SIGACFG) > Base de Dados > Dicionário de Dados**, seguindo a especificação em `src/dictionary/especificacao_dicionario.md`. Essa é a única forma suportada de criar/alterar dicionário de dados no Protheus — ver observação abaixo sobre por que não há um fonte `.prw` fazendo isso automaticamente.
2. Compilar todos os fontes de `src/contratos` no RPO do ambiente (via TDS/AppServer).
3. Incluir `ZCT010` (Contratos), `ZCT030` (Índices), `ZCT020` (Geração Mensal) e `ZCT040` (Previsão Financeira) no menu do(s) módulo(s) desejado(s) (ex: Compras/SIGACOM e Financeiro/SIGAFIN), associando os respectivos `CtrlClass`/programas no **Configurador > Ambiente > Cadastros > Menu**.
4. (Opcional) Cadastrar `U_ZCT020JOB()` no **Agendador de Tarefas (Schedule)** do Configurador para rodar automaticamente todo início de mês, dispensando execução manual.

## Fluxo de uso

1. **Cadastrar o contrato** (`ZCT010`): fornecedor/loja, início e fim de vigência, valor da mensalidade, condição de pagamento, índice e periodicidade de reajuste (em meses; deixe vazio se o contrato não tiver reajuste), produto/serviço, UM, centro de custo e comprador que serão usados na emissão do pedido. Ao gravar, o sistema calcula automaticamente a quantidade total de mensalidades previstas (`ZC1_QTDPAR`) e inicializa os contadores de emitidas (`ZC1_QTDEMI`) e faltantes (`ZC1_QTDFAL`).
2. **Alimentar os índices** (`ZCT030`), quando o contrato tiver reajuste: cadastrar mês a mês o percentual do índice utilizado.
3. **Gerar as mensalidades** (`ZCT020`, mensalmente ou via job agendado, ou pelo botão **"Gerar Pedidos Mensais"** em "Outras Ações" do browse de `ZCT010`): a rotina localiza todos os contratos ativos vigentes na competência informada e ainda não processados nela, verifica se é o mês de reajuste (com base em `ZC1_PERREA` e nos percentuais cadastrados em `ZC3`, aplicando o percentual acumulado sobre o valor vigente), gera o pedido de compra (`SC7`) via `MSExecAuto`/`MATA120` e:
   - incrementa `ZC1_QTDEMI` (mensalidades emitidas);
   - recalcula `ZC1_QTDFAL` (mensalidades restantes até o fim do contrato);
   - grava a competência e a data da última geração;
   - grava uma linha em `ZC2` com o número do pedido gerado;
   - encerra automaticamente o contrato (`ZC1_STATUS = "3"`) quando não restarem mensalidades ou a vigência tiver terminado.

A rotina pode ser executada em modo simulação (sem gerar pedidos, apenas exibindo o valor que seria faturado, inclusive já considerando reajuste) antes da geração efetiva.

4. **Previsão financeira** (`ZCT040`, disparada pelo analista financeiro quando desejar, ou pelo botão **"Previsão Financeira"** em "Outras Ações" do browse de `ZCT010`): para cada contrato ativo, gera no Contas a Pagar (`SE2`) um título tipo **Previsão ("PR")** para cada parcela futura ainda não faturada, até o fim da vigência do contrato — permitindo visualizar o comprometimento financeiro futuro antes de existir pedido/fatura real. A mesma execução também **baixa (exclui)** as previsões que deixaram de fazer sentido:
   - quando a parcela correspondente já foi realmente faturada e o pedido de compra gerado por ela foi **totalmente atendido** (`SC7.C7_QUJE >= SC7.C7_QUANT`);
   - quando o contrato deixou de estar ativo (suspenso/encerrado/cancelado) antes de consumir todas as parcelas previstas.

   Esse controle de baixa (`ZCTBaixaPrevisoes()`) também roda automaticamente a cada execução de `ZCT020` (mensal ou via job), então as previsões tendem a ficar em dia mesmo sem o analista rodar `ZCT040` com frequência — mas a geração de novas previsões só ocorre quando `ZCT040` é executada.

   Limitação conhecida: a previsão usa o valor vigente do contrato (`ZC1_VALOR`) para todas as parcelas futuras — reajustes que ainda vão ocorrer durante a vigência não são projetados antecipadamente (a previsão se corrige sozinha na próxima vez que `ZCT040` rodar após o reajuste ser efetivamente aplicado por `ZCT020`).

## Observações de implementação

- Em `ModelDef()` (`ZCT010.prw`), a validação/ajuste de campos calculados (datas, quantidade de parcelas) é passada como **3º parâmetro** de `MPFormModel():New()` (`bPosValidacao`, disparado ao confirmar a tela), nunca como o **4º** (`bCommit`): quando `bCommit` é informado, ele substitui a gravação automática do MVC — o próprio `RecLock`/`MsUnlock` passa a ser responsabilidade do bloco informado. Usá-lo apenas para validação (retornando `.T.`/`.F.` sem gravar nada) faz a tela exibir "gravado com sucesso" sem que nada seja persistido na tabela — foi exatamente esse bug corrigido aqui.
- A criação do dicionário de dados **não é feita por fonte AdvPL**. O TOTVS CodeAnalysis reprova (regra `CA2004-2`) qualquer acesso direto (`RecLock`/gravação) às tabelas de metadados `SX1/SX2/SX3/SIX`, e mesmo que a gravação fosse feita dessa forma, a criação física da tabela no RDBMS só ocorre quando realizada pelo próprio Configurador. Por isso a estrutura das tabelas está documentada em `src/dictionary/especificacao_dicionario.md` para cadastro manual (ou importação de pacote de dicionário exportado do Configurador).
- Os nomes de rotina (`ZCT010`, `ZCT020`, `ZCT030`) e os campos (`ZC1_*`, `ZC2_*`, `ZC3_*`) seguem a faixa reservada a customizações (`Z*`); ajuste os prefixos se já existir convenção própria no ambiente.
- A geração do pedido usa `MATA120` via `MSExecAuto` (inclusão, tipo `3`); campos adicionais obrigatórios no ambiente (ex: natureza, tipo de pedido) podem precisar ser incluídos em `ZCTGeraPC()` conforme a parametrização de Compras da empresa.
- Este código foi desenvolvido como referência funcional seguindo os padrões MVC do Protheus 12; pequenos ajustes de API podem ser necessários conforme a versão exata do `TOTVS Application Server`/build em uso.
- `ZCTFUN.prw` carrega os percentuais de `ZC3` uma única vez por execução (`ZCTCarregaZC3()`) e repassa o resultado em memória para `ZCTValIndice()`, em vez de consultar o banco a cada contrato dentro do laço de `ZCT020` — evita o padrão de "chamada de API/SQL dentro de laço" sinalizado pelo CodeAnalysis.
- Em `ZCTGeraPC()`, `lMsErroAuto` e `lAutoErrNoFile` são declaradas `Private` (nunca `Local`): o `MSExecAuto`/`MATA120` sinaliza erro por escopo dinâmico de variáveis Private, e `lAutoErrNoFile` é o que desvia o log para `GetAutoGRLog()` (que retorna um array de linhas, não uma string) em vez de gravar em arquivo/tela — necessário para a rotina funcionar tanto interativa quanto via job desassistido.
- A previsão financeira (`ZCT040`/`ZCTFUN.prw`) cria e exclui títulos de Contas a Pagar exclusivamente via `MSExecAuto`/`FINA050` (nunca por `RecLock` direto na `SE2`, que é tabela nativa do Financeiro) — mesmo princípio já aplicado a `SC7` em `ZCTGeraPC()`. Pela mesma razão de `lMsErroAuto`, `ZCTIncluiPR()`/`ZCTExcluiPR()` também declaram essas variáveis como `Private`.
- **Atenção na exclusão via `FINA050`**: ao contrário da inclusão, a exclusão por `ExecAuto` opera sobre o registro **corrente** da `SE2` — se o registro não estiver posicionado na chave correta antes da chamada, o `FINA050` pode excluir o primeiro título encontrado na tabela em vez do pretendido (armadilha real, relatada na comunidade TOTVS). Por isso `ZCTExcluiPR()` sempre posiciona a `SE2` pela chave completa e confere `E2_TIPO = "PR"` antes de excluir, abortando a operação por segurança se o registro não for exatamente uma previsão. Ainda assim, **teste esse fluxo exaustivamente em homologação** antes de liberar em produção, dado o histórico de relatos de comportamento inconsistente desse ExecAuto na comunidade.
- `ZC1_CONTRA` (e `ZC2_CONTRA`/`ZC4_CONTRA`) têm tamanho 9, não 10: a previsão financeira usa o número do contrato como `E2_NUM` da `SE2`, campo nativo limitado a 9 posições. Se as tabelas já foram criadas com 10 posições antes desta mudança, ajuste pelo Configurador antes de usar `ZCT040`.
- `ZC1_NATUR` é um campo novo em `ZC1`, obrigatório apenas para quem for usar `ZCT040` (natureza financeira gravada em `E2_NATUREZ`). Se `ZC1` já existia antes desta funcionalidade, adicione o campo pelo Configurador e preencha-o nos contratos existentes antes de gerar previsões para eles.
- A baixa automática de previsões atendidas roda a cada execução de `ZCT020`, mas a *geração* de novas previsões só acontece quando `ZCT040` é executada — não há job agendado sugerido para `ZCT040` porque criar previsões para muitos meses à frente sem revisão do analista pode não ser desejável em todo ambiente; avalie se faz sentido agendá-la também.
