#include "protheus.ch"
#include "parmtype.ch"

/*/{Protheus.doc} ZCT040
Previsao Financeira de Contratos. Rotina disparada pelo analista
financeiro para:

  1) baixar (excluir) titulos de Previsao (SE2, E2_TIPO="PR") cuja
     parcela ja foi atendida (pedido de compra totalmente recebido) ou
     cujo contrato deixou de estar ativo;
  2) gerar titulos de Previsao para as parcelas futuras (ate o fim da
     vigencia) dos contratos ativos que ainda nao possuem previsao
     gerada nem foram faturadas.

Assim o analista consegue visualizar no Contas a Pagar o comprometimento
financeiro futuro dos contratos antes de existir a fatura/pedido real,
sem que essas previsoes fiquem "sobrando" quando a parcela realmente
for atendida.
@author  Ivo Caetano
@since   01/09/2026
/*/
User Function ZCT040()
    Local aParams   := {}
    Local aRetorno  := {}
    Local cContrato := ""
    Local aRes

    aAdd(aParams,{1,"Contrato (vazio = todos os ativos)","","","","","",9,.F.})

    If !ParamBox(aParams,"Previsao Financeira de Contratos",aRetorno)
        Return
    EndIf

    cContrato := AllTrim(aRetorno[1])

    aRes := U_ZCTBaixaPrevisoes(cContrato)
    GeraPrevisoes(cContrato,aRes)

    MostraResultPrev(aRes)
Return

/*/{Protheus.doc} ZCTBaixaPrevisoes
Percorre as previsoes ativas (ZC4_STATUS="A") e:
  - exclui (baixa) as que ja foram atendidas: existe registro em ZC2 na
    mesma parcela (ZC2_SEQ=ZC4_PARC) cujo pedido de compra (SC7) ja foi
    totalmente recebido (C7_QUJE >= C7_QUANT);
  - cancela (exclui) as de contratos que deixaram de estar ativos
    (ZC1_STATUS <> "1").
Chamada tanto pela geracao mensal (ZCT020, silenciosamente, a cada
execucao) quanto pela rotina interativa (ZCT040).
@param cContrato Se informado, restringe a este contrato; vazio = todos
@return array {nBaixado, nCancelado, aErros[]}
/*/
User Function ZCTBaixaPrevisoes(cContrato)
    Local cAliasQry := GetNextAlias()
    Local nBaixado  := 0
    Local nCancel   := 0
    Local aErros    := {}
    Local aExc

    BeginSql Alias cAliasQry
        SELECT ZC4.ZC4_CONTRA AS CONTRA, ZC4.ZC4_PARC AS PARC, ZC4.ZC4_PREFIX AS PREFIX,
               ZC4.ZC4_NUMTIT AS NUMTIT, ZC4.ZC4_PARCTI AS PARCTI,
               ZC1.ZC1_FORNEC AS FORNEC, ZC1.ZC1_LOJA AS LOJA, ZC1.ZC1_STATUS AS CSTATUS,
               SC7.C7_NUM AS NUMPC, SC7.C7_QUANT AS QUANT, SC7.C7_QUJE AS QUJE
          FROM %table:ZC4% ZC4
          JOIN %table:ZC1% ZC1 ON ZC1.ZC1_FILIAL = ZC4.ZC4_FILIAL AND ZC1.ZC1_CONTRA = ZC4.ZC4_CONTRA AND ZC1.%NotDel%
          LEFT JOIN %table:ZC2% ZC2 ON ZC2.ZC2_FILIAL = ZC4.ZC4_FILIAL AND ZC2.ZC2_CONTRA = ZC4.ZC4_CONTRA AND ZC2.ZC2_SEQ = ZC4.ZC4_PARC AND ZC2.%NotDel%
          LEFT JOIN %table:SC7% SC7 ON SC7.C7_FILIAL = ZC4.ZC4_FILIAL AND SC7.C7_NUM = ZC2.ZC2_NUMPC AND SC7.%NotDel%
         WHERE ZC4.ZC4_FILIAL = %xFilial:ZC4%
           AND ZC4.ZC4_STATUS = 'A'
           AND (%exp:cContrato% = '' OR ZC4.ZC4_CONTRA = %exp:cContrato%)
           AND ZC4.%NotDel%
    EndSql

    While !(cAliasQry)->(Eof())
        If (cAliasQry)->CSTATUS <> "1"
            aExc := U_ZCTExcluiPR((cAliasQry)->PREFIX,(cAliasQry)->NUMTIT,(cAliasQry)->PARCTI,;
                                   (cAliasQry)->FORNEC,(cAliasQry)->LOJA)
            If aExc[1]
                AtualizaZC4((cAliasQry)->CONTRA,(cAliasQry)->PARC,"C")
                nCancel++
            Else
                aAdd(aErros,aExc[2])
            EndIf
        ElseIf !Empty((cAliasQry)->NUMPC) .And. (cAliasQry)->QUJE >= (cAliasQry)->QUANT
            aExc := U_ZCTExcluiPR((cAliasQry)->PREFIX,(cAliasQry)->NUMTIT,(cAliasQry)->PARCTI,;
                                   (cAliasQry)->FORNEC,(cAliasQry)->LOJA)
            If aExc[1]
                AtualizaZC4((cAliasQry)->CONTRA,(cAliasQry)->PARC,"B")
                nBaixado++
            Else
                aAdd(aErros,aExc[2])
            EndIf
        EndIf
        (cAliasQry)->(DbSkip())
    End
    (cAliasQry)->(DbCloseArea())
Return {nBaixado,nCancel,aErros}

/*/{Protheus.doc} GeraPrevisoes
Gera previsoes (SE2 tipo "PR") para as parcelas futuras (da proxima
ainda nao faturada ate ZC1_QTDPAR) de contratos ativos que ainda nao
possuem previsao ativa/baixada nem foram faturadas.

Usa o valor vigente do contrato (ZC1_VALOR) para todas as parcelas
futuras — reajustes que ainda vao ocorrer durante a vigencia nao sao
projetados (limitacao conhecida, ver README: a previsao e recalculada
a cada execucao, entao passa a refletir o valor reajustado assim que
ele for aplicado pela geracao mensal).
@param aRes Array {nBaixado,nCancelado,aErros[]} retornado por
             ZCTBaixaPrevisoes(); recebe um 4o elemento (nGerado) e tem
             erros de geracao empilhados em aRes[3].
/*/
Static Function GeraPrevisoes(cContrato,aRes)
    Local cAliasQry := GetNextAlias()
    Local nGerado   := 0
    Local nParc, cParc, dVenc, aInc

    // ZC1_DTINI mantido com o nome original (sem "AS"): o BeginSql so
    // reconhece o tipo Data de uma coluna quando o nome bate com um campo
    // do dicionario (SX3) - um alias renomeado (ex: "AS DTINI") faz o
    // TOPConnect devolver a coluna como Character, quebrando U_ZCTSomaMes.
    BeginSql Alias cAliasQry
        SELECT ZC1_CONTRA AS CONTRA, ZC1_DTINI, ZC1_VALOR AS VALOR,
               ZC1_QTDPAR AS QTDPAR, ZC1_QTDEMI AS QTDEMI
          FROM %table:ZC1% ZC1
         WHERE ZC1_FILIAL = %xFilial:ZC1%
           AND ZC1_STATUS = '1'
           AND (%exp:cContrato% = '' OR ZC1_CONTRA = %exp:cContrato%)
           AND ZC1.%NotDel%
    EndSql

    While !(cAliasQry)->(Eof())
        For nParc := (cAliasQry)->QTDEMI + 1 To (cAliasQry)->QTDPAR
            cParc := StrZero(nParc,4)
            If !TemPrevisaoOuFatura((cAliasQry)->CONTRA,cParc)
                dVenc := U_ZCTSomaMes((cAliasQry)->ZC1_DTINI, nParc-1)
                aInc  := U_ZCTIncluiPR((cAliasQry)->CONTRA,cParc,dVenc,(cAliasQry)->VALOR)
                If aInc[1]
                    GravaZC4((cAliasQry)->CONTRA,cParc,U_ZCTCompet(dVenc),dVenc,(cAliasQry)->VALOR,aInc[2],aInc[3],aInc[4])
                    nGerado++
                Else
                    aAdd(aRes[3],aInc[5])
                EndIf
            EndIf
        Next nParc
        (cAliasQry)->(DbSkip())
    End
    (cAliasQry)->(DbCloseArea())

    aAdd(aRes,nGerado)
Return

/*/{Protheus.doc} TemPrevisaoOuFatura
Verifica se a parcela do contrato ja possui previsao ativa/baixada
(ZC4) ou ja foi efetivamente faturada (ZC2), para nao gerar previsao
duplicada.
/*/
Static Function TemPrevisaoOuFatura(cContrato,cParc)
    Local lAchou := .F.
    Local aArea

    aArea := ZC4->(GetArea())
    ZC4->(DbSetOrder(1))
    If ZC4->(DbSeek(xFilial("ZC4")+cContrato+cParc)) .And. ZC4->ZC4_STATUS $ "AB"
        lAchou := .T.
    EndIf
    ZC4->(RestArea(aArea))

    If !lAchou
        aArea := ZC2->(GetArea())
        ZC2->(DbSetOrder(1))
        If ZC2->(DbSeek(xFilial("ZC2")+cContrato+cParc))
            lAchou := .T.
        EndIf
        ZC2->(RestArea(aArea))
    EndIf
Return lAchou

/*/{Protheus.doc} GravaZC4
Grava o registro de controle da previsao gerada.
/*/
Static Function GravaZC4(cContrato,cParc,cCompet,dVenc,nValor,cPrefixo,cNumTit,cParcTit)
    RecLock("ZC4",.T.)
        ZC4->ZC4_FILIAL := xFilial("ZC4")
        ZC4->ZC4_CONTRA := cContrato
        ZC4->ZC4_PARC   := cParc
        ZC4->ZC4_COMPET := cCompet
        ZC4->ZC4_VENCTO := dVenc
        ZC4->ZC4_VALOR  := nValor
        ZC4->ZC4_PREFIX := cPrefixo
        ZC4->ZC4_NUMTIT := cNumTit
        ZC4->ZC4_PARCTI := cParcTit
        ZC4->ZC4_STATUS := "A"
        ZC4->ZC4_DTGER  := Date()
    MsUnlock()
Return

/*/{Protheus.doc} AtualizaZC4
Atualiza o status de uma previsao apos baixa/cancelamento do titulo.
/*/
Static Function AtualizaZC4(cContrato,cParc,cStatus)
    Local aArea := ZC4->(GetArea())

    ZC4->(DbSetOrder(1))
    If ZC4->(DbSeek(xFilial("ZC4")+cContrato+cParc))
        RecLock("ZC4",.F.)
            ZC4->ZC4_STATUS  := cStatus
            ZC4->ZC4_DTBAIXA := Date()
        MsUnlock()
    EndIf
    ZC4->(RestArea(aArea))
Return

/*/{Protheus.doc} MostraResultPrev
Exibe ao usuario o resumo do processamento de previsoes.
/*/
Static Function MostraResultPrev(aRes)
    Local cMsg := "Titulos de previsao baixados (parcela atendida): "+AllTrim(Str(aRes[1]))+CRLF+;
                  "Titulos de previsao cancelados (contrato inativo): "+AllTrim(Str(aRes[2]))+CRLF+;
                  "Titulos de previsao gerados: "+AllTrim(Str(aRes[4]))
    Local i

    If Len(aRes[3]) > 0
        cMsg += CRLF+CRLF+"Ocorrencias:"
        For i := 1 To Len(aRes[3])
            cMsg += CRLF+"  - "+aRes[3][i]
        Next i
    EndIf

    MsgInfo(cMsg,"ZCT040 - Previsao Financeira de Contratos")
Return
