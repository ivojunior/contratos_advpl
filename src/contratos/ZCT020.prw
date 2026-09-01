#include "protheus.ch"
#include "parmtype.ch"

/*/{Protheus.doc} ZCT020
Geracao mensal de Pedidos de Compra referentes a mensalidade vigente dos
contratos de fornecedores cadastrados (ZC1). Uso interativo: solicita a
competencia a processar, lista os contratos que serao afetados, aplica
reajuste (se devido) e gera o pedido de compra (SC7) de cada contrato
ativo, atualizando os contadores de mensalidades emitidas/faltantes.
@author  Ivo Caetano
@since   31/08/2026
/*/
User Function ZCT020()
    Local aParams   := {}
    Local aRetorno  := {}
    Local dDataProc := Date()

    aAdd(aParams,{1,"Mes"     ,Month(Date()),"","","",40,.F.})
    aAdd(aParams,{1,"Ano"     ,Year(Date()) ,"","","",40,.F.})
    aAdd(aParams,{2,"Confirma a geracao dos pedidos?","Nao",{"Sim","Nao"},50,".F.",40,.T.})

    If !ParamBox(aParams,"Geracao Mensal de Pedidos - Contratos de Fornecedores",aRetorno)
        Return
    EndIf

    dDataProc := STOD(StrZero(aRetorno[2],4)+StrZero(aRetorno[1],2)+"01")

    ProcessaContratos(dDataProc, aRetorno[3] == "Sim", .T.)
Return

/*/{Protheus.doc} ZCT020JOB
Ponto de entrada para execucao desassistida (Schedule/Agendador de
Tarefas do Configurador), processando a competencia corrente sem
necessidade de confirmacao manual. Cadastrar esta funcao para rodar uma
vez por mes (ex: todo dia 1, as 06:00).
/*/
User Function ZCT020JOB()
    ProcessaContratos(Date(), .T., .F.)
Return

/*/{Protheus.doc} ProcessaContratos
Rotina central de geracao. Percorre os contratos ativos vigentes na
competencia informada, aplica reajuste quando devido, gera o pedido de
compra e atualiza os contadores de mensalidades do contrato.
@param dDataProc  Data base do processamento (define a competencia)
@param lGerar     .T. efetivamente gera os pedidos; .F. apenas simula/lista
@param lInterativo .T. exibe tela de resultado ao usuario
/*/
Static Function ProcessaContratos(dDataProc,lGerar,lInterativo)
    Local cCompet    := U_ZCTCompet(dDataProc)
    Local dPrimeiro  := STOD(SubStr(DtoS(dDataProc),1,6)+"01")
    Local dUltimo    := U_ZCTUltimoDiaMes(dDataProc)
    Local cAliasQry  := GetNextAlias()
    Local nOk        := 0
    Local nErro      := 0
    Local aResult    := {}
    Local aZC3       := U_ZCTCarregaZC3()

    // baixa/cancela previsoes (SE2 tipo "PR") ja atendidas ou de
    // contratos inativos antes de gerar as novas parcelas do mes
    U_ZCTBaixaPrevisoes("")

    BeginSql Alias cAliasQry
        SELECT ZC1_CONTRA
          FROM %table:ZC1% ZC1
         WHERE ZC1_FILIAL  = %xFilial:ZC1%
           AND ZC1_STATUS  = '1'
           AND ZC1_DTINI  <= %exp:dUltimo%
           AND ZC1_DTFIM  >= %exp:dPrimeiro%
           AND ZC1_COMPET <> %exp:cCompet%
           AND ZC1.%NotDel%
         ORDER BY ZC1_CONTRA
    EndSql

    While !(cAliasQry)->(Eof())
        aAdd(aResult, ProcessaUmContrato((cAliasQry)->ZC1_CONTRA, dDataProc, cCompet, lGerar, aZC3))
        If ATail(aResult)[2]
            nOk++
        Else
            nErro++
        EndIf
        (cAliasQry)->(DbSkip())
    End
    (cAliasQry)->(DbCloseArea())

    If lInterativo
        MostraResultado(aResult,nOk,nErro,lGerar)
    EndIf
Return

/*/{Protheus.doc} ProcessaUmContrato
Processa um unico contrato: aplica reajuste (se aplicavel), gera o
pedido de compra e atualiza os contadores/status do contrato.
@param aZC3 Array de indices pre-carregado por U_ZCTCarregaZC3() (ver
            ProcessaContratos) — evita consultar ZC3 a cada contrato.
@return array {cContrato, lOk, cMsg}
/*/
Static Function ProcessaUmContrato(cContrato,dDataProc,cCompet,lGerar,aZC3)
    Local aArea      := ZC1->(GetArea())
    Local lOk        := .T.
    Local cMsg       := ""
    Local nValorAtu  := 0
    Local nPercReaj  := 0
    Local dBaseReaj
    Local aGeraPC
    Local nSeq

    ZC1->(DbSetOrder(1))
    If !ZC1->(DbSeek(xFilial("ZC1")+cContrato))
        ZC1->(RestArea(aArea))
        Return {cContrato,.F.,"Contrato nao localizado."}
    EndIf

    nValorAtu := ZC1->ZC1_VALOR

    // ------ verifica necessidade de reajuste ------
    If !Empty(ZC1->ZC1_INDICE) .And. ZC1->ZC1_PERREA > 0
        dBaseReaj := If(Empty(ZC1->ZC1_DTULTR), ZC1->ZC1_DTINI, ZC1->ZC1_DTULTR)
        If U_ZCTMesesEntre(dBaseReaj,dDataProc) >= ZC1->ZC1_PERREA
            nPercReaj := U_ZCTValIndice(ZC1->ZC1_INDICE,dBaseReaj,dDataProc,aZC3)
            If nPercReaj <> 0
                nValorAtu := Round(ZC1->ZC1_VALOR * (1 + nPercReaj/100), 2)
            EndIf
        EndIf
    EndIf

    If !lGerar
        ZC1->(RestArea(aArea))
        Return {cContrato,.T.,"Simulacao - valor a faturar: "+AllTrim(Transform(nValorAtu,"@E 999,999,999.99"))}
    EndIf

    // ------ gera o pedido de compra ------
    aGeraPC := U_ZCTGeraPC(cContrato,dDataProc,nValorAtu)

    If !aGeraPC[1]
        ZC1->(RestArea(aArea))
        Return {cContrato,.F.,aGeraPC[3]}
    EndIf

    // ------ atualiza contadores do contrato ------
    RecLock("ZC1",.F.)
        ZC1->ZC1_VALOR  := nValorAtu
        If nPercReaj <> 0
            ZC1->ZC1_DTULTR := dDataProc
        EndIf
        ZC1->ZC1_QTDEMI := ZC1->ZC1_QTDEMI + 1
        ZC1->ZC1_QTDFAL := Max(ZC1->ZC1_QTDPAR - ZC1->ZC1_QTDEMI, 0)
        ZC1->ZC1_COMPET := cCompet
        ZC1->ZC1_DTULGE := dDataProc
        If ZC1->ZC1_QTDFAL <= 0 .Or. dDataProc >= ZC1->ZC1_DTFIM
            ZC1->ZC1_STATUS := "3" //Encerrado
        EndIf
    MsUnlock()

    // ------ grava historico ------
    nSeq := ZC2ProxSeq(cContrato)
    RecLock("ZC2",.T.)
        ZC2->ZC2_FILIAL  := xFilial("ZC2")
        ZC2->ZC2_CONTRA  := cContrato
        ZC2->ZC2_SEQ     := StrZero(nSeq,4)
        ZC2->ZC2_COMPET  := cCompet
        ZC2->ZC2_NUMPC   := aGeraPC[2]
        ZC2->ZC2_VALOR   := nValorAtu
        ZC2->ZC2_DTGER   := dDataProc
        ZC2->ZC2_USUARI  := cUserName
        ZC2->ZC2_STATUS  := "P"
    MsUnlock()

    cMsg := "Pedido "+aGeraPC[2]+" gerado com sucesso ("+;
             AllTrim(Str(ZC1->ZC1_QTDEMI))+"/"+AllTrim(Str(ZC1->ZC1_QTDPAR))+" mensalidades emitidas, "+;
             AllTrim(Str(ZC1->ZC1_QTDFAL))+" restantes)."

    ZC1->(RestArea(aArea))
Return {cContrato,.T.,cMsg}

/*/{Protheus.doc} ZC2ProxSeq
Retorna a proxima sequencia de historico (ZC2) para o contrato.
/*/
Static Function ZC2ProxSeq(cContrato)
    Local aArea  := ZC2->(GetArea())
    Local nSeq   := 1

    ZC2->(DbSetOrder(1))
    If ZC2->(DbSeek(xFilial("ZC2")+cContrato))
        While ZC2->(!Eof()) .And. ZC2->ZC2_FILIAL+ZC2->ZC2_CONTRA == xFilial("ZC2")+cContrato
            nSeq := Val(ZC2->ZC2_SEQ) + 1
            ZC2->(DbSkip())
        End
    EndIf
    ZC2->(RestArea(aArea))
Return nSeq

/*/{Protheus.doc} MostraResultado
Exibe ao usuario o resultado do processamento (contratos processados
com sucesso e falhas).
/*/
Static Function MostraResultado(aResult,nOk,nErro,lGerar)
    Local cMsg := If(lGerar,"Geracao concluida.","Simulacao concluida.")+CRLF+CRLF+;
                  "Contratos processados com sucesso: "+AllTrim(Str(nOk))+CRLF+;
                  "Contratos com falha: "+AllTrim(Str(nErro))
    Local i

    If Empty(aResult)
        MsgAlert("Nenhum contrato pendente de geracao para a competencia informada.","ZCT020")
        Return
    EndIf

    For i := 1 To Len(aResult)
        cMsg += CRLF+"  - "+aResult[i][1]+": "+aResult[i][3]
    Next i

    MsgInfo(cMsg,"ZCT020 - Resultado do Processamento")
Return
