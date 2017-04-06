/* Aloca Módulo*/
%macro calc_max_repl;
PROC SQL;
   CREATE TABLE WORK.max_repl_00 AS 
   SELECT t1.COD_CD, 
          t1.AREA, 
          t1.MODULO, 
          t1.CANAL, 
          t1.STATUS, 
          t1.X, 
          t1.Y
      FROM WRSTEMP.BLE_ESTRUTURA_CD_2700 t1
      WHERE t1.ESTACAO = 1
      ORDER BY t1.AREA,
               t1.MODULO,
               t1.Y,
               t1.X;
QUIT;
data max_repl_01;
	set max_repl_00;
	by AREA MODULO Y X;
	retain max_repl_mod nrepl;

	if first.modulo then do;
		max_repl_mod = 0;
		nrepl = 0;
	end;
	if status = '' then do;
		nrepl + 1;
		if nrepl > max_repl_mod then max_repl_mod = nrepl;
	end;
	else nrepl = 0;
	if last.modulo then output;

	keep area modulo max_repl_mod;
run;
PROC SQL;
   CREATE TABLE WORK.MAX_REPL_02 AS 
   SELECT t2.COD_CD, 
          t2.AREA, 
          t2.MODULO, 
          t2.CANAL, 
          t2.STATUS, 
          t2.X, 
          t2.Y, 
          t1.max_repl_mod
      FROM WORK.MAX_REPL_01 t1, WORK.MAX_REPL_00 t2
      WHERE (t1.AREA = t2.AREA AND t1.MODULO = t2.MODULO)
      ORDER BY t2.AREA,
               t2.MODULO,
               t2.Y,
               t2.X;
QUIT;
data max_repl;
	set max_repl_02;
	by AREA MODULO Y X;
	retain nrepl cnt_repl_max;

	if first.modulo then do;
		max_repl_mod = 0;
		nrepl = 0;
		cnt_repl_max = 0;
	end;
	if status = '' then do;
		nrepl + 1;
		if nrepl = max_repl_mod then cnt_repl_max + 1;
	end;
	else nrepl = 0;
	if last.modulo then output;

	keep area modulo max_repl_mod cnt_repl_max;
run;
%mend calc_max_repl;
%macro AlocaModulo(cd);
%calc_max_repl
proc optmodel printlevel=0;
	%let val_areas = 'SCS' 'Robô-Pick' 'MASS PICKING';
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
