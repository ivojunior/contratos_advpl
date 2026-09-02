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
    ADD OPTION aRotina TITLE "Previsao Financeira"        ACTION "U_ZCT040()" OPERATION 8 ACCESS 0
Return aRotina

/*/{Protheus.doc} ModelDef
Define o modelo de dados (campos + regras) do cadastro de contratos.
/*/
Static Function ModelDef()
    Local oStruZC1 := FWFormStruct(1,ZCT010_TABLE)
    Local oModel

    oStruZC1:SetProperty("ZC1_STATUS",MODEL_FIELD_INIT,FwBuildFeature(STRUCT_FEATURE_INIPAD,'"1"'))
    oStruZC1:SetProperty("ZC1_QTDEMI",MODEL_FIELD_INIT,FwBuildFeature(STRUCT_FEATURE_INIPAD,'0'))

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
confirmar a tela, antes da persistencia automatica do MVC): garante
consistencia das datas de vigencia, valor da mensalidade e recalcula a
quantidade de parcelas/faltantes via LoadValue.

IMPORTANTE: nao usar o 4o parametro (bCommit) para validacao — quando
informado, ele substitui a gravacao automatica do MVC e o proprio
RecLock/MsUnlock passa a ser responsabilidade do bloco informado (ver
README). Retornar .F. aqui aborta a gravacao normalmente.
/*/
Static Function ZCTCommit(oModel)
    Local oStruZC1  := oModel:GetModel("ZC1MASTER")
    Local dDtIni    := oStruZC1:GetValue("ZC1_DTINI")
    Local dDtFim    := oStruZC1:GetValue("ZC1_DTFIM")
    Local nValor    := oStruZC1:GetValue("ZC1_VALOR")
    Local nQtdPar   := 0
    Local nQtdEmi   := oStruZC1:GetValue("ZC1_QTDEMI")

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

    nQtdPar := U_ZCTCalcParc(dDtIni,dDtFim)

    oStruZC1:LoadValue("ZC1_QTDPAR",nQtdPar)
    oStruZC1:LoadValue("ZC1_QTDFAL",nQtdPar - nQtdEmi)

    If Empty(oStruZC1:GetValue("ZC1_VALORI"))
        oStruZC1:LoadValue("ZC1_VALORI",nValor)
    EndIf
Return .T.
