#include "protheus.ch"
#include "parmtype.ch"

/*/{Protheus.doc} ZCT025
Desfaz (cancela) os pedidos de compra gerados pela rotina de Geracao
Mensal (ZCT020) para uma competencia informada, permitindo ao analista
corrigir o cadastro do contrato ou algum dado do pedido e rodar a
geracao novamente sem duplicar mensalidade nem "sujar" os contadores do
contrato.

So desfaz pedidos ainda SEM recebimento (SC7, C7_QUJE = 0 em todos os
itens do pedido) - pedidos ja recebidos/faturados nao podem ser
simplesmente excluidos sem violar o fluxo fiscal/financeiro; nesses
casos a exclusao deve ser avaliada e feita manualmente pela tela padrao
de Compras.

LIMITACAO CONHECIDA: se a geracao desfeita tiver aplicado reajuste
(ZC1_VALOR/ZC1_DTULTR foram atualizados naquele mes pelo ZCT020), o
valor reajustado NAO e revertido automaticamente aqui - o historico
(ZC2) nao guarda o valor vigente antes do reajuste. Corrija
ZC1_VALOR/ZC1_DTULTR manualmente nesse caso, se necessario.

IMPORTANTE: assim como em ZCTGeraPC, a exclusao via MSExecAuto/MATA120
(aqui com nOpcao=5) e uma area historicamente sensivel do MATA120 via
ExecAuto - teste exaustivamente em homologacao antes de usar em
producao (ver README).
@author  Ivo Caetano
@since   04/09/2026
/*/
User Function ZCT025()
    Local aParams   := {}
    Local aRetorno  := {}
    Local cCompet   := ""
    Local cContrato := ""
    Local lConfirma := .F.
    Local aRes

    aAdd(aParams,{1,"Mes"     ,Month(Date()),"99","","","",40,.F.})
    aAdd(aParams,{1,"Ano"     ,Year(Date()) ,"","","","",40,.F.})
    aAdd(aParams,{1,"Contrato (vazio = todos)","","","","","",9,.F.})
    aAdd(aParams,{2,"Confirma o desfazimento dos pedidos?",2,{"Sim","Nao"},50,".F.",.T.})

    If !ParamBox(aParams,"Desfazer Geracao Mensal de Pedidos - Contratos de Fornecedores",aRetorno)
        Return
    EndIf

    // a resposta de uma pergunta tipo 2 (combo) do ParamBox pode voltar
    // como a string do texto selecionado OU, dependendo da versao/build,
    // como o indice numerico da opcao (aqui, aOpcoes={"Sim","Nao"} -> 1)
    // - comparar direto contra "Sim" quando o retorno vem numerico gera
    // "type mismatch on compare"; por isso trata os dois formatos.
    If ValType(aRetorno[4]) == "C"
        lConfirma := (aRetorno[4] == "Sim")
    Else
        lConfirma := (aRetorno[4] == 1)
    EndIf

    If !lConfirma
        Return
    EndIf

    cCompet   := StrZero(aRetorno[2],4)+StrZero(aRetorno[1],2)
    cContrato := AllTrim(aRetorno[3])

    aRes := DesfazCompet(cCompet,cContrato)

    MostraResDesfaz(aRes,cCompet)
Return

/*/{Protheus.doc} DesfazCompet
Percorre o historico (ZC2) da competencia informada com status "P"
(pedido gerado, ainda nao cancelado) e tenta desfazer cada um.
@param cCompet   Competencia AAAAMM a desfazer
@param cContrato Se informado, restringe a este contrato; vazio = todos
@return array {nDesfeito, nBloqueado, aErros[]}
/*/
Static Function DesfazCompet(cCompet,cContrato)
    Local cAliasQry := GetNextAlias()
    Local nDesfeito := 0
    Local nBloq      := 0
    Local aErros     := {}
    Local aRet

    BeginSql Alias cAliasQry
        SELECT ZC2.ZC2_CONTRA AS CONTRA, ZC2.ZC2_SEQ AS SEQ, ZC2.ZC2_NUMPC AS NUMPC
          FROM %table:ZC2% ZC2
         WHERE ZC2.ZC2_FILIAL = %xFilial:ZC2%
           AND ZC2.ZC2_COMPET = %exp:cCompet%
           AND ZC2.ZC2_STATUS = 'P'
           AND (%exp:cContrato% = '' OR ZC2.ZC2_CONTRA = %exp:cContrato%)
           AND ZC2.%NotDel%
         ORDER BY ZC2.ZC2_CONTRA, ZC2.ZC2_SEQ
    EndSql

    While !(cAliasQry)->(Eof())
        aRet := DesfazUmPedido((cAliasQry)->CONTRA,(cAliasQry)->SEQ,(cAliasQry)->NUMPC)
        If aRet[1]
            nDesfeito++
        Else
            nBloq++
            aAdd(aErros,aRet[2])
        EndIf
        (cAliasQry)->(DbSkip())
    End
    (cAliasQry)->(DbCloseArea())
Return {nDesfeito,nBloq,aErros}

/*/{Protheus.doc} DesfazUmPedido
Desfaz um unico pedido gerado: exclui o SC7 (via MSExecAuto/MATA120,
opcao 5 = exclusao) somente se nenhum item ainda tiver recebimento,
marca o historico (ZC2) correspondente como cancelado e reverte os
contadores/status do contrato (ZC1).
@param cContrato Numero do contrato (ZC2_CONTRA)
@param cSeq      Sequencia da parcela no historico (ZC2_SEQ)
@param cNumPC    Numero do pedido de compra gerado (ZC2_NUMPC / C7_NUM)
@return array {lOk, cMsgErro}
/*/
Static Function DesfazUmPedido(cContrato,cSeq,cNumPC)
    Local aAreaSC7   := SC7->(GetArea())
    Local aAreaZC1   := ZC1->(GetArea())
    Local aAreaZC2   := ZC2->(GetArea())
    Local lTemReceb  := .F.
    Local aCabec     := {}
    Local cForNum    := xFilial("SC7")+cNumPC
    Local cFornece, cLoja
    Local cMsgErro   := ""
    Local aLog       := {}
    Local nI
    Private lMsErroAuto    := .F.
    Private lAutoErrNoFile := .T.

    SC7->(DbSetOrder(1)) //C7_FILIAL+C7_NUM+C7_ITEM+C7_SEQUEN+C7_ITEMGRD
    If !SC7->(DbSeek(cForNum))
        SC7->(RestArea(aAreaSC7))
        Return {.F.,"Contrato "+cContrato+" parc. "+cSeq+": pedido "+cNumPC+" nao localizado (ja excluido?)."}
    EndIf

    cFornece := SC7->C7_FORNECE
    cLoja    := SC7->C7_LOJA

    // confere TODOS os itens do pedido antes de decidir se pode excluir -
    // basta um item com recebimento para abortar a exclusao automatica
    While SC7->(!Eof()) .And. SC7->C7_FILIAL+SC7->C7_NUM == cForNum
        If SC7->C7_QUJE > 0
            lTemReceb := .T.
        EndIf
        SC7->(DbSkip())
    End
    SC7->(RestArea(aAreaSC7))

    If lTemReceb
        Return {.F.,"Contrato "+cContrato+" parc. "+cSeq+": pedido "+cNumPC+" ja possui recebimento - "+;
                    "exclua manualmente pela tela de Compras, se realmente necessario."}
    EndIf

    aAdd(aCabec,{"C7_FILIAL" ,xFilial("SC7") ,Nil})
    aAdd(aCabec,{"C7_NUM"    ,cNumPC          ,Nil})
    aAdd(aCabec,{"C7_FORNECE",cFornece        ,Nil})
    aAdd(aCabec,{"C7_LOJA"   ,cLoja           ,Nil})

    MSExecAuto({|nFunc,x,y,z,w| Mata120(nFunc,x,y,z,w)}, 1, aCabec, {}, 5, .T.)

    If lMsErroAuto
        aLog := GetAutoGRLog()
        For nI := 1 To Len(aLog)
            cMsgErro += If(Empty(cMsgErro),"",CRLF) + aLog[nI]
        Next nI
        Return {.F.,"Contrato "+cContrato+" parc. "+cSeq+": erro ao excluir pedido "+cNumPC+": "+cMsgErro}
    EndIf

    ZC2->(DbSetOrder(1)) //ZC2_FILIAL+ZC2_CONTRA+ZC2_SEQ
    If ZC2->(DbSeek(xFilial("ZC2")+cContrato+cSeq))
        RecLock("ZC2",.F.)
            ZC2->ZC2_STATUS := "C"
        MsUnlock()
    EndIf
    ZC2->(RestArea(aAreaZC2))

    ZC1->(DbSetOrder(1)) //ZC1_FILIAL+ZC1_CONTRA
    If ZC1->(DbSeek(xFilial("ZC1")+cContrato))
        RecLock("ZC1",.F.)
            ZC1->ZC1_QTDEMI := Max(ZC1->ZC1_QTDEMI - 1, 0)
            ZC1->ZC1_QTDFAL := Max(ZC1->ZC1_QTDPAR - ZC1->ZC1_QTDEMI, 0)
            // o encerramento automatico (ZCT020) so acontece como efeito
            // desta mesma geracao - desfazer a geracao reabre o contrato
            If ZC1->ZC1_STATUS == "3"
                ZC1->ZC1_STATUS := "1"
            EndIf
        MsUnlock()
    EndIf
    ZC1->(RestArea(aAreaZC1))

    AtualizaUltGeracao(cContrato)
Return {.T.,""}

/*/{Protheus.doc} AtualizaUltGeracao
Recalcula ZC1_COMPET/ZC1_DTULGE do contrato a partir da geracao "P"
(nao cancelada) mais recente ainda existente no historico (ZC2), apos
uma geracao ser desfeita - evita que esses campos informativos fiquem
apontando para uma competencia que acabou de ser cancelada.
@param cContrato Numero do contrato (ZC1_CONTRA)
/*/
Static Function AtualizaUltGeracao(cContrato)
    Local aAreaZC1 := ZC1->(GetArea())
    Local aAreaZC2 := ZC2->(GetArea())
    Local cCompet  := ""
    Local dDtGer   := CTOD("")

    ZC2->(DbSetOrder(1)) //ZC2_FILIAL+ZC2_CONTRA+ZC2_SEQ
    ZC2->(DbSeek(xFilial("ZC2")+cContrato))
    While ZC2->(!Eof()) .And. ZC2->ZC2_FILIAL+ZC2->ZC2_CONTRA == xFilial("ZC2")+cContrato
        If ZC2->ZC2_STATUS == "P" .And. (Empty(cCompet) .Or. ZC2->ZC2_COMPET > cCompet)
            cCompet := ZC2->ZC2_COMPET
            dDtGer  := ZC2->ZC2_DTGER
        EndIf
        ZC2->(DbSkip())
    End
    ZC2->(RestArea(aAreaZC2))

    ZC1->(DbSetOrder(1))
    If ZC1->(DbSeek(xFilial("ZC1")+cContrato))
        RecLock("ZC1",.F.)
            ZC1->ZC1_COMPET := cCompet
            ZC1->ZC1_DTULGE := dDtGer
        MsUnlock()
    EndIf
    ZC1->(RestArea(aAreaZC1))
Return

/*/{Protheus.doc} MostraResDesfaz
Exibe ao usuario o resumo do desfazimento.
/*/
Static Function MostraResDesfaz(aRes,cCompet)
    Local cMsg := "Competencia: "+cCompet+CRLF+;
                  "Pedidos desfeitos: "+AllTrim(Str(aRes[1]))+CRLF+;
                  "Pedidos nao desfeitos (bloqueados/erro): "+AllTrim(Str(aRes[2]))
    Local i

    If Len(aRes[3]) > 0
        cMsg += CRLF+CRLF+"Ocorrencias:"
        For i := 1 To Len(aRes[3])
            cMsg += CRLF+"  - "+aRes[3][i]
        Next i
    EndIf

    MsgInfo(cMsg,"ZCT025 - Desfazer Geracao Mensal")
Return
