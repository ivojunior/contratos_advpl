#include "protheus.ch"
#include "tbiconn.ch"

/*/{Protheus.doc} UPDDICT
Cria/atualiza no dicionario de dados (SX2/SX3/SIX) as tabelas customizadas
utilizadas pela rotina de Controle de Contratos de Fornecedores:

    ZC1 - Contratos de Fornecedores (cabecalho do contrato)
    ZC2 - Historico de Pedidos de Compra gerados por contrato
    ZC3 - Indices de reajuste (percentual por competencia)

Executar uma unica vez (ou sempre que os fontes forem alterados) via
RPO/Smartclient, por exemplo: U_UPDDICT() em uma rotina TIR ou pelo
Advpl Command Window.

IMPORTANTE: apos a execucao, entrar no Configurador (SIGACFG) >
Base de Dados > Dicionario de Dados > "Atualizar Base de Dados" (ou
equivalente na versao em uso) para que as tabelas sejam materializadas
fisicamente no RDBMS. Este fonte apenas grava a definicao no dicionario.
@author  Ivo Caetano
@since   31/08/2026
/*/
User Function UPDDICT()
    Local aArea := GetArea()

    CriaSX2("ZC1","Contratos Fornec.","Contratos Fornec.","Contratos Fornec.","E")
    CriaSX2("ZC2","Hist.Ped.Contrato","Hist.Ped.Contrato","Hist.Ped.Contrato","E")
    CriaSX2("ZC3","Indices Reajuste" ,"Indices Reajuste" ,"Indices Reajuste" ,"C")

    CriaCamposZC1()
    CriaCamposZC2()
    CriaCamposZC3()

    CriaIndice("ZC1","1","ZC1_FILIAL+ZC1_CONTRA"             ,"Filial+Contrato")
    CriaIndice("ZC2","1","ZC2_FILIAL+ZC2_CONTRA+ZC2_SEQ"      ,"Filial+Contrato+Sequencia")
    CriaIndice("ZC3","1","ZC3_FILIAL+ZC3_INDICE+ZC3_COMPET"   ,"Filial+Indice+Competencia")

    RestArea(aArea)

    MsgAlert("Dicionario de dados atualizado (SX2/SX3/SIX)."+CRLF+;
              "Acesse o Configurador para materializar as tabelas no banco.","UPDDICT")
Return

/*/{Protheus.doc} CriaSX2
Grava a definicao da tabela (arquivo) no SX2, caso ainda nao exista.
@param cArq   Alias da tabela (ex: "ZC1")
@param cTit   Titulo padrao
@param cSpa   Titulo em espanhol
@param cEng   Titulo em ingles
@param cModo  "E"=Exclusivo por filial, "C"=Compartilhado entre filiais
/*/
Static Function CriaSX2(cArq,cTit,cSpa,cEng,cModo)
    DbSelectArea("SX2")
    DbSetOrder(1) //X2_ARQUIVO
    If DbSeek(cArq)
        Return
    EndIf

    RecLock("SX2",.T.)
        SX2->X2_ARQUIVO   := cArq
        SX2->X2_CHAVE     := ""
        SX2->X2_NOME      := cTit
        SX2->X2_NOMESPA   := cSpa
        SX2->X2_NOMEENG   := cEng
        SX2->X2_MODO      := cModo
        SX2->X2_INDICE    := cArq
        SX2->X2_ARQARLIM  := ""
    MsUnlock()
Return

/*/{Protheus.doc} CriaCampoSX3
Grava um campo no SX3, caso ainda nao exista.
/*/
Static Function CriaCampoSX3(cArq,cCampo,cTipo,nTam,nDec,cTitulo,cDescr,cPicture,cContext,cF3,cRelacao,cObrigat)
    Local nOrdem := 0

    DbSelectArea("SX3")
    DbSetOrder(2) //X3_CAMPO
    If DbSeek(cCampo)
        Return
    EndIf

    DbSetOrder(1) //X3_ARQUIVO+X3_ORDEM
    DbSeek(cArq)
    While !Eof() .And. SX3->X3_ARQUIVO == cArq
        nOrdem++
        DbSkip()
    End

    RecLock("SX3",.T.)
        SX3->X3_ARQUIVO  := cArq
        SX3->X3_CAMPO    := cCampo
        SX3->X3_TIPO     := cTipo        //C, N, D, M, L
        SX3->X3_TAMANHO  := nTam
        SX3->X3_DECIMAL  := nDec
        SX3->X3_TITULO   := cTitulo
        SX3->X3_DESCRIC  := cDescr
        SX3->X3_TITSPA   := cTitulo
        SX3->X3_TITENG   := cTitulo
        SX3->X3_DESCSPA  := cDescr
        SX3->X3_DESCENG  := cDescr
        SX3->X3_PICTURE  := cPicture
        SX3->X3_CONTEXT  := "R"          //campo real
        SX3->X3_VISUAL   := cTipo
        SX3->X3_USADO    := "S"
        SX3->X3_BROWSE   := "S"
        SX3->X3_TELA     := "S"
        SX3->X3_ORDEM    := StrZero(nOrdem+1,2)
        SX3->X3_F3       := cF3
        SX3->X3_RELACAO  := cRelacao
        SX3->X3_OBRIGAT  := cObrigat
        SX3->X3_VALID    := ""
        SX3->X3_NIVEL    := 1
        SX3->X3_INDEXA   := "N"
    MsUnlock()
Return

/*/{Protheus.doc} CriaIndice
Grava um indice (SIX) para a tabela informada.
/*/
Static Function CriaIndice(cArq,cOrdem,cChave,cDescri)
    DbSelectArea("SIX")
    DbSetOrder(1) //X6_ARQUIVO+X6_ORDEM
    If DbSeek(cArq+cOrdem)
        Return
    EndIf

    RecLock("SIX",.T.)
        SIX->X6_ARQUIVO  := cArq
        SIX->X6_ORDEM    := cOrdem
        SIX->X6_CHAVE    := cChave
        SIX->X6_DESCRI   := cDescri
        SIX->X6_DESCSPA  := cDescri
        SIX->X6_DESCENG  := cDescri
        SIX->X6_NICKNAME := cArq+cOrdem
        SIX->X6_UNIQUE   := "1"
        SIX->X6_PROPRI   := "S"
    MsUnlock()
Return

/*/{Protheus.doc} CriaCamposZC1
Campos da tabela ZC1 - Contratos de Fornecedores (cabecalho)
/*/
Static Function CriaCamposZC1()
    CriaCampoSX3("ZC1_FILIAL","ZC1_FILIAL","C",8,0,"Filial"       ,"Filial"                       ,"@!"        ,"R","" ,"","N")
    CriaCampoSX3("ZC1_CONTRA","ZC1_CONTRA","C",10,0,"Contrato"    ,"Numero do Contrato"           ,"@!"        ,"R","" ,"","S")
    CriaCampoSX3("ZC1_DESCR" ,"ZC1_DESCR" ,"C",40,0,"Descricao"   ,"Descricao/Objeto do contrato"  ,"@!"        ,"R","" ,"","S")
    CriaCampoSX3("ZC1_FORNEC","ZC1_FORNEC","C",6,0 ,"Fornecedor"  ,"Codigo do Fornecedor"          ,"@!"        ,"R","SA2","","S")
    CriaCampoSX3("ZC1_LOJA"  ,"ZC1_LOJA"  ,"C",2,0 ,"Loja"        ,"Loja do Fornecedor"            ,"@!"        ,"R","" ,"","S")
    CriaCampoSX3("ZC1_DTINI" ,"ZC1_DTINI" ,"D",8,0 ,"Dt.Inicio"   ,"Data de inicio da vigencia"    ,""          ,"R","" ,"","S")
    CriaCampoSX3("ZC1_DTFIM" ,"ZC1_DTFIM" ,"D",8,0 ,"Dt.Fim"      ,"Data de termino da vigencia"   ,""          ,"R","" ,"","S")
    CriaCampoSX3("ZC1_VALOR" ,"ZC1_VALOR" ,"N",17,2,"Vl.Mensal"   ,"Valor da mensalidade vigente"  ,"@E 999,999,999.99","R","","","S")
    CriaCampoSX3("ZC1_VALORI","ZC1_VALORI","N",17,2,"Vl.Original" ,"Valor mensal original do contrato","@E 999,999,999.99","R","","","N")
    CriaCampoSX3("ZC1_CONDPG","ZC1_CONDPG","C",3,0 ,"Cond.Pagto"  ,"Condicao de pagamento"         ,"@!"        ,"R","SE4","","S")
    CriaCampoSX3("ZC1_INDICE","ZC1_INDICE","C",6,0 ,"Indice"      ,"Indice de reajuste (ZC3)"      ,"@!"        ,"R","","","N")
    CriaCampoSX3("ZC1_PERREA","ZC1_PERREA","N",3,0 ,"Period.Reaj.","Periodicidade do reajuste (meses)","999"    ,"R","","","N")
    CriaCampoSX3("ZC1_DTULTR","ZC1_DTULTR","D",8,0 ,"Dt.Ult.Reaj.","Data do ultimo reajuste aplicado",""        ,"R","","","N")
    CriaCampoSX3("ZC1_PRODUT","ZC1_PRODUT","C",15,0,"Produto"     ,"Produto/Servico usado no pedido","@!"       ,"R","SB1","","S")
    CriaCampoSX3("ZC1_UM"    ,"ZC1_UM"    ,"C",2,0 ,"UM"          ,"Unidade de medida"             ,"@!"        ,"R","","","N")
    CriaCampoSX3("ZC1_CC"    ,"ZC1_CC"    ,"C",9,0 ,"Cent.Custo"  ,"Centro de custo"               ,"@!"        ,"R","CTT","","S")
    CriaCampoSX3("ZC1_COMPRA","ZC1_COMPRA","C",6,0 ,"Comprador"   ,"Codigo do comprador"           ,"@!"        ,"R","SY1","","N")
    CriaCampoSX3("ZC1_TES"   ,"ZC1_TES"   ,"C",3,0 ,"TES"         ,"Tipo de entrada/saida"         ,"@!"        ,"R","SF4","","N")
    CriaCampoSX3("ZC1_QTDPAR","ZC1_QTDPAR","N",3,0 ,"Qtd.Parcelas","Total de mensalidades previstas","999"      ,"R","","","N")
    CriaCampoSX3("ZC1_QTDEMI","ZC1_QTDEMI","N",3,0 ,"Qtd.Emitidas","Mensalidades/pedidos ja emitidos","999"     ,"R","","","N")
    CriaCampoSX3("ZC1_QTDFAL","ZC1_QTDFAL","N",3,0 ,"Qtd.Faltam"  ,"Mensalidades restantes ate o fim","999"      ,"R","","","N")
    CriaCampoSX3("ZC1_COMPET","ZC1_COMPET","C",6,0 ,"Ult.Compet." ,"Ultima competencia gerada AAAAMM","999999"   ,"R","","","N")
    CriaCampoSX3("ZC1_DTULGE","ZC1_DTULGE","D",8,0 ,"Dt.Ult.Ger." ,"Data da ultima geracao de pedido",""         ,"R","","","N")
    CriaCampoSX3("ZC1_STATUS","ZC1_STATUS","C",1,0 ,"Status"      ,"1=Ativo 2=Suspenso 3=Encerrado 4=Cancelado","@!","R","","","N")
    CriaCampoSX3("ZC1_OBS"   ,"ZC1_OBS"   ,"M",0,0 ,"Observacao"  ,"Observacoes do contrato"       ,""          ,"R","","","N")
Return

/*/{Protheus.doc} CriaCamposZC2
Campos da tabela ZC2 - Historico de pedidos gerados por contrato
/*/
Static Function CriaCamposZC2()
    CriaCampoSX3("ZC2_FILIAL","ZC2_FILIAL","C",8,0 ,"Filial"    ,"Filial"                        ,"@!","R","" ,"","N")
    CriaCampoSX3("ZC2_CONTRA","ZC2_CONTRA","C",10,0,"Contrato"  ,"Numero do Contrato (ZC1)"      ,"@!","R","ZC1","","S")
    CriaCampoSX3("ZC2_SEQ"   ,"ZC2_SEQ"   ,"C",4,0 ,"Sequencia" ,"Sequencia da parcela gerada"   ,"9999","R","","","N")
    CriaCampoSX3("ZC2_COMPET","ZC2_COMPET","C",6,0 ,"Competenc.","Competencia AAAAMM"            ,"999999","R","","","N")
    CriaCampoSX3("ZC2_NUMPC" ,"ZC2_NUMPC" ,"C",6,0 ,"Num.Pedido","Numero do Pedido de Compra (SC7)","@!","R","SC7","","N")
    CriaCampoSX3("ZC2_VALOR" ,"ZC2_VALOR" ,"N",17,2,"Valor"     ,"Valor gerado na parcela"       ,"@E 999,999,999.99","R","","","N")
    CriaCampoSX3("ZC2_DTGER" ,"ZC2_DTGER" ,"D",8,0 ,"Dt.Geracao","Data em que o pedido foi gerado",""   ,"R","","","N")
    CriaCampoSX3("ZC2_USUARI","ZC2_USUARI","C",20,0,"Usuario"   ,"Usuario/job que gerou o pedido","@!","R","","","N")
    CriaCampoSX3("ZC2_STATUS","ZC2_STATUS","C",1,0 ,"Status"    ,"P=Pedido Gerado C=Cancelado"   ,"@!","R","","","N")
Return

/*/{Protheus.doc} CriaCamposZC3
Campos da tabela ZC3 - Indices de reajuste (percentual mensal por indice)
/*/
Static Function CriaCamposZC3()
    CriaCampoSX3("ZC3_FILIAL","ZC3_FILIAL","C",8,0 ,"Filial"    ,"Filial"                     ,"@!","R","" ,"","N")
    CriaCampoSX3("ZC3_INDICE","ZC3_INDICE","C",6,0 ,"Indice"    ,"Codigo do indice (ex: IGPM)","@!","R","" ,"","S")
    CriaCampoSX3("ZC3_DESCR" ,"ZC3_DESCR" ,"C",30,0,"Descricao" ,"Descricao do indice"        ,"@!","R","" ,"","N")
    CriaCampoSX3("ZC3_COMPET","ZC3_COMPET","C",6,0 ,"Competenc.","Competencia AAAAMM"         ,"999999","R","","","S")
    CriaCampoSX3("ZC3_PERC"  ,"ZC3_PERC"  ,"N",7,4 ,"Percentual","Percentual do indice no mes","@E 999.9999","R","","","S")
Return
