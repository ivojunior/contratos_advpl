#include "protheus.ch"
#include "fwmvcdef.ch"
#include "parmtype.ch"

#define ZCT010_TABLE "ZC1"

/*/{Protheus.doc} ZCT010
Cadastro de Contratos de Fornecedores.
Tela MVC (browse + inclusao/alteracao/exclusao/visualizacao) da tabela
ZC1, onde sao informados: fornecedor, vigencia, valor da mensalidade,
condicao de pagamento, indice/periodicidade de reajuste e os dados do
produto/servico e centro de custo usados na geracao mensal do pedido
de compra (rotina ZCT020).
@author  Ivo Caetano
@since   31/08/2026
/*/
User Function ZCT010()
    Local oBrowse := FWMBrowse():New()

    oBrowse:SetAlias(ZCT010_TABLE)
    oBrowse:SetDescription("Contratos de Fornecedores")
    oBrowse:SetMenuDef("ZCT010")

    oBrowse:AddLegend("ZC1_STATUS=='1'","GREEN"  ,"Ativo")
    oBrowse:AddLegend("ZC1_STATUS=='2'","YELLOW" ,"Suspenso")
    oBrowse:AddLegend("ZC1_STATUS=='3'","BLUE"   ,"Encerrado")
    oBrowse:AddLegend("ZC1_STATUS=='4'","RED"    ,"Cancelado")

    oBrowse:Activate()
Return

/*/{Protheus.doc} MenuDef
Define as opcoes de rotina do browse/cadastro.
/*/
Static Function MenuDef()
    Local aRotina := {}

    ADD OPTION aRotina TITLE "Pesquisar"  ACTION "PesqBrw"        OPERATION 1 ACCESS 0
    ADD OPTION aRotina TITLE "Visualizar" ACTION "VIEWDEF.ZCT010" OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"    ACTION "VIEWDEF.ZCT010" OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE "Alterar"    ACTION "VIEWDEF.ZCT010" OPERATION 4 ACCESS 0
    ADD OPTION aRotina TITLE "Excluir"    ACTION "VIEWDEF.ZCT010" OPERATION 5 ACCESS 0

    // acoes extras (fora do CRUD padrao) aparecem agrupadas em "Outras Acoes"
    ADD OPTION aRotina TITLE "Gerar Pedidos Mensais"      ACTION "U_ZCT020()" OPERATION 8 ACCESS 0
    ADD OPTION aRotina TITLE "Desfazer Geracao Mensal"    ACTION "U_ZCT025()" OPERATION 8 ACCESS 0
    ADD OPTION aRotina TITLE "Renovar Contrato"           ACTION "U_ZCTRenova()" OPERATION 8 ACCESS 0
    ADD OPTION aRotina TITLE "Previsao Financeira"        ACTION "U_ZCT040()" OPERATION 8 ACCESS 0
Return aRotina

/*/{Protheus.doc} ZCTNumContrato
Reserva (sem confirmar) o proximo numero sequencial de contrato
(ZC1_CONTRA) via controle SXE (GetSxeNum), com 9 posicoes (mesmo tamanho
do campo). Chamada em MODEL_FIELD_INIT, ao abrir a tela de Incluir -
precisa preencher o campo desde ja para satisfazer a obrigatoriedade do
SX3 (o FWFormView valida campos obrigatorios antes de chamar ZCTCommit).

A confirmacao (ConfirmSX8) so acontece em ZCTCommit, quando a inclusao e
efetivamente salva: enquanto a reserva nao e confirmada nem descartada,
o proprio GetSxeNum devolve o MESMO numero pendente em chamadas
seguintes - por isso desistir da inclusao (fechar sem confirmar) e abrir
"Incluir" novamente nao pula numero, o proximo Incluir mostra o mesmo
numero ainda pendente.
@return Numero de contrato gerado, com zeros a esquerda (C, 9)
/*/
User Function ZCTNumContrato()
Return GetSxeNum(ZCT010_TABLE,"ZC1_CONTRA")

/*/{Protheus.doc} ZCTNatFornec
Chamada em MODEL_FIELD_VALID de ZC1_LOJA: assim que o usuario digita o
codigo e a loja do fornecedor, preenche ZC1_NATUR com a natureza
financeira cadastrada no fornecedor (SA2->A2_NATUREZ). So sobrescreve
quando o fornecedor/loja e encontrado e A2_NATUREZ nao esta vazio -
mesmo assim, o usuario continua podendo alterar ZC1_NATUR livremente
depois (nao ha MODEL_FIELD_WHEN bloqueando o campo).
@return .T. sempre - nunca bloqueia a confirmacao do campo ZC1_LOJA
/*/
User Function ZCTNatFornec()
    Local cFornec := M->ZC1_FORNEC
    Local cLoja   := M->ZC1_LOJA
    Local aArea   := SA2->(GetArea())

    If !Empty(cFornec) .And. !Empty(cLoja)
        SA2->(DbSetOrder(1)) //A2_FILIAL+A2_COD+A2_LOJA
        If SA2->(DbSeek(xFilial("SA2")+cFornec+cLoja)) .And. !Empty(SA2->A2_NATUREZ)
            M->ZC1_NATUR := SA2->A2_NATUREZ
        EndIf
    EndIf

    SA2->(RestArea(aArea))
Return .T.

/*/{Protheus.doc} ModelDef
Define o modelo de dados (campos + regras) do cadastro de contratos.
/*/
Static Function ModelDef()
    Local oStruZC1 := FWFormStruct(1,ZCT010_TABLE)
    Local oModel

    oStruZC1:SetProperty("ZC1_STATUS",MODEL_FIELD_INIT,FwBuildFeature(STRUCT_FEATURE_INIPAD,'"1"'))
    oStruZC1:SetProperty("ZC1_QTDEMI",MODEL_FIELD_INIT,FwBuildFeature(STRUCT_FEATURE_INIPAD,'0'))
    // ZC1_CONTRA e autoincrementado via SXE (GetSxeNum) e nunca fica
    // editavel: e chave primaria da tabela e reutilizado como E2_NUM no
    // titulo de Previsao (ZCTIncluiPR), digitar/alterar manualmente
    // quebraria essa amarracao. O numero e apenas RESERVADO aqui (ver
    // U_ZCTNumContrato) - a confirmacao definitiva (ConfirmSX8) ocorre em
    // ZCTCommit, somente quando a inclusao e realmente salva.
    oStruZC1:SetProperty("ZC1_CONTRA",MODEL_FIELD_INIT,FwBuildFeature(STRUCT_FEATURE_INIPAD,'U_ZCTNumContrato()'))
    oStruZC1:SetProperty("ZC1_CONTRA",MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))

    // Ao confirmar a Loja do fornecedor (digitados fornecedor+loja), pre-
    // enche ZC1_NATUR com a natureza financeira cadastrada no fornecedor
    // (SA2->A2_NATUREZ) - o usuario continua podendo alterar ZC1_NATUR
    // manualmente depois, o campo nao fica somente leitura.
    oStruZC1:SetProperty("ZC1_LOJA",MODEL_FIELD_VALID,FwBuildFeature(STRUCT_FEATURE_VALID,'U_ZCTNatFornec()'))

    // Campos preenchidos/atualizados pelo proprio sistema (framework ou
    // rotinas ZCT020/ZCTCommit), nunca pelo usuario - somente leitura na tela.
    oStruZC1:SetProperty("ZC1_FILIAL" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    // ZC1_UM e desnecessario digitar: sempre reflete a unidade cadastrada
    // no produto (SB1->B1_UM), atribuida em ZCTCommit.
    oStruZC1:SetProperty("ZC1_UM"     ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    oStruZC1:SetProperty("ZC1_QTDPAR" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    oStruZC1:SetProperty("ZC1_QTDEMI" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    oStruZC1:SetProperty("ZC1_QTDFAL" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    oStruZC1:SetProperty("ZC1_COMPET" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    oStruZC1:SetProperty("ZC1_DTULGE" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))
    oStruZC1:SetProperty("ZC1_DTULTR" ,MODEL_FIELD_WHEN,FwBuildFeature(STRUCT_FEATURE_WHEN,'.F.'))

    oModel := MPFormModel():New("ZCT010M",,{|oModel| ZCTCommit(oModel)})
    oModel:AddFields("ZC1MASTER",,oStruZC1)
    oModel:SetPrimaryKey({"ZC1_FILIAL","ZC1_CONTRA"})
    oModel:SetDescription("Contratos de Fornecedores")
Return oModel

/*/{Protheus.doc} ViewDef
Define a visualizacao (tela) do cadastro de contratos.
/*/
Static Function ViewDef()
    Local oModel   := ModelDef()
    Local oStruZC1 := FWFormStruct(2,ZCT010_TABLE)
    Local oView

    oView := FWFormView():New()
    oView:SetModel(oModel)
    oView:AddField("VIEW_ZC1",oStruZC1,"ZC1MASTER")
    oView:CreateHorizontalBox("TELA",100)
    oView:SetOwnerView("VIEW_ZC1","TELA")
Return oView

/*/{Protheus.doc} ZCTCommit
Pos-validacao do modelo (3o parametro de MPFormModel():New — dispara ao
confirmar a tela, antes da persistencia automatica do MVC): confirma o
numero de contrato reservado na inclusao, garante consistencia das datas
de vigencia e do valor da mensalidade, e recalcula a quantidade de
parcelas/faltantes via LoadValue.

IMPORTANTE: nao usar o 4o parametro (bCommit) para validacao — quando
informado, ele substitui a gravacao automatica do MVC e o proprio
RecLock/MsUnlock passa a ser responsabilidade do bloco informado (ver
README). Retornar .F. aqui aborta a gravacao normalmente.

IMPORTANTE: este bloco tambem e disparado na operacao de Excluir (nao so
Incluir/Alterar), e o FWFormFieldsModel:LoadValue() nao pode ser chamado
nessa operacao ("erro no parametro... SetOperation configurada nao pode
ser utilizada com este metodo") - por isso a funcao retorna de imediato
quando a operacao e MODEL_OPERATION_DELETE, sem rodar validacoes/LoadValue
que so fazem sentido para Incluir/Alterar.
/*/
Static Function ZCTCommit(oModel)
    Local oStruZC1  := oModel:GetModel("ZC1MASTER")
    Local dDtIni
    Local dDtFim
    Local nValor
    Local cProduto
    Local nQtdPar   := 0
    Local nQtdEmi
    Local aAreaSB1

    If oModel:GetOperation() == MODEL_OPERATION_DELETE
        Return .T.
    EndIf

    dDtIni   := oStruZC1:GetValue("ZC1_DTINI")
    dDtFim   := oStruZC1:GetValue("ZC1_DTFIM")
    nValor   := oStruZC1:GetValue("ZC1_VALOR")
    cProduto := oStruZC1:GetValue("ZC1_PRODUT")
    nQtdEmi  := oStruZC1:GetValue("ZC1_QTDEMI")

    If Empty(dDtIni) .Or. Empty(dDtFim)
        Help(,,"ZCT010",,"Informe as datas de inicio e fim da vigencia do contrato.",1,0)
        Return .F.
    EndIf

    If dDtFim < dDtIni
        Help(,,"ZCT010",,"A data de fim da vigencia deve ser maior ou igual a data de inicio.",1,0)
        Return .F.
    EndIf

    If nValor <= 0
        Help(,,"ZCT010",,"Informe o valor da mensalidade do contrato.",1,0)
        Return .F.
    EndIf

    // ------ valida produto e obtem a unidade de medida (ZC1_UM e somente ------
    // ------ leitura: sempre reflete o cadastro do produto, SB1->B1_UM)   ------
    If Empty(cProduto)
        Help(,,"ZCT010",,"Informe o produto/servico utilizado na geracao do pedido de compra.",1,0)
        Return .F.
    EndIf

    aAreaSB1 := SB1->(GetArea())
    SB1->(DbSetOrder(1)) //B1_FILIAL+B1_COD
    If !SB1->(DbSeek(xFilial("SB1")+cProduto))
        SB1->(RestArea(aAreaSB1))
        Help(,,"ZCT010",,"Produto "+AllTrim(cProduto)+" nao cadastrado (SB1).",1,0)
        Return .F.
    EndIf

    oStruZC1:LoadValue("ZC1_UM",SB1->B1_UM)
    SB1->(RestArea(aAreaSB1))

    nQtdPar := U_ZCTCalcParc(dDtIni,dDtFim)

    oStruZC1:LoadValue("ZC1_QTDPAR",nQtdPar)
    oStruZC1:LoadValue("ZC1_QTDFAL",nQtdPar - nQtdEmi)

    If Empty(oStruZC1:GetValue("ZC1_VALORI"))
        oStruZC1:LoadValue("ZC1_VALORI",nValor)
    EndIf

    // so agora, com todas as validacoes passadas e a inclusao de fato
    // indo ser persistida, confirma definitivamente o numero reservado
    // por U_ZCTNumContrato (MODEL_FIELD_INIT) - evita pular numero em
    // caso de validacao rejeitada nas tentativas anteriores de confirmar.
    If oModel:GetOperation() == MODEL_OPERATION_INSERT
        ConfirmSX8()
    EndIf
Return .T.

/*/{Protheus.doc} ZCTRenova
Renova um contrato ENCERRADO (ZC1_STATUS="3"): o usuario posiciona o
browse de ZCT010 no registro do contrato encerrado e aciona "Renovar
Contrato" em "Outras Acoes". A rotina pede a nova vigencia (e, opcional-
mente, um novo valor de mensalidade) e cria um CONTRATO NOVO (novo
ZC1_CONTRA, via U_ZCTNumContrato), copiando fornecedor/produto/UM/CC/
TES/natureza/condicao de pagamento/indice/periodicidade do contrato
original - o contrato encerrado NAO e alterado.

Por que um contrato novo, e nao reabrir o mesmo: ZC1_QTDPAR e recalcu-
lado a partir de ZC1_DTINI ate ZC1_DTFIM inteiro, e ZCT040 gera previsao
para TODAS as parcelas futuras ainda nao faturadas numa unica execucao -
um mesmo contrato sucessivamente estendido acumula QTDPAR cada vez maior
e corre risco de ultrapassar 99 parcelas pendentes simultaneas, colidindo
em E2_PARCELA (2 posicoes, ver ZCTIncluiPR/README). Abrir um contrato
novo a cada renovacao mantem QTDPAR de cada um baixo e elimina esse risco.
/*/
User Function ZCTRenova()
    Local aArea      := ZC1->(GetArea())
    Local cContrato  := ZC1->ZC1_CONTRA
    Local aParams    := {}
    Local aRetorno   := {}
    Local dDtIniSug  := ZC1->ZC1_DTFIM + 1
    Local dDtIniNovo, dDtFimNovo, nValorNovo
    Local cNumNovo, nQtdPar
    Local lConfirma  := .F.
    Local cDescr, cFornec, cLoja, cCondPg, cIndice, nPerRea
    Local cProdut, cUM, cCC, cTES, cNatur, cYOper

    If ZC1->ZC1_STATUS <> "3"
        MsgAlert("So e possivel renovar contratos com status Encerrado. Posicione o browse no contrato encerrado desejado.","ZCT010 - Renovar Contrato")
        ZC1->(RestArea(aArea))
        Return
    EndIf

    aAdd(aParams,{1,"Dt.Inicio da renovacao",dDtIniSug   ,"","","","",40,.T.})
    aAdd(aParams,{1,"Dt.Fim da renovacao"   ,CTOD("")    ,"","","","",40,.T.})
    aAdd(aParams,{1,"Valor da mensalidade"  ,ZC1->ZC1_VALOR,"@E 9,999,999.99","","","",40,.T.})
    aAdd(aParams,{2,"Confirma a renovacao (novo contrato)?",2,{"Sim","Nao"},50,".F.",.T.})

    If !ParamBox(aParams,"Renovar Contrato "+AllTrim(cContrato),aRetorno)
        ZC1->(RestArea(aArea))
        Return
    EndIf

    If ValType(aRetorno[4]) == "C"
        lConfirma := (aRetorno[4] == "Sim")
    Else
        lConfirma := (aRetorno[4] == 1)
    EndIf

    If !lConfirma
        ZC1->(RestArea(aArea))
        Return
    EndIf

    dDtIniNovo := aRetorno[1]
    dDtFimNovo := aRetorno[2]
    nValorNovo := aRetorno[3]

    If Empty(dDtIniNovo) .Or. Empty(dDtFimNovo)
        Help(,,"ZCT010",,"Informe as datas de inicio e fim da nova vigencia.",1,0)
        ZC1->(RestArea(aArea))
        Return
    EndIf

    If dDtFimNovo < dDtIniNovo
        Help(,,"ZCT010",,"A data de fim deve ser maior ou igual a data de inicio da renovacao.",1,0)
        ZC1->(RestArea(aArea))
        Return
    EndIf

    If nValorNovo <= 0
        Help(,,"ZCT010",,"Informe o valor da mensalidade do contrato renovado.",1,0)
        ZC1->(RestArea(aArea))
        Return
    EndIf

    nQtdPar := U_ZCTCalcParc(dDtIniNovo,dDtFimNovo)

    // copia os dados do contrato original (ZC1 ainda posicionado nele)
    // ANTES do RecLock/inclusao abaixo mover o registro corrente
    cDescr   := ZC1->ZC1_DESCR
    cFornec  := ZC1->ZC1_FORNEC
    cLoja    := ZC1->ZC1_LOJA
    cCondPg  := ZC1->ZC1_CONDPG
    cIndice  := ZC1->ZC1_INDICE
    nPerRea  := ZC1->ZC1_PERREA
    cProdut  := ZC1->ZC1_PRODUT
    cUM      := ZC1->ZC1_UM
    cCC      := ZC1->ZC1_CC
    cTES     := ZC1->ZC1_TES
    cNatur   := ZC1->ZC1_NATUR
    cYOper   := ZC1->ZC1_YOPER

    cNumNovo := U_ZCTNumContrato()
    ConfirmSX8()

    RecLock("ZC1",.T.)
        ZC1->ZC1_FILIAL := xFilial("ZC1")
        ZC1->ZC1_CONTRA := cNumNovo
        ZC1->ZC1_DESCR  := cDescr
        ZC1->ZC1_FORNEC := cFornec
        ZC1->ZC1_LOJA   := cLoja
        ZC1->ZC1_DTINI  := dDtIniNovo
        ZC1->ZC1_DTFIM  := dDtFimNovo
        ZC1->ZC1_VALOR  := nValorNovo
        ZC1->ZC1_VALORI := nValorNovo
        ZC1->ZC1_CONDPG := cCondPg
        ZC1->ZC1_INDICE := cIndice
        ZC1->ZC1_PERREA := nPerRea
        ZC1->ZC1_PRODUT := cProdut
        ZC1->ZC1_UM     := cUM
        ZC1->ZC1_CC     := cCC
        ZC1->ZC1_TES    := cTES
        ZC1->ZC1_NATUR  := cNatur
        ZC1->ZC1_YOPER  := cYOper
        ZC1->ZC1_QTDPAR := nQtdPar
        ZC1->ZC1_QTDEMI := 0
        ZC1->ZC1_QTDFAL := nQtdPar
        ZC1->ZC1_STATUS := "1"
    MsUnlock()

    MsgInfo("Contrato "+AllTrim(cContrato)+" renovado com sucesso."+CRLF+;
            "Novo contrato: "+AllTrim(cNumNovo),"ZCT010 - Renovar Contrato")

    ZC1->(RestArea(aArea))
Return
