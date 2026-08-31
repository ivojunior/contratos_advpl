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
    Local aCabec     := {}
    Local aItens     := {}
    Local aLinha     := {}
    Local cNumPC     := ""
    Local cMsgErro   := ""
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

    aAdd(aCabec,{"C7_FILIAL"  ,xFilial("SC7")           ,Nil})
    aAdd(aCabec,{"C7_FORNECE" ,ZC1->ZC1_FORNEC           ,Nil})
    aAdd(aCabec,{"C7_LOJA"    ,ZC1->ZC1_LOJA             ,Nil})
    aAdd(aCabec,{"C7_COND"    ,ZC1->ZC1_CONDPG           ,Nil})
    aAdd(aCabec,{"C7_EMISSAO" ,dDtEmiss                  ,Nil})
    aAdd(aCabec,{"C7_COMPRA"  ,ZC1->ZC1_COMPRA           ,Nil})
    aAdd(aCabec,{"C7_OBS"     ,"Pedido gerado automaticamente - Contrato "+;
                                cContrato+" - Compet. "+U_ZCTCompet(dDtEmiss),Nil})

    aAdd(aLinha,{"C7_PRODUTO" ,ZC1->ZC1_PRODUT           ,Nil})
    aAdd(aLinha,{"C7_QUANT"   ,1                          ,Nil})
    aAdd(aLinha,{"C7_PRECO"   ,nValor                     ,Nil})
    aAdd(aLinha,{"C7_UM"      ,ZC1->ZC1_UM                ,Nil})
    aAdd(aLinha,{"C7_CC"      ,ZC1->ZC1_CC                ,Nil})
    If !Empty(ZC1->ZC1_TES)
        aAdd(aLinha,{"C7_TES" ,ZC1->ZC1_TES              ,Nil})
    EndIf
    aAdd(aLinha,{"C7_DATPRF"  ,dDtEmiss                   ,Nil})
    aAdd(aItens,aLinha)

    MSExecAuto({|x,y,z,w| Mata120(x,y,z,w)}, aCabec, aItens, 3)

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
