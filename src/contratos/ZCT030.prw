#include "protheus.ch"
#include "fwmvcdef.ch"

#define ZCT030_TABLE "ZC3"

/*/{Protheus.doc} ZCT030
Cadastro auxiliar de Indices de Reajuste. Permite alimentar mes a mes o
percentual de um indice (ex: IGPM, IPCA, INPC) que sera utilizado pela
rotina ZCT020 para reajustar automaticamente o valor da mensalidade dos
contratos vinculados a este indice.
@author  Ivo Caetano
@since   31/08/2026
/*/
User Function ZCT030()
    Local oBrowse := FWMBrowse():New()

    oBrowse:SetAlias(ZCT030_TABLE)
    oBrowse:SetDescription("Indices de Reajuste")
    oBrowse:SetMenuDef("ZCT030")
    oBrowse:Activate()
Return

Static Function MenuDef()
    Local aRotina := {}

    ADD OPTION aRotina TITLE "Pesquisar"  ACTION "PesqBrw"        OPERATION 1 ACCESS 0
    ADD OPTION aRotina TITLE "Visualizar" ACTION "VIEWDEF.ZCT030" OPERATION 2 ACCESS 0
    ADD OPTION aRotina TITLE "Incluir"    ACTION "VIEWDEF.ZCT030" OPERATION 3 ACCESS 0
    ADD OPTION aRotina TITLE "Alterar"    ACTION "VIEWDEF.ZCT030" OPERATION 4 ACCESS 0
    ADD OPTION aRotina TITLE "Excluir"    ACTION "VIEWDEF.ZCT030" OPERATION 5 ACCESS 0
Return aRotina

Static Function ModelDef()
    Local oStruZC3 := FWFormStruct(1,ZCT030_TABLE)
    Local oModel

    oModel := MPFormModel():New("ZCT030M")
    oModel:AddFields("ZC3MASTER",,oStruZC3)
    oModel:SetPrimaryKey({"ZC3_FILIAL","ZC3_INDICE","ZC3_COMPET"})
    oModel:SetDescription("Indices de Reajuste")
Return oModel

Static Function ViewDef()
    Local oModel   := ModelDef()
    Local oStruZC3 := FWFormStruct(2,ZCT030_TABLE)
    Local oView

    oView := FWFormView():New()
    oView:SetModel(oModel)
    oView:AddField("VIEW_ZC3","ZC3MASTER",oStruZC3)
    oView:CreateHorizontalBox("TELA",100)
    oView:SetOwnerView("VIEW_ZC3","TELA")
Return oView
