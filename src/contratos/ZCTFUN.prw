#include "protheus.ch"
#include "parmtype.ch"

/*/{Protheus.doc} ZCTCalcParc
Calcula a quantidade de mensalidades previstas em um contrato, contando
o mes de inicio e o mes de fim da vigencia.
@param dIni Data de inicio da vigencia
@param dFim Data de fim da vigencia
@return numeric Quantidade de parcelas (meses)
/*/
User Function ZCTCalcParc(dIni,dFim)
    Local nMeses := 0

    If !Empty(dIni) .And. !Empty(dFim) .And. dFim >= dIni
        nMeses := (Year(dFim)-Year(dIni))*12 + (Month(dFim)-Month(dIni)) + 1
    EndIf
Return nMeses

/*/{Protheus.doc} ZCTMesesEntre
Retorna a quantidade de meses corridos entre duas datas (sem +1).
/*/
User Function ZCTMesesEntre(dIni,dFim)
    Local nMeses := 0

    If !Empty(dIni) .And. !Empty(dFim)
        nMeses := (Year(dFim)-Year(dIni))*12 + (Month(dFim)-Month(dIni))
    EndIf
Return nMeses

/*/{Protheus.doc} ZCTCompet
Monta a competencia AAAAMM a partir de uma data.
/*/
User Function ZCTCompet(dData)
Return StrZero(Year(dData),4)+StrZero(Month(dData),2)

/*/{Protheus.doc} ZCTUltimoDiaMes
Retorna a data do ultimo dia do mes da data informada.
/*/
User Function ZCTUltimoDiaMes(dData)
    Local nAno := Year(dData)
    Local nMes := Month(dData) + 1

    If nMes > 12
        nMes := 1
        nAno++
    EndIf
Return STOD(StrZero(nAno,4)+StrZero(nMes,2)+"01") - 1

/*/{Protheus.doc} ZCTSomaMes
Soma (ou subtrai) uma quantidade de meses a uma data, preservando o dia
quando possivel (ajusta para o ultimo dia do mes destino quando o dia
de origem nao existir nele, ex: 31/01 + 1 mes = 28/02 ou 29/02).
/*/
User Function ZCTSomaMes(dData,nMeses)
    Local nTotMes, nAno, nMes, dPrimeiro, nDia

    // defesa contra campos Data vindos de BeginSql: nesta versao do
    // DBAccess (MSSQL/TopConnect) a conversao automatica C->D so e
    // garantida no acesso via workarea (alias->campo); em BeginSql cru o
    // campo pode retornar como Character (fisicamente armazenado como
    // CHAR(8) "AAAAMMDD" no banco) mesmo sem apelido (AS) na coluna.
    If ValType(dData) == "C"
        dData := STOD(dData)
    EndIf

    nTotMes   := Year(dData)*12 + (Month(dData)-1) + nMeses
    nAno      := Int(nTotMes/12)
    nMes      := (nTotMes % 12) + 1
    dPrimeiro := STOD(StrZero(nAno,4)+StrZero(nMes,2)+"01")
    nDia      := Min(Day(dData), Day(U_ZCTUltimoDiaMes(dPrimeiro)))
Return dPrimeiro + nDia - 1

/*/{Protheus.doc} ZCTCarregaZC3
Carrega em memoria todos os percentuais de indice cadastrados (ZC3) da
filial corrente. Deve ser chamada uma unica vez antes de processar um
lote de contratos (ex: no inicio de ZCT020), e o retorno repassado a
ZCTValIndice(), evitando abrir uma consulta a banco para cada contrato
processado dentro do laco de geracao.
@return array de {ZC3_INDICE, ZC3_COMPET, ZC3_PERC}
/*/
User Function ZCTCarregaZC3()
    Local aZC3      := {}
    Local cAliasZC3 := GetNextAlias()

    BeginSql Alias cAliasZC3
        SELECT ZC3_INDICE, ZC3_COMPET, ZC3_PERC
          FROM %table:ZC3% ZC3
         WHERE ZC3_FILIAL = %xFilial:ZC3%
           AND ZC3.%NotDel%
    EndSql

    While !(cAliasZC3)->(Eof())
        aAdd(aZC3,{(cAliasZC3)->ZC3_INDICE,(cAliasZC3)->ZC3_COMPET,(cAliasZC3)->ZC3_PERC})
        (cAliasZC3)->(DbSkip())
    End
    (cAliasZC3)->(DbCloseArea())
Return aZC3

/*/{Protheus.doc} ZCTValIndice
Calcula o percentual de reajuste acumulado de um indice entre duas
competencias (exclusive a inicial, inclusive a final), a partir do
array em memoria retornado por ZCTCarregaZC3().
@param cIndice Codigo do indice (ZC3_INDICE)
@param dDtIni  Data do ultimo reajuste (ou inicio do contrato se nunca reajustado)
@param dDtFim  Data base do calculo (normalmente a data de processamento)
@param aZC3    Array pre-carregado por ZCTCarregaZC3(); se omitido, a
               funcao carrega sozinha (uso individual/pontual, fora de laco)
@return numeric Percentual acumulado (ex: 5.23 = 5,23%)
/*/
User Function ZCTValIndice(cIndice,dDtIni,dDtFim,aZC3)
    Local cCompIni := U_ZCTCompet(dDtIni)
    Local cCompFim := U_ZCTCompet(dDtFim)
    Local nFator   := 1
    Local nI

    If Empty(cIndice)
        Return 0
    EndIf

    If aZC3 == Nil
        aZC3 := U_ZCTCarregaZC3()
    EndIf

    For nI := 1 To Len(aZC3)
        If aZC3[nI][1] == cIndice .And. aZC3[nI][2] > cCompIni .And. aZC3[nI][2] <= cCompFim
            nFator *= (1 + (aZC3[nI][3] / 100))
        EndIf
    Next nI
Return Round((nFator - 1) * 100, 4)

/*/{Protheus.doc} ZCTGeraPC
Gera um Pedido de Compra (SC7) referente a mensalidade vigente de um
contrato, atraves de MSExecAuto (MATA120).
@param cContrato Numero do contrato (ZC1_CONTRA), registro ja posicionado
                  nao e necessario, a funcao posiciona internamente.
@param dDtEmiss  Data de emissao do pedido
@param nValor    Valor a ser utilizado no pedido (ja com reajuste aplicado)
@return array {lOk, cNumPC, cMsgErro}
/*/
User Function ZCTGeraPC(cContrato,dDtEmiss,nValor)
    Local aArea      := ZC1->(GetArea())
    Local aAreaSA2
    Local aCabec     := {}
    Local aItens     := {}
    Local aLinha     := {}
    Local cNumPC     := ""
    Local cMsgErro   := ""
    Local cContato   := ""
    Local aLog       := {}
    Local nI
    // lMsErroAuto/lAutoErrNoFile precisam ser Private: o MSExecAuto/MATA120
    // sinaliza o resultado atraves dessas variaveis por escopo dinamico
    // (nao funcionam como Local) e lAutoErrNoFile e o que desvia o log de
    // erro para GetAutoGRLog() em vez de gravar em arquivo/tela.
    Private lMsErroAuto    := .F.
    Private lAutoErrNoFile := .T.

    DbSelectArea("ZC1")
    ZC1->(DbSetOrder(1))
    If !ZC1->(DbSeek(xFilial("ZC1")+cContrato))
        ZC1->(RestArea(aArea))
        Return {.F.,"","Contrato "+cContrato+" nao localizado."}
    EndIf

    aAreaSA2 := SA2->(GetArea())
    SA2->(DbSetOrder(1)) //A2_FILIAL+A2_COD+A2_LOJA
    If SA2->(DbSeek(xFilial("SA2")+ZC1->ZC1_FORNEC+ZC1->ZC1_LOJA))
        cContato := AllTrim(SA2->A2_CONTATO)
    EndIf
    SA2->(RestArea(aAreaSA2))

    aAdd(aCabec,{"C7_FILIAL"  ,xFilial("SC7")           ,Nil})
    aAdd(aCabec,{"C7_FORNECE" ,ZC1->ZC1_FORNEC           ,Nil})
    aAdd(aCabec,{"C7_LOJA"    ,ZC1->ZC1_LOJA             ,Nil})
    aAdd(aCabec,{"C7_COND"    ,ZC1->ZC1_CONDPG           ,Nil})
    aAdd(aCabec,{"C7_EMISSAO" ,dDtEmiss                  ,Nil})
    aAdd(aCabec,{"C7_FILENT"  ,xFilial("SC7")            ,Nil})
    If !Empty(cContato)
        aAdd(aCabec,{"C7_CONTATO",cContato               ,Nil})
    EndIf
    aAdd(aCabec,{"C7_YOPER"   ,ZC1->ZC1_YOPER            ,Nil})
    aAdd(aCabec,{"C7_OBS"     ,"Pedido gerado automaticamente - Contrato "+;
                                cContrato+" - Compet. "+U_ZCTCompet(dDtEmiss),Nil})

    aAdd(aLinha,{"C7_PRODUTO" ,ZC1->ZC1_PRODUT           ,Nil})
    aAdd(aLinha,{"C7_QUANT"   ,1                          ,Nil})
    aAdd(aLinha,{"C7_PRECO"   ,nValor                     ,Nil})
    aAdd(aLinha,{"C7_TOTAL"   ,nValor                     ,Nil})
    // C7_UM propositalmente NAO informado: o MATA120 obtem a unidade
    // diretamente do cadastro do produto (SB1->B1_UM).
    aAdd(aLinha,{"C7_CC"      ,ZC1->ZC1_CC                ,Nil})
    aAdd(aLinha,{"C7_ITEMCTA" ,xFilial("SC7")             ,Nil})
    If !Empty(ZC1->ZC1_TES)
        aAdd(aLinha,{"C7_TES" ,ZC1->ZC1_TES              ,Nil})
    EndIf
    aAdd(aLinha,{"C7_DATPRF"  ,dDtEmiss                   ,Nil})
    aAdd(aItens,aLinha)

    // O bRotina de MSExecAuto para o MATA120 precisa do 1o parametro
    // "nFuncao" antes do cabecalho/itens - a assinatura generica usada em
    // outros ExecAuto deste modulo (aCabec, aItens, nOpcao) NAO se aplica
    // ao MATA120, cujo 1o parametro real e nFuncao (aqui 1). Usar a
    // assinatura errada fazia o MATA120 receber o array aCabec no lugar
    // de nFuncao, causando "type mismatch on compare" (erro fatal, que
    // nem Begin Sequence/Recover Using conseguia capturar).
    MSExecAuto({|nFunc,x,y,z,w| Mata120(nFunc,x,y,z,w)}, 1, aCabec, aItens, 3, .T.)

    If lMsErroAuto
        aLog := GetAutoGRLog()
        For nI := 1 To Len(aLog)
            cMsgErro += If(Empty(cMsgErro),"",CRLF) + aLog[nI]
        Next nI
        cMsgErro := "Erro ao gerar pedido do contrato "+cContrato+": "+cMsgErro
    Else
        cNumPC := SC7->C7_NUM
    EndIf

    ZC1->(RestArea(aArea))
Return {!lMsErroAuto, cNumPC, cMsgErro}

/*/{Protheus.doc} ZCTIncluiPR
Cria um titulo de Previsao (SE2, E2_TIPO="PR") no Contas a Pagar
referente a uma parcela futura de um contrato, via MSExecAuto/FINA050,
para que o analista financeiro visualize o comprometimento futuro antes
de existir a fatura real. Usado pela rotina de Previsao Financeira
(ZCT040).
@param cContrato Numero do contrato (ZC1_CONTRA, ate 9 posicoes)
@param cParc     Sequencial da parcela dentro do contrato ("0001","0002",...)
@param dVenc     Data de vencimento previsto da parcela
@param nValor    Valor previsto da parcela (valor vigente do contrato)
@return array {lOk, cPrefixo, cNumTit, cParcTit, cMsgErro}

IMPORTANTE: E2_NUM e sempre o numero do contrato (9 posicoes, ver README)
e nao varia por parcela - por isso e2_PARCELA (aqui, cParcTit) PRECISA
variar a cada parcela do MESMO contrato, senao duas previsoes do mesmo
contrato tentam usar a chave identica da SE2
(E2_FILIAL+E2_PREFIXO+E2_NUM+E2_PARCELA+E2_TIPO+E2_FORNECE+E2_LOJA) e o
FINA050 rejeita a segunda com "numero do titulo ja existe para este
fornecedor". Usa os 2 ultimos digitos de cParc (E2_PARCELA nativo tem
so 2 posicoes) - LIMITACAO CONHECIDA: contratos com mais de 99 parcelas
AINDA NAO FATURADAS simultaneamente (implausivel na pratica, ja que
ZCT020 fatura mensalmente) colidiriam entre si.
/*/
User Function ZCTIncluiPR(cContrato,cParc,dVenc,nValor)
    Local aArea    := ZC1->(GetArea())
    Local aCabec   := {}
    Local cPrefixo := "PR"
    Local cNumTit  := Left(cContrato,9)
    Local cParcTit := Right(cParc,2)
    Local cMsgErro := ""
    Local aLog     := {}
    Local nI
    // Ver nota em ZCTGeraPC: lMsErroAuto/lAutoErrNoFile precisam ser Private.
    Private lMsErroAuto    := .F.
    Private lAutoErrNoFile := .T.

    ZC1->(DbSetOrder(1))
    If !ZC1->(DbSeek(xFilial("ZC1")+cContrato))
        ZC1->(RestArea(aArea))
        Return {.F.,"","","","Contrato "+cContrato+" nao localizado."}
    EndIf

    aAdd(aCabec,{"E2_FILIAL" ,xFilial("SE2")   ,Nil})
    aAdd(aCabec,{"E2_PREFIXO",cPrefixo         ,Nil})
    aAdd(aCabec,{"E2_NUM"    ,cNumTit          ,Nil})
    aAdd(aCabec,{"E2_PARCELA",cParcTit         ,Nil})
    aAdd(aCabec,{"E2_TIPO"   ,"PR"             ,Nil})
    aAdd(aCabec,{"E2_FORNECE",ZC1->ZC1_FORNEC  ,Nil})
    aAdd(aCabec,{"E2_LOJA"   ,ZC1->ZC1_LOJA    ,Nil})
    aAdd(aCabec,{"E2_NATUREZ",ZC1->ZC1_NATUR   ,Nil})
    aAdd(aCabec,{"E2_EMISSAO",MsDate()         ,Nil})
    aAdd(aCabec,{"E2_VENCTO" ,dVenc            ,Nil})
    aAdd(aCabec,{"E2_VENCREA",dVenc            ,Nil})
    aAdd(aCabec,{"E2_VALOR"  ,nValor           ,Nil})
    aAdd(aCabec,{"E2_MOEDA"  ,1                ,Nil})
    aAdd(aCabec,{"E2_HIST"   ,"Previsao ctr. "+cContrato+" parc. "+cParc+"/"+StrZero(ZC1->ZC1_QTDPAR,Len(cParc)),Nil})
    aAdd(aCabec,{"E2_YOPER"  ,"087"            ,Nil})

    MSExecAuto({|x,y| FINA050(x,y)}, aCabec, 3)

    If lMsErroAuto
        aLog := GetAutoGRLog()
        For nI := 1 To Len(aLog)
            cMsgErro += If(Empty(cMsgErro),"",CRLF) + aLog[nI]
        Next nI
        cMsgErro := "Erro ao gerar previsao do contrato "+cContrato+" parcela "+cParc+": "+cMsgErro
    EndIf

    ZC1->(RestArea(aArea))
Return {!lMsErroAuto, cPrefixo, cNumTit, cParcTit, cMsgErro}

/*/{Protheus.doc} ZCTExcluiPR
Exclui um titulo de Previsao (SE2, E2_TIPO="PR") via MSExecAuto/FINA050,
usado quando a parcela correspondente ja foi atendida/faturada (ou o
contrato deixou de estar ativo) e a previsao perde o sentido.

IMPORTANTE: ao contrario da inclusao, a exclusao via ExecAuto do
FINA050 opera sobre o registro CORRENTE da SE2 — por isso esta funcao
sempre posiciona explicitamente a SE2 na chave informada e confere
E2_TIPO="PR" antes de excluir, para nunca acabar excluindo "o primeiro
registro encontrado" por falta de posicionamento (armadilha conhecida
e amplamente relatada no uso do FINA050 via ExecAuto). Testar em
homologacao antes de usar em producao.
@return array {lOk, cMsgErro}
/*/
User Function ZCTExcluiPR(cPrefixo,cNumTit,cParcTit,cFornec,cLoja)
    Local aArea    := SE2->(GetArea())
    Local aCabec   := {}
    Local cMsgErro := ""
    Local aLog     := {}
    Local nI
    Private lMsErroAuto    := .F.
    Private lAutoErrNoFile := .T.

    DbSelectArea("SE2")
    SE2->(DbSetOrder(1)) //E2_FILIAL+E2_PREFIXO+E2_NUM+E2_PARCELA+E2_TIPO+E2_FORNECE+E2_LOJA
    If !SE2->(DbSeek(xFilial("SE2")+cPrefixo+cNumTit+cParcTit+"PR"+cFornec+cLoja))
        SE2->(RestArea(aArea))
        Return {.T.,""} //titulo ja nao existe: nada a fazer
    EndIf

    If SE2->E2_TIPO <> "PR"
        SE2->(RestArea(aArea))
        Return {.F.,"Titulo "+cPrefixo+" "+cNumTit+"/"+cParcTit+" nao e do tipo Previsao (PR); exclusao abortada por seguranca."}
    EndIf

    aAdd(aCabec,{"E2_FILIAL" ,SE2->E2_FILIAL ,Nil})
    aAdd(aCabec,{"E2_PREFIXO",SE2->E2_PREFIXO,Nil})
    aAdd(aCabec,{"E2_NUM"    ,SE2->E2_NUM    ,Nil})
    aAdd(aCabec,{"E2_PARCELA",SE2->E2_PARCELA,Nil})
    aAdd(aCabec,{"E2_TIPO"   ,SE2->E2_TIPO   ,Nil})
    aAdd(aCabec,{"E2_FORNECE",SE2->E2_FORNECE,Nil})
    aAdd(aCabec,{"E2_LOJA"   ,SE2->E2_LOJA   ,Nil})

    MSExecAuto({|x,y| FINA050(x,y)}, aCabec, 5)

    If lMsErroAuto
        aLog := GetAutoGRLog()
        For nI := 1 To Len(aLog)
            cMsgErro += If(Empty(cMsgErro),"",CRLF) + aLog[nI]
        Next nI
        cMsgErro := "Erro ao excluir previsao "+cPrefixo+" "+cNumTit+"/"+cParcTit+": "+cMsgErro
    EndIf

    SE2->(RestArea(aArea))
Return {!lMsErroAuto, cMsgErro}
