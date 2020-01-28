/* --- Start of code for "BalanceamentoSeparacaoAframe_v1.02(remoto)". --- */
libname SIMULA "F:\data\natura\Balanceamento\balanceamento_compartilhado";
libname WRSTEMP "F:\data\natura\Balanceamento\balanceamento_compartilhado\&cod_cd";
/* Classe Main*/
/*%let CLASS_PATH= C:\Users\Fabio\Google Drive\Projetos\Natura\Balanceamento\Programas\v1.01;*/
%let CLASS_PATH=F:\data\natura\Balanceamento\balanceamento_compartilhado\REPOSITORIO STP;
options mprint symbolgen mlogic;
%include "&CLASS_PATH/BALLog_v1.09.sas";
%include "&CLASS_PATH/BALPreProc_v1.09.sas";
%include "&CLASS_PATH/BALAlocaArea_v1.07.sas";
%include "&CLASS_PATH/BALAlocaModulo_v1.09.sas";
%include "&CLASS_PATH/BALAlocaCanal_v1.08.sas";
%include "&CLASS_PATH/BALPosProc_v1.06.sas";

%macro AlocaCanalAframe(cd);
proc optmodel printlevel=0;
	%let val_areas = 'AFRAME';
	/*Lê DESCONTINUADOS_&cd*/
	set<str,str,num,num> XDescSet;
	read data WRSTEMP.BLS1_DESCONTINUADOS_&cd into XDescSet=[AREA CANAL COD_VENDA MATERIAL]; 
	set<num,num> DescSet = setof{<a,can,cv,mat> in XDescSet} <cv,mat>;
	/*Lê PRODUTOS_&cd*/
	set<num,num> ProdutoSet;
	str descricao{ProdutoSet};
	num demanda{ProdutoSet};




	num volume{ProdutoSet};
	num itens_caixa{ProdutoSet};
	read data WRSTEMP.BLS1_PRODUTOS_&cd into ProdutoSet=[COD_VENDA MATERIAL] demanda=DEMANDA_PERC descricao volume itens_caixa;
	/* Cadastro de Materiais*/
	set<num,num> CadMatSet;
	num comprimento{CadMatSet};
	num largura{CadMatSet};
	num altura{CadMatSet};
	read data CADASTRO_MATERIAIS into CadMatSet=[COD_VENDA MATERIAL] comprimento largura altura;

	/*Lê RESTRICAO_AREA*/
	set<str> AreaSet;
	num capArea{AreaSet};
	num replArea{AreaSet};
	num fixaArea{AreaSet};
	read data WRSTEMP.BLE_RESTRICAO_AREA_&cd.(where=(area in (&val_areas))) into AreaSet=[AREA]
		capArea=CAPACIDADE replArea=REPLICACAO fixaArea=fixa;
	/*Lê ESTRUTURA_CD*/
	set<str,str> CanalSet;
	str modCanal{CanalSet};
	num estacao{CanalSet};
	read data WRSTEMP.BLE_ESTRUTURA_CD_&cd.(where=(STATUS~='INDISPONÍVEL' AND ESTACAO=1 and area not in (&val_areas))) 
		into CanalSet=[AREA CANAL] modCanal=MODULO estacao; 
	/* Lê solução de alocação de área*/
	set<num,num,str> ProdutoAreaSet;
	num trocaArea{ProdutoAreaSet};
	read data WRSTEMP.BLS2_sol_mapa3(where=(area in (&val_areas))) into ProdutoAreaSet=[COD_VENDA MATERIAL AREA] trocaArea;
	/*Lê PRODUTOS_AREA_&cd*/
	set<str,str,str,num,num> XProdutoAreaSet;
	read data WRSTEMP.BLS1_PRODUTO_AREA_&cd(where=(area in (&val_areas) and estacao=1)) into XProdutoAreaSet=[AREA MODULO CANAL COD_VENDA MATERIAL];
	set<num,num,str> ProdutoCanalSet = 
		setof{<a,mod,can,cv,mat> in XProdutoAreaSet}<cv,mat,can>;
	/* Lê OBJ_AREA*/
	set<str> objSet;
	num max_trocas{objSet};
	read data WRSTEMP.BLE_OBJ_AREA_&cd. into objSet=[AREA] max_trocas=trocas;

	/* Carrega nova estrutura*/
	set<str> AframeSet;
	str status{AframeSet};
	str giro{AframeSet};
	num canal_virtual{AframeSet};
	read data WRSTEMP.BLE_ESTRUTURA_AFRAME_&cd into AframeSet=[CANAL] status giro canal_virtual;
	set CanalVSet = setof{can in AframeSet: canal_virtual[can] ~= .}<canal_virtual[can]>;
	put canalvset=;

	set AlocaCanalSet = setof{can in CanalVSet, <cv,mat,a> in ProdutoAreaSet}<cv,mat,can>;
	var varAloca{AlocaCanalSet} binary;

	/*Capacidade*/
	con cap:
		sum{<cv,mat,can> in AlocaCanalSet} varAloca[cv,mat,can] <= card(CanalVSet);

	/* Um canal*/
	con umCanal{<cv,mat,a> in ProdutoAreaSet}: sum{<(cv),(mat),can> in AlocaCanalSet} varAloca[cv,mat,can] = 1;

	/*Um material*/
	con umMat{can in CanalVSet}:
		sum{<cv,mat,(can)> in AlocaCanalSet} varAloca[cv,mat,can] <= 1;

	/* Troca*/
	set<num,num,num> AlocaAnterior = setof{<cv,mat,can> in ProdutoCanalSet: status[can] = ''} <cv,mat,canal_virtual[can]>;
	/* Se o material estava alocado em mais de um canal virtual, conta troca só se mudar todos*/
	set matM1Canal = setof{<cv,mat,a> in ProdutoAreaSet: card(slice(<cv,mat,*>,AlocaAnterior))>1}<cv,mat>;
	num ncardMat{<cv,mat> in matM1Canal} = card(slice(<cv,mat,*>,AlocaAnterior));
	num cardCanV = sum{<cv,mat,a> in ProdutoAreaSet: card(slice(<cv,mat,*>,AlocaAnterior))>1} (card(slice(<cv,mat,*>,AlocaAnterior))-1);

	/* Conjunto de canais virtuais com mais de um material*/
	set canM1Mat = setof{<cv,mat,can> in AlocaAnterior: card(slice(<*,*,can>,AlocaAnterior))>1}<can>;
	num ncardCan{can in canM1Mat} = card(slice(<*,*,can>,AlocaAnterior));
	num cardMat = sum{<cv,mat,can> in AlocaAnterior: card(slice(<*,*,can>,AlocaAnterior))>1} (card(slice(<*,*,can>,AlocaAnterior))-1);
	num matAnt{AframeSet}, matAloca{AframeSet}, largCan{AframeSet};
	num cvAnt{AframeSet}, cvAloca{AframeSet}, largMat{AframeSet};

/*	restricao de similares*/
	set<num> SimilarSet;
	str grupo{SimilarSet};
	read data SIMULA.BLE_SIMILARES into SimilarSet=[COD_VENDA] grupo;
	set<str> GrupoSet = setof{cv in SimilarSet} <grupo[cv]>;
	set<num> CVSimilarSet{gp in GrupoSet} = setof{cv in SimilarSet: grupo[cv]=gp}<cv>;

/*	con simLadoCon{gp in GrupoSet, cv1 in CVSimilarSet[(gp)], cv2 in CVSimilarSet[(gp)], */
/*		<(cv1),mat1,can1> in AlocaCanalSet, <(cv2),mat2,can2> in AlocaCanalSet : cv1>cv2 and can1=can2+1}:*/
/*		varAloca[cv1,mat1,can1] + varAloca[cv2,mat2,can2] <= 1;*/

	/* Penalização por largura*/
	num larguraCan{CanalVSet} init 1E10;
	for{<cv,mat,canV> in AlocaAnterior} do;
		if larguraCan[canV] > median(comprimento[cv,mat],largura[cv,mat],altura[cv,mat]) then
			larguraCan[canV] = median(comprimento[cv,mat],largura[cv,mat],altura[cv,mat]);
	end;
	num larguraMat{<cv,mat,a> in ProdutoAreaSet} = median(comprimento[cv,mat],largura[cv,mat],altura[cv,mat]);
	var varTrocaLarg{ProdutoAreaSet} binary init 0;
	con largPenalidade{<cv,mat,a> in ProdutoAreaSet, canV in CanalVSet: larguraMat[cv,mat,a]>larguraCan[canV]}:
		varTrocaLarg[cv,mat,a] >= varAloca[cv,mat,canV];
	impvar ivarTLarg = sum{<cv,mat,a> in ProdutoAreaSet} varTrocaLarg[cv,mat,a];

	
	/* Minimizar Trocas*/
	impvar varTrocas = sum{<cv,mat,can> in AlocaAnterior: <cv,mat,can> in AlocaCanalSet} (1-varAloca[cv,mat,can]);
	min objTrocas = varTrocas;

	solve with milp/absobjgap=0.03 maxtime=300;
	num minTrocas;
	minTrocas = objTrocas;
	Title 'AFRAME: Otimização em 3 etapas';
	print "Minimizar número de trocas: " _SOLUTION_STATUS_;
	print 'Máximo trocas epecificado = ' max_trocas['AFRAME'] 'Mínimo de trocas necessárias = ' minTrocas;
	if minTrocas > max_trocas['AFRAME'] then do;
		max_trocas['AFRAME'] = minTrocas;
	end;



	print 'Máximo de trocas utilizado = ' max_trocas['AFRAME'];

	con trocas:
		varTrocas <= max_trocas['AFRAME']; 

	/* Maximizar produtividade*/
	set<str> ClasseSet = /AA A B C D E F/;
	num tempo{ClasseSet} = [1 1.5 2 2.5 3 3.5 4];

	max vel = sum{<cv,mat,can> in AlocaCanalSet, can_real in AframeSet: canal_virtual[can_real]=can} 
				varAloca[cv,mat,can]*&produtividade.*28*demanda[cv,mat]/itens_caixa[cv,mat]/tempo[giro[can_real]];

	solve with milp/ primalin relobjgap=0.01 maxtime=600;
		
	print "Maximizar produtividade: " _SOLUTION_STATUS_;
	num veltot;
	veltot = vel * (1 - &max_trocas_repl_aframe.);
	con prodMax:
		sum{<cv,mat,can> in AlocaCanalSet, can_real in AframeSet: canal_virtual[can_real]=can} 
				varAloca[cv,mat,can]*&produtividade.*28*demanda[cv,mat]/itens_caixa[cv,mat]/tempo[giro[can_real]] >= veltot;


	min trocaLarg = ivarTLarg;

	solve with milp/ primalin relobjgap=0.01 maxtime=150;
	num minTLarg;
	minTLarg = trocaLarg;
	print "Minimizar violação de largura: " _SOLUTION_STATUS_;
	print "Número de violações necessárias = " minTLarg;
	
	/* Saída*/
	/* Imprime quais produtos trocaram*/
	set<num,num,num> TrocaSet;
	TrocaSet = setof{<cv,mat,canv> in AlocaAnterior: <cv,mat,canv> in AlocaCanalSet and varAloca[cv,mat,canv]<0.1}<cv,mat,canv>;
	num novo_canv{TrocaSet};
	for{<cv,mat,canv> in TrocaSet} do;
		for{<(cv),(mat),canv2> in AlocaCanalSet: varAloca[(cv),(mat),canv2]>0.1}
			novo_canv[cv,mat,canv] = canv2;
	end;
	print novo_canv;
	
	/* Imprime análise de produtividade*/
	str grupocan{AframeSet};
	str descricaocan{AframeSet};
	num demandacan{AframeSet};
	num comprimentocan{AframeSet};
	num alturacan{AframeSet};
	num larguracanal{AframeSet};
	num volumecan{AframeSet};
	num giro_mat_anterior{AframeSet};
	num giro_mat_alocado{AframeSet};
	for{canr in AframeSet, <cv,mat,(canr)> in ProdutoCanalSet: <cv,mat,canal_virtual[canr]> in AlocaCanalSet} do;
		giro_mat_anterior[canr] = &produtividade.*28*demanda[cv,mat]/itens_caixa[cv,mat];
		matAnt[canr] = mat;

		cvAnt[canr] = cv;
		largCan[canr] = median(comprimento[cv,mat],largura[cv,mat],altura[cv,mat]);
	end;
	for{canr in AframeSet, <cv,mat,can> in AlocaCanalSet: canal_virtual[canr]=can and varAloca[cv,mat,can] >= 0.1} do;
		matAloca[canr] = mat;
		cvAloca[canr] = cv;
		giro_mat_alocado[canr] = &produtividade.*28*demanda[cv,mat]/itens_caixa[cv,mat];
		if cv in similarSet then grupocan[canr] = grupo[cv];
		largMat[canr] = median(comprimento[cv,mat],largura[cv,mat],altura[cv,mat]);
		descricaocan[canr]=descricao[cv,mat];
		demandacan[canr]=demanda[cv,mat];
		comprimentocan[canr]=comprimento[cv,mat];
		alturacan[canr]=altura[cv,mat];
		larguracanal[canr]=largura[cv,mat];
		volumecan[canr]=volume[cv,mat];
	end;
	create data WRSTEMP.BLS3_sol_aframe_canais from [CANAL]={canr in AframeSet} status GIRO canal_virtual largCan cvAnt 

		matAnt cvAloca matAloca largMat grupocan giro_mat_anterior giro_mat_alocado;

	create data solucao_canal_aframe from [CANAL]={canr in AframeSet} AREA="AFRAME" MODULO="" COD_VENDA=cvAloca 
		MATERIAL=matAloca descricao=descricaocan classificacao=giro demanda=demandacan comprimento=comprimentocan altura=alturacan 
		largura=larguracanal volume=volumecan;

quit;

%mend AlocaCanalAframe;

/* Aloca Canal*/
%macro AlocaCanal(cd);

PROC SQL;
   CREATE TABLE WORK.SOLUCAO_MODULO_01 AS 
   SELECT distinct t1.AREA LENGTH=12, 
          t1.MODULO, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          /* TROCA */
            (ifn(t2.COD_VENDA is missing,1,0)) AS TROCA,
          t1.NCANAIS
      FROM WRSTEMP.BLS3_SOLUCAO_MODULO t1
           LEFT JOIN WRSTEMP.BLS1_PRODUTO_AREA_&cd t2 ON (t1.AREA = t2.AREA) AND (t1.MODULO = t2.MODULO) 
				AND (t1.COD_VENDA = t2.COD_VENDA) AND (t1.MATERIAL = t2.MATERIAL)
      WHERE t1.AREA IN ('AFRAME','AFRAME MAQ','PBL AAG','PBL AG','PBL MG','PBL BG');
   CREATE TABLE WORK.SOLUCAO_MODULO_02 AS 
   SELECT DISTINCT t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.AREA, 
          t2.MODULO,
          t1.trocaArea AS TROCA,
		  1 AS NCANAIS
      FROM WRSTEMP.BLS2_SOL_MAPA3 t1
	  	INNER JOIN WRSTEMP.BLE_ESTRUTURA_CD_&cd t2
		ON t1.AREA=t2.AREA AND t2.ESTACAO=1 AND t1.AREA = 'MASS PICKING';
QUIT;
DATA WORK.SOLUCAO_MODULO;
	SET SOLUCAO_MODULO_01 SOLUCAO_MODULO_02;
RUN;
proc sql noprint;
	create table areas as select distinct area from solucao_modulo;
	select count(*) into :pbl_cnt from areas where area in ('MASS PICKING','PBL AAG','PBL AG','PBL MG','PBL BG');
/*	select count(*) into :aframe_cnt from areas where area in ('AFRAME','AFRAME MAQ');*/
quit;

proc sql;
	create table WRSTEMP.BLS4_solucao_canal(
	AREA	Character	12,			
	MODULO	Character	14,		
	CANAL	Character	11,	
	COD_VENDA	Numeric	8,		
	MATERIAL	Numeric	8,		
	descricao	Character	40,			
	classificacao	Character	2,			
	demanda	Numeric	8,			
	comprimento	Numeric	8,			
	altura	Numeric	8,			
	largura	Numeric	8,			
	volume	Numeric	8			
);
quit;
%if &pbl_cnt ~= 0 %then %do;
	%alocaPBL(&cd)
	data WRSTEMP.BLS4_solucao_canal;
		set WRSTEMP.BLS4_solucao_canal solucao_canal_PBL;
	run;
%end;

%AlocaCanalAframe(&cd)


data WRSTEMP.BLS4_solucao_canal;
	set WRSTEMP.BLS4_solucao_canal solucao_canal_AFRAME;
run;

proc sort data=WRSTEMP.BLS4_solucao_canal;
	by AREA MODULO CANAL;
run;
%mend AlocaCanal;

%macro AlocaModulo(cd);
%calc_max_repl
proc optmodel printlevel=0;
	%let val_areas = 'SCS' 'Robô-Pick' 'MASS PICKING' 'AFRAME';
	/*Lê DESCONTINUADOS_&cd*/
	set<str,str,num,num> XDescSet;
	read data WRSTEMP.BLS1_DESCONTINUADOS_&cd into XDescSet=[AREA CANAL COD_VENDA MATERIAL]; 
	set<num,num> DescSet = setof{<a,can,cv,mat> in XDescSet} <cv,mat>;
	/*Lê PRODUTOS_&cd*/
	set<num,num> ProdutoSet;
	str descricao{ProdutoSet};
	num demanda{ProdutoSet};
	num comprimento{ProdutoSet};
	num largura{ProdutoSet};
	num altura{ProdutoSet};
	num volume{ProdutoSet};

	read data WRSTEMP.BLS1_PRODUTOS_&cd into ProdutoSet=[COD_VENDA MATERIAL] demanda=DEMANDA_PERC descricao comprimento largura altura volume;
	/*Lê PRODUTOS_AREA_&cd*/
	set<str,str,str,num,num> XProdutoAreaSet;
	read data WRSTEMP.BLS1_PRODUTO_AREA_&cd(where=(area not in (&val_areas) and estacao=1)) into XProdutoAreaSet=[AREA MODULO CANAL COD_VENDA MATERIAL];
	set<num,num,str,str> ProdutoModSet = setof{<a,mod,can,cv,mat> in XProdutoAreaSet: <cv,mat> not in DescSet}<cv,mat,a,mod>;
	/*Lê RESTRICAO_AREA*/
	set<str> AreaSet;
	num capArea{AreaSet};
	num replArea{AreaSet};
	num fixaArea{AreaSet};
	read data WRSTEMP.BLE_RESTRICAO_AREA_&cd.(where=(area not in (&val_areas))) into AreaSet=[AREA]
		capArea=CAPACIDADE replArea=REPLICACAO fixaArea=fixa;
	/*Lê ESTRUTURA_CD*/
	set<str,str> CanalSet;
	str modCanal{CanalSet};
	num estacao{CanalSet};
	read data WRSTEMP.BLE_ESTRUTURA_CD_&cd.(where=(STATUS~='INDISPONÍVEL' AND ESTACAO=1 and area not in (&val_areas))) 
		into CanalSet=[AREA CANAL] modCanal=MODULO estacao; 

	/* Lê replicação máxima possível no módulo (restrição para o AFRAME)*/
	set<str,str> ReplModuloSet;
	num max_repl_mod{ReplModuloSet};
	num cnt_repl_max{ReplModuloSet};
	read data WORK.MAX_REPL into ReplModuloSet=[AREA MODULO] max_repl_mod cnt_repl_max;

	/* Lê solução de alocação de área*/
	set<num,num,str> ProdutoAreaSet;
	num trocaArea{ProdutoAreaSet};
	read data WRSTEMP.BLS2_sol_mapa3(where=(area not in (&val_areas))) into ProdutoAreaSet=[COD_VENDA MATERIAL AREA] trocaArea;

	/*Lê REPLICACAO  de canais*/
	set<num,num,str> ReplSet;
	num repl{ReplSet};
	num cardMod{ReplSet};
	num fixa_repl{ReplSet};
	read data WRSTEMP.BLS1_REPLICACAO_&cd into ReplSet=[COD_VENDA MATERIAL AREA] repl cardMod fixa_repl; 

	/* Lê OBJ_AREA*/
	set<str> objSet;
	num max_trocas{objSet};
	read data WRSTEMP.BLE_OBJ_AREA_&cd. into objSet=[AREA] max_trocas=trocas;

	/* Lê OBJ_MODULO*/
	set<str,str> ObjModuloSet;
	num objModulo{ObjModuloSet};
	num ordemModulo{ObjModuloSet};
	read data WRSTEMP.BLE_OBJ_MODULO_&cd. into ObjModuloSet=[AREA MODULO] objModulo=carga ordemModulo=ORDEM;

	/****************** Prepara modelo ******************/
	str Area;
	Area = 'PBL BG';
	set<str> ModuloSet = setof{<a,can> in CanalSet: a=Area}<modCanal[a,can]>;
	set<num,num,str> AlocaModuloSet = setof{<cv,mat,a> in ProdutoAreaSet, mod in ModuloSet: a=Area}<cv,mat,mod>;

	var varAloca{<cv,mat,mod> in AlocaModuloSet} binary;

	/* Area intereira está fixa*/
	num fixaModulo{ModuloSet} init 0;

	set modFixaSet = setof{<cv,mat,a,mod> in ProdutoModSet: <cv,mat,mod> in AlocaModuloSet and fixaModulo[mod] = 1} <cv,mat,mod>;
	con fixarArea1{<cv,mat,mod> in modFixaSet}:
		varAloca[cv,mat,mod] = 1;
	con fixarArea2{<cv,mat,mod> in AlocaModuloSet: fixaModulo[mod] = 1 and <cv,mat,mod> not in modFixaSet}:
		varAloca[cv,mat,mod] = 0;

	/* Exatamente card módulos para cada produto */
	con maxModulo{<cv,mat,a> in ProdutoAreaSet: a = Area and fixaArea[a] = 0}:
		sum{<(cv),(mat),mod> in AlocaModuloSet} varAloca[cv,mat,mod] = cardMod[cv,mat,a];

	/* Número de trocas*/
	var varTrocas >= 0;

	set ProdContaTroca = setof{<cv,mat,a> in ProdutoAreaSet: a=Area and trocaArea[cv,mat,a]=0}<cv,mat>;
	set<num,num,str> AlocaAnterior = setof{<cv,mat,a,mod> in ProdutoModSet: mod in ModuloSet and <cv,mat> in ProdContaTroca}<cv,mat,mod>;
	con trocas:
		varTrocas = sum{<cv,mat,mod> in AlocaAnterior} (1-varAloca[cv,mat,mod]); 
	/* Calcula o card anterior para cada produto*/
	set<num,num> ProdAlocaAnterior = setof{<cv,mat,mod> in AlocaAnterior}<cv,mat>;
	num cardDif{<cv,mat> in ProdAlocaAnterior}= abs(sum{<(cv),(mat),mod> in AlocaAnterior}1 - cardMod[cv,mat,Area]);
	con maxTrocas:
		varTrocas <= max_trocas[Area] + sum{<cv,mat> in ProdAlocaAnterior}cardDif[cv,mat];

/*****************************************************************************************/
/* Aplicar parâmetro fixa_replicacao ==> manter repl para estes produtos*/
	set<str,str> ModuloAreaSet = setof{<a,can> in CanalSet}<a,modCanal[a,can]>;
	set<num,num,str> ReplModSet = setof{<cv,mat,a> in ProdutoAreaSet, <(a),mod> in ModuloAreaSet}<cv,mat,mod>;
	num replMod{ReplModSet} init 1, num_repl;
	/* Aplicar parâmetro fixa_replicacao ==> manter repl para estes produtos*/
	for{<cv,mat,mod> in ReplModSet, a in AreaSet: <a,mod> in ModuloAreaSet} do;
		if fixa_repl[cv,mat,a] = 1 then do;
			num_repl = sum{<(a),(mod),can,(cv),(mat)> in XProdutoAreaSet}1;
			if num_repl > 0 then 
				replMod[cv,mat,mod] = num_repl;
			else
				replMod[cv,mat,mod] = repl[cv,mat,a];
		end;
		else replMod[cv,mat,mod] = repl[cv,mat,a];
	end;
/*****************************************************************************************/
	/*Restrição de replicação por módulo. Para matyas a configuração do aframe impede que aloque algumas replicações.*/
	/* Exemplo: alguns módulos contém no máximo 2 canais consecutivos e, portanto, não é possível alocar materiais com repl = 4*/
	con replMaxMod{<cv,mat,mod> in AlocaModuloSet: replMod[cv,mat,mod] > max_repl_mod[Area,mod]}:
		varAloca[cv,mat,mod] = 0;
	/* Não alocar mais materiais replicados do que o número "buracos" (canais consecutivos)*/
	con nReplMax{<Area,mod> in ModuloAreaSet}:
		sum{<cv,mat,(mod)> in AlocaModuloSet: replMod[cv,mat,mod] = max_repl_mod[Area,mod]} varAloca[cv,mat,mod] <=
			cnt_repl_max[Area,mod];
/*****************************************************************************************/

	/* Capacidade Módulo*/
	num capModulo{ModuloSet};
	con cap{mod in ModuloSet: fixaModulo[mod] = 0}:
		sum{<cv,mat,(mod)> in AlocaModuloSet} varAloca[cv,mat,mod]*replMod[cv,mat,mod] <= 
		sum{<a,can> in CanalSet: a=Area and modCanal[a,can]=mod}1;

/*	drop trocas;*/
	/* FO ==> minimizar desvio da distribuição ideal*/
	num objDemMod{mod in ModuloSet} = objModulo[Area,mod];
	num demTotModulo = sum{<cv,mat,a> in ProdutoAreaSet: a=Area} demanda[cv,mat];
	impvar ivCargaModulo{mod in ModuloSet} = sum{<cv,mat,(mod)> in AlocaModuloSet} 
		varAloca[cv,mat,mod]*demanda[cv,mat]/cardMod[cv,mat,Area]/demTotModulo;
	var varDesvio{ModuloSet};
	con desvioPlus{mod in ModuloSet}:
		varDesvio[mod] >= ivCargaModulo[mod]-objDemMod[mod];
	con desvioMinus{mod in ModuloSet}:
		varDesvio[mod] >= objDemMod[mod]-ivCargaModulo[mod];

	min obj=sum{mod in ModuloSet} varDesvio[mod];

	set<str> SolModulo{ProdutoAreaSet} init {};
	num demModulo{ModuloSet};

	/* produtos maiores vão para o fim do PBL*/
	set<str> AreaOrdemSet = setof{<a,mod> in ObjModuloSet: ordemModulo[a,mod]~=.}<a>;
/*	num objetivo;*/
/*	con DesvioMax: objetivo>=sum{mod in ModuloSet} varDesvio[mod];*/
	num desvio{ModuloSet};
	con DesvioMax{mod in ModuloSet}: varDesvio[mod] <= desvio[mod] + 0.01;
	drop DesvioMax;
	num ordemMax = max{mod in ModuloSet} ordemModulo[Area,mod]+1;
	max obj2 = sum{mod in ModuloSet, <cv,mat,(mod)> in AlocaModuloSet} 
		varAloca[cv,mat,mod]*volume[cv,mat]*(ordemMax - ordemModulo[Area,mod]);
/*	for{a in AreaSet: a in {'AFRAME','PAPER DISPENSER'}} do;*/

	for{a in AreaSet} do;
		Area = a;
		for{mod in ModuloSet} fixaModulo[mod]=fixaArea[a];
		solve with milp obj obj / maxtime=20;
		for{mod in ModuloSet} do;
			demModulo[mod] = sum{<cv,mat,(mod)> in AlocaModuloSet} varAloca[cv,mat,mod]*demanda[cv,mat]/cardMod[cv,mat,Area]/demTotModulo;
			desvio[mod] = varDesvio[mod];
		end;
		print 'Resultado Otimização 1 (Minimizar desvio do objetivo) ' _SOLUTION_STATUS_;
		print objDemMod percent8.2 demModulo percent8.2 varDesvio percent8.2;
		if a in AreaOrdemSet then do;
			/* Mantém desvio max*/
/*			objetivo = obj + 0.01;*/
			restore DesvioMax;
			solve with milp obj obj2 / primalin maxtime=60;
			drop DesvioMax;
			for{mod in ModuloSet} 
				demModulo[mod] = sum{<cv,mat,(mod)> in AlocaModuloSet} varAloca[cv,mat,mod]*demanda[cv,mat]/cardMod[cv,mat,Area]/demTotModulo;
			print 'Resultado Otimização 1 (Maximizar alocação para áreas com módulos ordenados) ' _SOLUTION_STATUS_;
			print objDemMod percent8.2 demModulo percent8.2 varDesvio percent8.2;
		end;
		for{<cv,mat,mod> in AlocaModuloSet} do;
			if varAloca[cv,mat,mod] > 0.1 then
				SolModulo[cv,mat,a] = SolModulo[cv,mat,a] union {mod};
			cardMod[cv,mat,a] = card(SolModulo[cv,mat,a]);
		end;
		print varTrocas;
	end;
	set<str,str,num,num> SolucaoSet = setof{<cv,mat,a> in ProdutoAreaSet, mod in SolModulo[cv,mat,a]} <a,mod,cv,mat>;
	create data WRSTEMP.BLS3_solucao_modulo from [AREA MODULO COD_VENDA MATERIAL]={<a,mod,cv,mat> in SolucaoSet}
		DESCRICAO[cv,mat] DEMANDA_PLIN=DEMANDA[cv,mat] DEMANDA=(DEMANDA[cv,mat]/cardMod[cv,mat,a]) 
		COMPRIMENTO[cv,mat] ALTURA[cv,mat] LARGURA[cv,mat] VOLUME[cv,mat] NCANAIS=replMod[cv,mat,mod];
quit;
%mend AlocaModulo;


%macro main;
	%global erros cod_cd data_ini data_fin produtividade prev_itens_volume max_troca_area
			exec_aloca_area exec_aloca_modulo exec_aloca_canal max_itens_aframe max_itens_aframe_maq alt_coluna_aframe regra_estoque
			preenche_mpick max_trocas_repl_aframe;

	PROC SQL NOPRINT;
		SELECT DATA_INICIAL, DATA_FINAL, PRODUTIVIDADE, ITENS_POR_VOLUME, MAX_TROCA_AREA, 
			   ALOCA_AREA, ALOCA_MODULO, ALOCA_CANAL, MAX_ITENS_AFRAME, MAX_ITENS_AFRAME_MAQ, ALT_COLUNA_AFRAME, REGRA_ESTOQUE,
			   PREENCHE_MASS_PICKING, MAX_TROCAS_REPL_AFRAME
			INTO :data_ini, :data_fin, :produtividade, :prev_itens_volume, :max_troca_area,
				:exec_aloca_area, :exec_aloca_modulo, :exec_aloca_canal, :max_itens_aframe, :max_itens_aframe_maq, :alt_coluna_aframe, 
				:regra_estoque, :preenche_mpick, :max_trocas_repl_aframe
		from WRSTEMP.BLE_PARAMETROS;
	QUIT;
	
	/* Pré-processamento + Log*/
	%PRP_Main
	/* Aloca ÁREA*/
	%if &erros = 0 and &exec_aloca_area = 1 %then %do;
		%AlocaArea(&cod_cd)
	%end;
	/* Aloca Módulo*/
	%if &erros = 0 and &exec_aloca_modulo = 1 %then %do;
		%AlocaModulo(&cod_cd)
	%end;
	/* Aloca Canal*/
	%if &erros = 0 and &exec_aloca_canal = 1 %then %do;
		%AlocaCanal(&cod_cd)
		%posProc(&cod_cd)
	%end;
%mend main;
%main
/* --- End of code for "BalanceamentoSeparacaoAframe_v1.02(remoto)". --- */