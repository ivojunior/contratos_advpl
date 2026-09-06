# Manual do Usuário — Contratos de Fornecedores

Documentação de processo operacional do módulo de **Contratos de Fornecedores**. Este manual descreve, do ponto de vista de quem opera o sistema no dia a dia (analista de compras/financeiro), **o que cada rotina faz e como usá-la**. Para detalhes técnicos de implementação (AdvPL, dicionário de dados), consulte `README.md` e `src/dictionary/especificacao_dicionario.md`.

## Sumário

1. [Visão geral do módulo](#1-visão-geral-do-módulo)
2. [Cadastro de Contratos (ZCT010)](#2-cadastro-de-contratos-zct010)
3. [Cadastro de Índices de Reajuste (ZCT030)](#3-cadastro-de-índices-de-reajuste-zct030)
4. [Gerar Pedidos Mensais (ZCT020)](#4-gerar-pedidos-mensais-zct020)
5. [Desfazer Geração Mensal (ZCT025)](#5-desfazer-geração-mensal-zct025)
6. [Renovar Contrato (ZCTRenova)](#6-renovar-contrato-zctrenova)
7. [Previsão Financeira (ZCT040)](#7-previsão-financeira-zct040)
8. [Ciclo de vida de um contrato](#8-ciclo-de-vida-de-um-contrato)
9. [Perguntas frequentes / cuidados operacionais](#9-perguntas-frequentes--cuidados-operacionais)

---

## 1. Visão geral do módulo

O módulo controla contratos de fornecimento recorrente (aluguéis, mensalidades de serviço, etc.) e automatiza, mês a mês:

- a **emissão do pedido de compra** referente à mensalidade vigente do contrato;
- a aplicação de **reajuste** do valor, quando o contrato tiver um índice e periodicidade configurados;
- a criação de **previsões no Contas a Pagar** para as mensalidades futuras ainda não faturadas, dando visibilidade do comprometimento financeiro antes de o pedido existir.

Todas as rotinas ficam disponíveis a partir do **browse de Contratos** (`ZCT010`). As ações que não são de cadastro simples (gerar pedidos, desfazer, renovar, previsão) aparecem agrupadas no menu **"Outras Ações"** da tela.

### Status do contrato

O browse de `ZCT010` identifica o status de cada contrato por cor:

| Cor | Status | Código (`ZC1_STATUS`) | Significado |
|---|---|---|---|
| 🟢 Verde | Ativo | `1` | Contrato em vigência, gerando pedidos normalmente |
| 🟡 Amarelo | Suspenso | `2` | Contrato temporariamente parado (ajuste manual) |
| 🔵 Azul | Encerrado | `3` | Vigência terminada ou todas as mensalidades já emitidas |
| 🔴 Vermelho | Cancelado | `4` | Contrato cancelado |

> O status `Encerrado` é atribuído **automaticamente** pelo sistema (ver seção 4); `Suspenso` e `Cancelado` são ajustados manualmente pelo usuário, alterando o campo Status na tela de alteração do contrato.

---

## 2. Cadastro de Contratos (ZCT010)

Tela de cadastro (Incluir/Alterar/Excluir/Visualizar) de cada contrato de fornecimento.

### Campos da tela

| Campo | Descrição | Preenchimento |
|---|---|---|
| Contrato | Número do contrato | **Automático** (sequencial) — não digitável |
| Descrição | Descrição/objeto do contrato | Manual |
| Fornecedor / Loja | Código e loja do fornecedor (SA2) | Manual |
| Nome Fornec. | Nome do fornecedor | Automático (exibido apenas para conferência) |
| Dt.Início / Dt.Fim | Início e fim da vigência do contrato | Manual |
| Vl.Mensal | Valor da mensalidade vigente | Manual na inclusão (depois é atualizado automaticamente a cada reajuste) |
| Vl.Original | Valor mensal original do contrato, antes de qualquer reajuste | **Automático** — o sistema preenche sozinho com o Vl.Mensal informado na inclusão e o campo fica bloqueado para edição (não digitável), inclusive na Alteração. Não é mais atualizado depois disso, mesmo com reajustes |
| Cond.Pagto | Condição de pagamento (SE4) | Manual |
| Índice | Índice de reajuste a aplicar (cadastrado em `ZCT030`) | Manual — deixe em branco se o contrato não tiver reajuste |
| Period.Reaj. | Periodicidade do reajuste, em meses (ex.: `12` para reajuste anual) | Manual — obrigatório apenas se um Índice for informado |
| Dt.Ult.Reaj. | Data do último reajuste aplicado | Automático |
| Produto | Produto/serviço (SB1) usado na emissão do pedido de compra | Manual |
| UM | Unidade de medida | Automático (vem do cadastro do produto) |
| Cent.Custo | Centro de custo debitado no pedido | Manual |
| TES | Tipo de entrada/saída do pedido | Manual |
| Tp.Operação | Tipo de operação usado no pedido de compra | Manual, se aplicável no ambiente |
| Natureza | Natureza financeira usada na previsão do Contas a Pagar | Manual — obrigatório se a Previsão Financeira (seção 7) for utilizada |
| Qtd.Parcelas | Total de mensalidades previstas na vigência | Automático (calculado a partir de Dt.Início/Dt.Fim) |
| Qtd.Emitidas | Quantas mensalidades já foram faturadas (pedidos gerados) | Automático |
| Qtd.Faltam | Quantas mensalidades ainda faltam gerar | Automático |
| Ult.Compet. | Última competência (mês/ano) em que um pedido foi gerado | Automático |
| Dt.Ult.Ger. | Data da última geração de pedido | Automático |
| Status | Ativo / Suspenso / Encerrado / Cancelado | Manual para Suspender/Cancelar; automático para Encerrar |
| Observação | Texto livre | Manual |

### Como incluir um contrato

1. Acesse o browse de Contratos (`ZCT010`) e clique em **Incluir**.
2. Informe fornecedor/loja, descrição, vigência (Dt.Início/Dt.Fim) e o valor da mensalidade.
3. Se o contrato tiver reajuste, informe o Índice (previamente cadastrado em `ZCT030` — ver seção 3) e a periodicidade em meses.
4. Informe produto, centro de custo, condição de pagamento e demais dados usados na emissão do pedido de compra.
5. Se for utilizar a Previsão Financeira (seção 7), preencha também a Natureza financeira.
6. Confirme. O sistema calcula automaticamente a quantidade total de mensalidades (`Qtd.Parcelas`) a partir da vigência informada.

### Alterar / Excluir / Visualizar

Seguem o padrão do Protheus: posicione o cursor no contrato desejado no browse e acione a opção correspondente. Campos calculados/automáticos (UM, Qtd.Parcelas, Qtd.Emitidas, Qtd.Faltam, Ult.Compet., Dt.Ult.Ger., Dt.Ult.Reaj.) aparecem bloqueados para edição.

> **Atenção**: alterar manualmente Dt.Início/Dt.Fim de um contrato já em andamento recalcula `Qtd.Parcelas` — se o contrato já tiver mensalidades emitidas, confira se `Qtd.Faltam` fica coerente após a alteração.

---

## 3. Cadastro de Índices de Reajuste (ZCT030)

Tela auxiliar onde o analista alimenta, **mês a mês**, o percentual de cada índice de reajuste (ex.: IGPM, IPCA, INPC) que será usado para reajustar automaticamente o valor de contratos vinculados a ele.

### Campos da tela

| Campo | Descrição |
|---|---|
| Índice | Código do índice (ex.: `IGPM`) |
| Descrição | Descrição do índice |
| Competência | Mês/ano de referência do percentual, formato `AAAAMM` |
| Percentual | Percentual do índice naquela competência |

### Como usar

1. Todo mês (ou conforme o índice for divulgado), acesse `ZCT030` e clique em **Incluir**.
2. Informe o código do índice, a competência (`AAAAMM`) e o percentual do mês.
3. Confirme.

> Um contrato só é reajustado automaticamente pela **Geração Mensal** (seção 4) se o índice da competência devida já estiver cadastrado aqui. Se faltar o percentual do mês, o reajuste simplesmente não é aplicado naquela execução — mantenha o cadastro em dia.

---

## 4. Gerar Pedidos Mensais (ZCT020)

Rotina que, uma vez por mês, **emite o pedido de compra** referente à mensalidade vigente de cada contrato ativo, aplicando reajuste quando devido.

Acesso: browse de `ZCT010` → **Outras Ações → Gerar Pedidos Mensais**.

### Tela de parâmetros

| Campo | Descrição |
|---|---|
| Mês / Ano | Competência a processar (padrão: mês/ano atual) |
| Contrato de: / Contrato até: | Faixa de contratos a processar (em branco = todos) |
| Confirma a geração dos pedidos? | `Sim` executa de fato; `Não` cancela a operação |

### O que a rotina faz

Para cada contrato **ativo** dentro da faixa informada, vigente na competência e ainda não processado naquela competência:

1. Verifica se é o mês de reajuste (com base na periodicidade e no índice cadastrado em `ZCT030`) e, se for, recalcula o valor da mensalidade.
2. Gera o **pedido de compra** com os dados cadastrados no contrato.
3. Atualiza os contadores do contrato: mensalidades emitidas, mensalidades restantes, última competência e data de geração.
4. Se não restarem mais mensalidades a gerar, ou a vigência tiver terminado, **encerra automaticamente o contrato** (Status = Encerrado).

Ao final, é exibido um resumo com os contratos processados com sucesso e as falhas ocorridas.

### Modo simulação

Antes de confirmar (`"Confirma a geração dos pedidos?" = Não`), a rotina pode ser usada para **simular**: mostra o valor que seria faturado (já considerando reajuste, se houver) sem realmente gerar nenhum pedido — útil para conferir antes de rodar a geração de verdade.

### Execução automática (job)

A geração também pode ser agendada para rodar sozinha todo início de mês (ponto de entrada `ZCT020JOB`, cadastrado no Agendador de Tarefas do Configurador). Nesse modo, todos os contratos são processados, sem tela de confirmação.

---

## 5. Desfazer Geração Mensal (ZCT025)

Rotina para **cancelar** os pedidos gerados por uma execução da Geração Mensal (seção 4) numa competência específica — útil quando se percebe um erro no cadastro do contrato ou no pedido logo após a geração, permitindo corrigir e gerar novamente sem duplicar mensalidade.

Acesso: browse de `ZCT010` → **Outras Ações → Desfazer Geração Mensal**.

### Tela de parâmetros

| Campo | Descrição |
|---|---|
| Mês / Ano | Competência a desfazer |
| Contrato (vazio = todos) | Restringe o desfazimento a um único contrato; em branco desfaz todos os pedidos daquela competência |
| Confirma o desfazimento dos pedidos? | `Sim` executa; `Não` cancela |

### O que a rotina faz, e o que ela NÃO faz

- **Só desfaz pedidos que ainda não tiveram nenhum recebimento.** Se algum item do pedido já foi recebido/faturado, aquele pedido é **pulado** (aparece na lista de ocorrências do resultado) e precisa ser tratado manualmente pela tela padrão de Compras.
- Ao desfazer um pedido com sucesso, a rotina:
  - exclui o pedido de compra gerado;
  - reverte os contadores do contrato (mensalidades emitidas/faltantes);
  - reabre o contrato (volta para Ativo) caso ele tivesse sido encerrado automaticamente por aquela mesma geração.
- **Limitação conhecida**: se a geração desfeita tiver aplicado reajuste, o valor da mensalidade **não** é revertido automaticamente para o valor anterior ao reajuste — se isso ocorrer, corrija manualmente o valor no cadastro do contrato.

Ao final, é exibido um resumo com a quantidade de pedidos desfeitos, quantos ficaram bloqueados (com recebimento) e o detalhe de cada ocorrência.

---

## 6. Renovar Contrato (ZCTRenova)

Rotina para renovar um contrato que já **encerrou** (Status = Encerrado), criando automaticamente um **novo contrato** com uma nova vigência, sem precisar redigitar os dados do fornecedor/produto/condições que se repetem.

Acesso: browse de `ZCT010` → posicione o cursor no contrato **Encerrado** a renovar → **Outras Ações → Renovar Contrato**.

> Se o contrato posicionado não estiver com Status = Encerrado, o sistema exibe um aviso e não permite prosseguir. Renovação só se aplica a contratos encerrados — para um contrato Ativo, basta alterar a vigência diretamente no próprio cadastro (`ZCT010`), se for o caso.

### Tela de parâmetros

| Campo | Descrição |
|---|---|
| Dt.Início da renovação | Data de início da nova vigência (sugerida automaticamente como o dia seguinte ao fim do contrato original) |
| Dt.Fim da renovação | Data de fim da nova vigência |
| Valor da mensalidade | Valor da mensalidade do novo contrato (sugerido com o último valor do contrato original, mas pode ser alterado) |
| Confirma a renovação (novo contrato)? | `Sim` cria o novo contrato; `Não` cancela |

### O que a rotina faz

Cria um **contrato novo** (novo número, gerado automaticamente), copiando do contrato encerrado: fornecedor/loja, produto, unidade de medida, centro de custo, TES, tipo de operação, natureza financeira, condição de pagamento e índice/periodicidade de reajuste. Só a **vigência** e o **valor da mensalidade** são pedidos de novo, pois normalmente mudam a cada renovação.

O contrato original **não é alterado** — permanece Encerrado, preservando seu histórico de pedidos gerados. Ao final, o sistema exibe o número do novo contrato criado.

> **Por que um contrato novo, e não reabrir/estender o mesmo?** A quantidade de mensalidades e a geração de previsões financeiras são calculadas sobre a vigência inteira do contrato de uma só vez. Um mesmo contrato sucessivamente estendido acumularia um número cada vez maior de mensalidades pendentes, podendo ultrapassar o limite de 99 mensalidades simultâneas ainda não faturadas — o que geraria erro na geração de previsões (ver seção 7). Abrir um contrato novo a cada renovação evita esse problema.

---

## 7. Previsão Financeira (ZCT040)

Rotina para dar visibilidade, no Contas a Pagar, do comprometimento financeiro futuro dos contratos — gera um título de **Previsão** para cada mensalidade futura ainda não faturada, antes mesmo de existir o pedido de compra real daquele mês.

Acesso: browse de `ZCT010` → **Outras Ações → Previsão Financeira**.

### Tela de parâmetros

| Campo | Descrição |
|---|---|
| Contrato de: / Contrato até: | Faixa de contratos a processar (em branco = todos) |

### O que a rotina faz

Dentro da faixa informada, para cada contrato ativo:

1. **Gera** no Contas a Pagar um título de Previsão para cada mensalidade futura ainda não faturada, até o fim da vigência do contrato.
2. **Baixa (exclui)** automaticamente as previsões que deixaram de fazer sentido:
   - a mensalidade já foi faturada (pedido de compra gerado) **e** totalmente recebida;
   - o contrato deixou de estar ativo (foi suspenso, encerrado ou cancelado).

Ao final, é exibido um resumo com a quantidade de títulos baixados, cancelados e gerados.

> A baixa de previsões atendidas também roda **automaticamente e silenciosamente** a cada execução da Geração Mensal (seção 4), para todos os contratos — por isso as previsões tendem a ficar em dia mesmo sem rodar `ZCT040` com frequência. Já a **geração** de novas previsões só acontece quando esta rotina é executada manualmente.

> **Limitação conhecida**: a previsão usa o valor **vigente** do contrato para todas as parcelas futuras — reajustes que ainda vão ocorrer durante a vigência não são projetados com antecedência (a previsão se corrige sozinha assim que o reajuste for efetivamente aplicado pela Geração Mensal).

> Pré-requisito: o contrato precisa ter o campo **Natureza** financeira preenchido (`ZCT010`) para que a previsão possa ser gerada.

---

## 8. Ciclo de vida de um contrato

```
Cadastro (ZCT010)
      │
      ▼
   Ativo ──────────► Suspenso (manual, se necessário)
      │                    │
      │  (Geração Mensal,  │ (reativar manualmente)
      │   todo mês)        ▼
      │                  Ativo
      │
      ├─── Cancelado (manual, a qualquer momento)
      │
      ▼
  Encerrado (automático: fim da vigência ou última
             mensalidade emitida)
      │
      ▼
  Renovar Contrato ──► novo contrato Ativo (ZCTRenova)
```

Fluxo típico de operação mês a mês:

1. Cadastrar/manter os contratos (`ZCT010`) e os índices de reajuste (`ZCT030`).
2. Rodar (ou deixar o job agendado rodar) a **Geração Mensal** (`ZCT020`).
3. Se algo sair errado na geração daquele mês, usar **Desfazer Geração Mensal** (`ZCT025`), corrigir o cadastro e gerar novamente.
4. Quando um contrato encerrar e precisar continuar, usar **Renovar Contrato**.
5. Quando desejado, rodar a **Previsão Financeira** (`ZCT040`) para visibilidade do comprometimento futuro no Contas a Pagar.

---

## 9. Perguntas frequentes / cuidados operacionais

**Um contrato encerrou sozinho, mas eu não queria que encerrasse ainda.**
Confira a vigência (Dt.Fim) e a Qtd.Parcelas/Qtd.Emitidas no cadastro (`ZCT010`). O encerramento automático acontece quando a vigência termina ou quando todas as mensalidades previstas já foram emitidas. Se a vigência estiver errada, corrija-a e altere o Status de volta para Ativo manualmente.

**Gerei os pedidos do mês, mas percebi um erro no cadastro do contrato depois.**
Use **Desfazer Geração Mensal** (seção 5) para aquela competência/contrato, corrija o cadastro do contrato (`ZCT010`) e rode a Geração Mensal novamente. Isso só funciona enquanto o pedido gerado não tiver recebimento.

**Um contrato terminou e o fornecedor vai continuar prestando o serviço.**
Use **Renovar Contrato** (seção 6) posicionado no contrato encerrado — não reabra o contrato antigo manualmente alterando o Status e a vigência, pois isso pode gerar problema na geração de previsões financeiras de contratos com muitas mensalidades acumuladas.

**A Previsão Financeira não gerou nada para um contrato.**
Confira se o contrato está Ativo, se o campo Natureza está preenchido e se já não existe previsão/fatura gerada para todas as parcelas restantes.

**Quero suspender ou cancelar um contrato.**
Altere o contrato (`ZCT010`) e mude o campo Status manualmente para Suspenso ou Cancelado. Um contrato Suspenso ou Cancelado deixa de ser processado pela Geração Mensal; a próxima execução da Previsão Financeira também baixa (cancela) as previsões pendentes desse contrato automaticamente.
