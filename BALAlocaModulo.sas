/* Aloca Módulo*/

%macro AlocaModulo(cd);
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
	/* Lê solução de alocação de área*/
	set<num,num,str> ProdutoAreaSet;
	num trocaArea{ProdutoAreaSet};
	read data WRSTEMP.BLS2_sol_mapa3(where=(area not in (&val_areas))) into ProdutoAreaSet=[COD_VENDA MATERIAL AREA] trocaArea;

	/*Lê REPLICACAO  de canais*/
	set<num,num,str> ReplSet;
	num repl{ReplSet};
	num cardMod{ReplSet};
	read data WRSTEMP.BLS1_REPLICACAO_&cd into ReplSet=[COD_VENDA MATERIAL AREA] repl cardMod; 

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
	Area = 'PBL AG';
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
	/* Capacidade Módulo*/
	num capModulo{ModuloSet};
	con cap{mod in ModuloSet: fixaModulo[mod] = 0}:
		sum{<cv,mat,(mod)> in AlocaModuloSet} varAloca[cv,mat,mod]*repl[cv,mat,Area] <= 
		sum{<a,can> in CanalSet: a=Area and modCanal[a,can]=mod}1;

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
	for{a in AreaSet} do;
		Area = a;
		for{mod in ModuloSet} fixaModulo[mod]=fixaArea[a];
		solve with milp obj obj / maxtime=20;
		for{mod in ModuloSet} do;
			demModulo[mod] = sum{<cv,mat,(mod)> in AlocaModuloSet} varAloca[cv,mat,mod]*demanda[cv,mat]/cardMod[cv,mat,Area]/demTotModulo;
			desvio[mod] = varDesvio[mod];
		end;
		print objDemMod percent8.2 demModulo percent8.2 varDesvio percent8.2;
		if a in AreaOrdemSet then do;
			/* Mantém desvio max*/
/*			objetivo = obj + 0.01;*/
			restore DesvioMax;
			solve with milp obj obj2 / primalin maxtime=60;
			drop DesvioMax;
			for{mod in ModuloSet} 
				demModulo[mod] = sum{<cv,mat,(mod)> in AlocaModuloSet} varAloca[cv,mat,mod]*demanda[cv,mat]/cardMod[cv,mat,Area]/demTotModulo;
			print objDemMod percent8.2 demModulo percent8.2 varDesvio percent8.2;
		end;
		for{<cv,mat,mod> in AlocaModuloSet} do;
			if varAloca[cv,mat,mod] > 0.1 then
				SolModulo[cv,mat,a] = SolModulo[cv,mat,a] union {mod};
			cardMod[cv,mat,a] = card(SolModulo[cv,mat,a]);
		end;
	end;
	set<str,str,num,num> SolucaoSet = setof{<cv,mat,a> in ProdutoAreaSet, mod in SolModulo[cv,mat,a]} <a,mod,cv,mat>;
	create data WRSTEMP.BLS3_solucao_modulo from [AREA MODULO COD_VENDA MATERIAL]={<a,mod,cv,mat> in SolucaoSet}
		DESCRICAO[cv,mat] DEMANDA_PLIN=DEMANDA[cv,mat] DEMANDA=(DEMANDA[cv,mat]/cardMod[cv,mat,a]) 
		COMPRIMENTO[cv,mat] ALTURA[cv,mat] LARGURA[cv,mat] VOLUME[cv,mat] NCANAIS=repl[cv,mat,a];
quit;
%mend AlocaModulo;
