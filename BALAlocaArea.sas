/* Classe ALA: Aloca��o otimizada de �rea*/

%macro logArea(cd);
/* Canais insuficientes*/
/* materiais fixos*/
	PROC SQL;
	   CREATE TABLE WORK.mat_fixo AS 
	   SELECT distinct
	            t1.MATERIAL
	      FROM WRSTEMP.BLS1_PRODUTO_AREA_&cod_cd. t1, WRSTEMP.BLS1_PRODUTOS_&cod_cd. t2, WRSTEMP.BLE_RESTRICAO_AREA_&cod_cd. t3
	      WHERE (t1.COD_VENDA = t2.COD_VENDA AND t1.MATERIAL = t2.MATERIAL AND t1.AREA = t3.AREA) AND t3.FIXA = 1;
	QUIT;
/* Tira materiais fixos de produtos*/
	PROC SQL;
	   CREATE TABLE WORK.MAT_ALOC AS 
	   SELECT t1.COD_VENDA, 
	          t1.MATERIAL, 
	          /* MIN_of_REPL */
	            (MIN(t3.repl * t3.cardMod)) AS MIN_of_REPL
	      FROM WRSTEMP.BLS1_PRODUTOS_&cod_cd. t1
	           LEFT JOIN WORK.MAT_FIXO t2 ON (t1.MATERIAL = t2.MATERIAL)
	           INNER JOIN WRSTEMP.BLS1_REPLICACAO_&cod_cd. t3 ON (t1.COD_VENDA = t3.COD_VENDA) AND (t1.MATERIAL = t3.MATERIAL)
	      WHERE t2.MATERIAL IS MISSING
	      GROUP BY t1.COD_VENDA,
	               t1.MATERIAL;
	QUIT;
/* canais necess�rios*/
	PROC SQL;
	   CREATE TABLE WORK.canal_nesc AS 
	   SELECT /* SUM_of_MIN_of_REPL */
	            (SUM(t1.MIN_of_REPL)) AS SUM_of_MIN_of_REPL
	      FROM WORK.MAT_ALOC t1;
	QUIT;
/* Canais dispon�veis*/
	PROC SQL;
	   CREATE TABLE WORK.canal_disp AS 
	   SELECT /* SUM_of_CAPACIDADE */
	            (SUM(t1.CAPACIDADE)) FORMAT=BEST12. AS SUM_of_CAPACIDADE
	      FROM WRSTEMP.BLE_RESTRICAO_AREA_&cod_cd. t1
	      WHERE t1.FIXA = 0;
	QUIT;
/* Display de erro*/

	PROC SQL;
		create table erro_area as select distinct
			'ERRO' AS TIPO,
			"Canais necess�rios = " || trim(put(t1.SUM_of_MIN_of_REPL,4.)) ||
			" Canais dispon�veis = " || trim(put(t2.SUM_of_CAPACIDADE,4.)) || "." AS DESCRICAO,
			'BLS1_PRODUTOS' AS TABELA1,
			'RESTRICAO_AREA' AS TABELA2
	      FROM WORK.canal_nesc t1, WORK.canal_disp t2 WHERE t1.SUM_of_MIN_of_REPL>t2.SUM_of_CAPACIDADE;
	QUIT;
	PROC SQL noprint;
		select count(*) into :erros from erro_area;
	QUIT;
%if &erros. > 0 %then %do;
	Title "ERRO Aloca �rea - Otimiza��o n�o realizada.";
	proc sql;
		select * from erro_area;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT * from erro_area;
	quit;
%end;
%mend logArea;
%macro initPaper(cd);
proc sql;
	create table mat_paper as select distinct
		cod_venda,
		material	
	from paper where cod_cd = &cd.;
quit;
%mend initPaper;
%macro AA_maxPaper;
	set<num,num> MatPaperSet;
	read data mat_paper into MatPaperSet=[COD_VENDA MATERIAL];
	set PaperSet = /'PAPER DISPENSER' 'PBL AAG' 'PBL AG' 'PBL MG' 'PBL BG'/;
	/* ZPRE s� no paper ou pbl*/
	con zpre_paper{<cv,mat,a> in AlocaAreaSet: <cv,mat> in MatPaperSet and a not in PaperSet}:
		varAloca[cv,mat,a] = 0;
	/* No paper s� zpre*/
	con paper_zpre{<cv,mat,a> in AlocaAreaSet: <cv,mat> not in MatPaperSet and a in {'PAPER DISPENSER'}}:
		varAloca[cv,mat,a] = 0;
	max obj_paper = sum{<cv,mat,a> in AlocaAreaSet: a in {'PAPER DISPENSER'}} varAloca[cv,mat,a]*demanda[cv,mat];
	if card({'PAPER DISPENSER'} inter AreaSet) = 1 then do;
		drop trocas;
		solve;
		for{<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a] > 0.1 and a='PAPER DISPENSER'}
			fix varAloca[cv,mat,a];
		restore trocas;
	end;
%mend AA_maxPaper;
%macro logTrocas(cd);
/* movimentos por descadastramento (descontinuados)*/
title 'N�mero de descadastramentos nescess�rios (para detalhe tabela BLS1_DESCONTINUADOS)';
proc sql;
	select count(*) into :aa_desc from wrstemp.bls1_descontinuados_&cd;
quit;
/* movimentos por cadastramento de novos skus (lan�amentos)*/
title 'N�mero de cadastramentos nescess�rios (para detalhe tabela BLS1_LANCAMENTOS)';
proc sql;
	select count(*) into :aa_novos from wrstemp.bls1_lancamentos_&cd;
quit;
/* movimentos por abertura/fechamento de canais*/
/* N�mero de canais para cada material/�rea no mapa atual*/
PROC SQL;
   CREATE TABLE WORK.mov_abre_canal AS 
   SELECT t1.AREA, 
          t1.MATERIAL, 
          /* COUNT_of_CANAL */
            (COUNT(t1.CANAL)) AS COUNT_of_CANAL
      FROM WRSTEMP.BLE_MAPA_&cd t1, WRSTEMP.BLE_ESTRUTURA_CD_&cd t2
      WHERE (t1.AREA = t2.AREA AND t1.CANAL = t2.CANAL) AND t2.ESTACAO = 1
      GROUP BY t1.AREA,
               t1.MATERIAL;
QUIT;
PROC SQL;
   CREATE TABLE WORK.MOV_ABRE_CANAL_1 AS 
   SELECT t1.AREA, 
          t1.MATERIAL, 
          t1.COUNT_of_CANAL, 
          /* abre_count */
            (t2.repl * t2.cardMod) AS abre_count, 
          /* canal_dif */
            (abs((t2.repl * t2.cardMod) - t1.COUNT_of_CANAL)) AS canal_dif
      FROM WORK.MOV_ABRE_CANAL t1, WRSTEMP.BLS1_REPLICACAO_&cd t2
      WHERE (t1.MATERIAL = t2.MATERIAL AND t1.AREA = t2.AREA);
QUIT;
title 'N�mero de movimenta��es nescess�rias para abertura e fechamento de canais';
proc sql;
	select area, sum(canal_dif) as movimentacoes from WORK.MOV_ABRE_CANAL_1 group by area;
quit;
%mend logTrocas;
%macro ajustaRepl;
/* Seleciona para o AFRAME quais s�o as movimenta��es por replica��o escolhidas*/
/*Materiais AFRAME*/
PROC SQL;
   CREATE TABLE WORK.RESTR_REPL_00 AS 
   SELECT distinct 
		t1.AREA, 
        t1.MATERIAL
      FROM WRSTEMP.BLS2_SOLUCAO_AREA t1
      WHERE t1.AREA in ('AFRAME','AFRAME MAQ');
QUIT;
/* Calcula n�mero atual de canais do material na linha*/
PROC SQL;
	CREATE TABLE WORK.RESTR_REPL_01A AS 
		SELECT t1.AREA, 
			t1.MATERIAL,
			t3.MODULO,	 
			(COUNT(t3.CANAL)) AS nCanAtual
		FROM RESTR_REPL_00 t1
			LEFT JOIN WRSTEMP.BLE_MAPA_&cd. t2 ON (t1.MATERIAL=t2.MATERIAL AND t1.AREA=t2.AREA)
			LEFT JOIN WRSTEMP.BLE_ESTRUTURA_CD_&cd. t3 ON (t1.AREA = t3.AREA AND t2.CANAL = t3.CANAL)
		WHERE t3.ESTACAO = 1
		GROUP BY t1.AREA,t1.MATERIAL,t3.MODULO
		ORDER BY t1.MATERIAL;
QUIT;

PROC SQL;
   CREATE TABLE WORK.RESTR_REPL_01B AS 
   SELECT t1.AREA, 
          t1.MATERIAL, 
          /* COUNT_of_MODULO */
            (COUNT(t1.MODULO)) AS cardModAtual, 
          /* MAX_of_nCanAtual */
            (MAX(t1.nCanAtual)) AS replAtual
      FROM WORK.RESTR_REPL_01A t1
      GROUP BY t1.AREA,
               t1.MATERIAL;
QUIT;

/* Calcula n�mero de movimenta��es por replica��o*/
PROC SQL;
	CREATE TABLE WORK.RESTR_REPL_02 AS 
		SELECT t1.COD_VENDA, 
			t1.MATERIAL, 
			t1.AREA, 
			t1.descricao, 
			t1.demanda, 
			t1.comprimento, 
			t1.altura, 
			t1.largura, 
			t1.volume, 
			t1.trocaArea, 
			(COALESCE(t2.cardModAtual*t2.replAtual,0)) AS COUNT_OF_CANAL,
			t2.cardModAtual,
			t2.replAtual,
			t3.repl, 
			t3.cardMod,
			(t3.repl*t3.cardMod) - COALESCE(t2.cardModAtual*t2.replAtual,0) AS NMOV
		FROM WRSTEMP.BLS2_SOL_MAPA3 t1
			LEFT JOIN WORK.RESTR_REPL_01B t2 ON (t1.AREA = t2.AREA) AND (t1.MATERIAL = t2.MATERIAL)
			INNER JOIN WRSTEMP.BLS1_REPLICACAO_&cd. t3 ON (t1.MATERIAL = t3.MATERIAL) AND (t1.AREA = t3.AREA)
		WHERE t1.AREA IN('AFRAME','AFRAME MAQ')
		ORDER BY (CALCULATED NMOV) DESC;
QUIT;
/* Limita as movimenta��es*/
DATA RESTR_REPL_03;
	SET RESTR_REPL_02;
	RETAIN ACC_MOV 0;

	fixa_repl = 0;
	if ACC_MOV + abs(NMOV) < &max_trocas_repl_aframe. and NMOV ~= 0 then ACC_MOV + abs(NMOV);
	/* A partir deste ponto modifica replica��o*/
	else do;
		if trocaArea = 1 or COUNT_OF_CANAL=0 then do;
			repl = 1;
			cardMod = 1;
		end;
		else do;
			cardMod = cardModAtual;
			repl = replAtual;
			fixa_repl = 1;
		end;
	end;
RUN;
/* Atualiza a tabela de replica��es. Altera algumas replica��es e acrescenta o campo fixa replica��o que impede replica��es*/
PROC SQL;
   CREATE TABLE WORK.BLS1_REPLICACAO AS 
   SELECT t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.AREA, 
          t1.reposicao,
		  coalesce(t2.fixa_repl,0) as fixa_repl, 
          /* repl */
            (coalesce(t2.repl,t1.repl)) AS repl, 
          /* cardMod */
            (coalesce(t2.cardMod,t1.cardMod)) AS cardMod
      FROM WRSTEMP.BLS1_REPLICACAO_&cd. t1
           LEFT JOIN WORK.RESTR_REPL_03 t2 ON (t1.MATERIAL = t2.MATERIAL) AND (t1.AREA = t2.AREA)
      ORDER BY t1.AREA,
               cardMod DESC,
               repl DESC;
QUIT;
data WRSTEMP.BLS1_REPLICACAO_&cd.;
	set BLS1_REPLICACAO;
run;
%mend ajustaRepl;

%macro AlocaArea(cd);
%logArea(&cd.)
%initPaper(&cd.)
%logTrocas(&cd.)
%if &erros. = 0 %then %do;
	proc optmodel printlevel=0;
		/*L� DESCONTINUADOS_&cd*/
		set<str,str,num,num> XDescSet;
		read data WRSTEMP.BLS1_DESCONTINUADOS_&cd into XDescSet=[AREA CANAL COD_VENDA MATERIAL]; 
		set DescSet = setof{<a,can,cv,mat> in XDescSet} <cv>;
		/*L� LANCAMENTOS_&cd*/
		set<num,num> LancaSet;
		read data WRSTEMP.BLS1_LANCAMENTOS_&cd into LancaSet=[COD_VENDA MATERIAL]; 
		/*L� PRODUTOS_&cd*/
		set<num,num> ProdutoSet;
		str descricao{ProdutoSet};
		str tipo{ProdutoSet};
		num demanda{ProdutoSet};
		num demanda100{ProdutoSet};
		num comprimento{ProdutoSet};
		num largura{ProdutoSet};
		num altura{ProdutoSet};
		num volume{ProdutoSet};
		read data WRSTEMP.BLS1_PRODUTOS_&cd into ProdutoSet=[COD_VENDA MATERIAL] demanda=DEMANDA_PERC demanda100=DEMANDA_PERC_100
			descricao comprimento largura altura volume tipo=TMat;
		/*L� PRODUTOS_AREA_&cd*/
		set<str,str,num,num> XProdutoAreaSet;
		num fixa{XProdutoAreaSet};
		read data WRSTEMP.BLS1_PRODUTO_AREA_&cd into XProdutoAreaSet=[AREA CANAL COD_VENDA MATERIAL];
		set<num,num,str> ProdutoAreaSet = setof{<a,can,cv,mat> in XProdutoAreaSet: cv not in DescSet}<cv,mat,a>;
		num fixaPrd{ProdutoAreaSet} init 0;
		/*L� INCOMPATIBILIDADES*/
	/*	set<str,num> IncompSet;*/
	/*	read data WRSTEMP.BLS1_INCOMPATIBILIDADE_&cd into IncompSet=[AREA_INCOMPATIVEL COD_VENDA]; */
		set XIncompSet;
		set<str> IncompColSet = / 'ROB�-PICK' 'AFRAME' 'AFRAME MAQ' /;
		str incompat{XIncompSet,IncompColSet};
		read data WRSTEMP.BLE_INCOMPATIBILIDADE_&cd into XIncompSet=[COD_VENDA]
				{a in IncompColSet} <incompat[cod_venda,a]=col(a)>; 
		set<num,str> IncompSet = setof{cv in XIncompSet, a in IncompColSet: incompat[cv,a]~=''} <cv,a>;

		/*L� RESTRICAO_AREA*/
		set<str> AreaSet;
		num capArea{AreaSet};
		num replArea{AreaSet};
		num fixaArea{AreaSet};
		read data WRSTEMP.BLE_RESTRICAO_AREA_&cd into AreaSet=[AREA]
			capArea=CAPACIDADE replArea=REPLICACAO fixaArea=fixa; 
		/*L� ESTRUTURA_CD*/
		set<str> CanalSet;
		str areaCanal{CanalSet};
		str modCanal{CanalSet};
		read data WRSTEMP.BLE_ESTRUTURA_CD_&cd(where=(STATUS~='INDISPON�VEL' AND ESTACAO=1)) into CanalSet=[CANAL]
			areaCanal=AREA modCanal=MODULO; 
		/*L� REPLICACAO  de canais*/
		set<num,num,str> ReplSet;
		num repl{ReplSet};
		num cardMod{ReplSet};
		read data WRSTEMP.BLS1_REPLICACAO_&cd into ReplSet=[COD_VENDA MATERIAL AREA] repl cardMod; 
		
		/************ OBJETIVOS ==> para cada �rea em termos de % demanda ******************/
		/* M�ximo de 11 itens por volume no AFRAME ==> transformar em demanda % m�xima*/
		/* Usando o valor fixo de 32.26 itens/volume (previs�o itens por volume do dia 13 ao 26/11)*/

	/*	print nModArea;*/
		/****************** Prepara modelo ******************/
		set<num,num,str> AlocaAreaSet = setof{<cv,mat> in ProdutoSet, a in AreaSet}<cv,mat,a>;
		var varAloca{AlocaAreaSet} binary;
		/* Fecha produtos na linha*/
		con naLinha{<cv,mat,a> in AlocaAreaSet: <cv,mat,a> in ProdutoAreaSet}:
			varAloca[cv,mat,a] = 1;
		drop naLinha;
		/* Uma �rea para cada produto (vai dar problema!)*/
		/* Achar produtos em mais de uma �rea*/
		set<str> areasProd{<cv,mat> in ProdutoSet} = slice(<cv,mat,*>,ProdutoAreaSet);
		num cardProd{<cv,mat> in ProdutoSet} = card(areasProd[cv,mat]);
	/*	set ProdUmaAreaSet = setof{cv in ProdutoSet: cardProd[cv] <= 1}<cv>;*/
		con umaArea{<cv,mat> in ProdutoSet}:
			sum{a in AreaSet}varAloca[cv,mat,a] = 1;
			
		/* Area intereira est� fixa*/
		set areaFixaSet = setof{<cv,mat,a> in ProdutoAreaSet: <cv,mat,a> in AlocaAreaSet and fixaArea[a] = 1} <cv,mat,a>;
		con fixarArea1{<cv,mat,a> in areaFixaSet}:
			varAloca[cv,mat,a] = 1;
		con fixarArea2{<cv,mat,a> in AlocaAreaSet: fixaArea[a] = 1 and <cv,mat,a> not in areaFixaSet}:
			varAloca[cv,mat,a] = 0;

		/* Capacidade */
		con cap{a in AreaSet: fixaArea[a]=0}:
			sum{<cv,mat> in ProdutoSet} varAloca[cv,mat,a]*cardMod[cv,mat,a]*repl[cv,mat,a] <= capArea[a];
		/* N�o aloca na �rea que n�o possui m�dulos suficientes*/
		num nModArea{a in AreaSet} = card(setof{can in CanalSet: AreaCanal[can]=a}<modCanal[can]>);
		con ModMax{a in AreaSet, <cv,mat> in ProdutoSet: fixaArea[a]=0 and cardMod[cv,mat,a]>nModArea[a]}:
			varAloca[cv,mat,a] = 0;
		/* Incompatibilidade */
		con incomp{<cv,mat,a> in AlocaAreaSet: <cv,a> in IncompSet and <cv,mat,a> not in areaFixaSet}:
			varAloca[cv,mat,a] = 0;
	/*	con incomp{<cv,mat,a> in AlocaAreaSet: <cv,a> in IncompSet and <cv,mat,a> not in prdFixaSet}:*/
	/*		varAloca[cv,mat,a] = 0;*/
		/* N�mero de trocas*/
		num trocaProdMult = sum{<cv,mat> in ProdutoSet: cardProd[cv,mat] > 1} (cardProd[cv,mat]-1);
		var varTrocas >= 0 <= &max_troca_area + trocaProdMult;
/*		var varTrocas >= 0 <= &max_troca_area;*/
		con trocas:
			varTrocas = sum{<cv,mat,a> in ProdutoAreaSet: <cv,mat> in ProdutoSet and <cv,a> not in IncompSet} (1-varAloca[cv,mat,a]); 

		/* Restri��o PAPER*/
		set<num,num> MatPaperSet;
		read data mat_paper into MatPaperSet=[COD_VENDA MATERIAL];
		set PaperSet = /'PAPER DISPENSER' 'PBL AAG' 'PBL AG' 'PBL MG' 'PBL BG'/;
		/* ZPRE s� no paper ou pbl*/
		con zpre_paper{<cv,mat,a> in AlocaAreaSet: <cv,mat> in MatPaperSet and a not in PaperSet}:
			varAloca[cv,mat,a] = 0;
		/* No paper s� zpre*/
		con paper_zpre{<cv,mat,a> in AlocaAreaSet: <cv,mat> not in MatPaperSet and a in {'PAPER DISPENSER'}}:
			varAloca[cv,mat,a] = 0;

		/* Objetivo para �reas*/
		num objDemArea{AreaSet} init 0;
		num demanda_total = sum{<cv,mat> in ProdutoSet} demanda[cv,mat];
		put demanda_total=;
		set<str> objSet;
		num objPerc{objSet};
		read data WRSTEMP.BLE_OBJ_AREA_&cd. into objSet=[AREA] objPerc=objetivo;
		
		/* Divide a demanda de acordo com a demanada total*/
		for{a in AreaSet}
			objDemArea[a] =objPerc[a]*demanda_total;

		/* FO ==> minimizar desvio da distribui��o ideal*/
		impvar ivCargaArea{a in AreaSet} = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda[cv,mat];

		/* Paper e AFRAME n�o podem ultrapassar o objetivo*/
		con maxObj{a in AreaSet: a in {'PAPER DISPENSER','AFRAME','AFRAME MAQ'}}: 
			ivCargaArea[a] <= objPerc[a];
		
		max obj = sum{<cv,mat,a> in AlocaAreaSet: a in {'PAPER DISPENSER','AFRAME','AFRAME MAQ'}} ivCargaArea[a];
		solve;
		print 'Resultado Otimiza��o 1 (Maximizar AFRAME e PAPER) ' _SOLUTION_STATUS_;
		num objAreaIni{objSet};
		for{a in AreaSet: a in {'PAPER DISPENSER','AFRAME','AFRAME MAQ'}} do;
			objAreaIni[a] = ivCargaArea[a];
		end;

		con fixaObjMin{a in AreaSet: a in {'PAPER DISPENSER','AFRAME','AFRAME MAQ'}}:
			ivCargaArea[a] >= objAreaIni[a]*0.9;

		num demRestante = demanda_total - sum{a in {'PAPER DISPENSER','AFRAME','AFRAME MAQ'}: a in AreaSet} objDemArea[a];
		for{a in AreaSet: a not in {'PAPER DISPENSER','AFRAME','AFRAME MAQ'}}
			objDemArea[a] = objPerc[a]*demRestante;

		impvar ivCarga{a in AreaSet} = ivCargaArea[a]/demanda_total;
		impvar ivDesvio{a in AreaSet} = ivCarga[a]-objDemArea[a];
		num pesoObj{AreaSet} init 1;
		for{a in AreaSet} do;
			if a in {'SCS','Rob�-Pick'} then
				pesoObj[a] = 3;
			if a = 'PBL BG' then 
				pesoObj[a] = 2;
		end;
		var varDesvio{AreaSet};
		con red{a in AreaSet}:
			varDesvio[a] >= 0;
		con desvioPlus{a in AreaSet}:
			varDesvio[a] >= (ivCargaArea[a]-objDemArea[a])*pesoObj[a];
		con desvioMinus{a in AreaSet}:
			varDesvio[a] >= (objDemArea[a]-ivCargaArea[a])*pesoObj[a];
		restore trocas;
		min obj2=sum{a in AreaSet} varDesvio[a];

		solve with milp/ presolver=none primalin maxtime=25;
		print 'Resultado Otimiza��o 2 (Minimizar desvio do objetivo) ' _SOLUTION_STATUS_;

		num demArea{AreaSet};
		for{a in AreaSet} 
			demArea[a] = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda100[cv,mat];
		Title "Solu��o Inicial";
		print objPerc percent8.2 objDemArea percent8.2 ivCarga percent8.2 ivDesvio percent8.2;
		set<str,str,num,num> TrocaSet init {};
		for{<cv,mat> in ProdutoSet, org in AreaSet, dest in AreaSet: <cv,mat> not in LancaSet and <cv,mat,org> in ProdutoAreaSet} do;
			if varAloca[cv,mat,org]=0 and varAloca[cv,mat,dest]>0.1 then
				TrocaSet = TrocaSet union {<org,dest,cv,mat>};
		end;
		create data WRSTEMP.BLS2_sol_lanca from [COD_VENDA MATERIAL AREA]={<cv,mat,a> in AlocaAreaSet: <cv,mat> in LancaSet and varAloca[cv,mat,a]>0.1}; 
		create data WRSTEMP.BLS2_sol_trocas from [AREA_ORG AREA_DEST COD_VENDA MATERIAL]={<org,dest,cv,mat> in TrocaSet: cardprod[cv,mat]<=1} 
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat];
		create data WRSTEMP.BLS2_sol_uma_area from [AREA_ORG AREA_DEST COD_VENDA MATERIAL]={<org,dest,cv,mat> in TrocaSet: cardprod[cv,mat]>1} 
			cardprod[cv,mat] descricao[cv,mat] demanda[cv,mat];
		create data WRSTEMP.BLS2_sol_mapa1 from [COD_VENDA AREA MATERIAL]={<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat] volume[cv,mat];
		create data WRSTEMP.BLS2_sol_dem1 from [AREA]={a in AreaSet} demArea; 

		set<num,num,str> Sol2Set init {};
		for{<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1} do;
			Sol2Set = Sol2Set union {<cv,mat,a>};
		end;
		/* Melhorar a solu��o do SCS*/
		/* Permite desvios + 0.5%*/
		num desvio1{AreaSet};
		for{a in AreaSet} desvio1[a] = varDesvio[a];
		con desvioSCS{a in AreaSet}:
			varDesvio[a] <= desvio1[a] + 0.005;
		/* Aumenta n�mero de trocas*/
	/*	varTrocas.ub = varTrocas.ub + 10;*/
		/* Objetivo maximizar produtos no SCS*/
		max obj3 = sum{<cv,mat,a> in AlocaAreaSet: a = 'SCS'} varAloca[cv,mat,a];
		solve with milp/ primalin maxtime=60;
		print 'Resultado Otimiza��o 3 (Melhorar aloca��o do SCS) ' _SOLUTION_STATUS_;

		set<str,str,num,num> TrocaSetSCS init {};
		for{<cv,mat> in ProdutoSet, org in AreaSet, dest in AreaSet: <cv,mat,org> in Sol2Set} do;
			if varAloca[cv,mat,org]=0 and varAloca[cv,mat,dest]>0.1 then
				TrocaSetSCS = TrocaSetSCS union {<org,dest,cv,mat>};
		end;
		for{a in AreaSet} 
			demArea[a] = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda100[cv,mat];
		Title "Melhoria SCS";
		print objPerc percent8.2 objDemArea percent8.2 ivCarga percent8.2 ivDesvio percent8.2;
		create data WRSTEMP.BLS2_sol_trocas2 from [AREA_ORG AREA_DEST COD_VENDA MATERIAL]={<org,dest,cv,mat> in TrocaSetSCS}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat];
		create data WRSTEMP.BLS2_sol_mapa2 from [COD_VENDA MATERIAL AREA]={<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat] volume[cv,mat];

		set<num,num,str> Sol3Set init {};
		for{<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1} do;
			Sol3Set = Sol3Set union {<cv,mat,a>};
		end;
		/* Melhorar a solu��o do MASS PICKING*/
		/* Guarda a solu��o para o SCS*/
		set<num,num> SCSSet init {};
		for{<cv,mat,a> in AlocaAreaSet: a = 'SCS'} do;
			if varAloca[cv,mat,a] = 1 then
				SCSSet = SCSSet union {<cv,mat>};
		end;
		con scsOK{<cv,mat> in SCSSet}:
			varAloca[cv,mat,'SCS'] = 1;
		max obj4 = sum{<cv,mat,a> in AlocaAreaSet: a = 'MASS PICKING'} varAloca[cv,mat,a]*volume[cv,mat];
		%if &preenche_mpick. = 1 %then %do;
			solve with milp/ primalin maxtime=60;
			print 'Resultado Otimiza��o 4 (Melhorar aloca��o do Mass Picking) ' _SOLUTION_STATUS_;
			Title "Melhoria Mass Picking";
			print objPerc percent8.2 objDemArea percent8.2 ivCarga percent8.2 ivDesvio percent8.2;
		%end;
		set<str,str,num,num> TrocaSetMass init {};
		for{<cv,mat> in ProdutoSet, org in AreaSet, dest in AreaSet: <cv,mat,org> in Sol3Set} do;
			if varAloca[cv,mat,org]=0 and varAloca[cv,mat,dest]>0.1 then
				TrocaSetMass = TrocaSetMass union {<org,dest,cv,mat>};
		end;
		for{a in AreaSet} 
			demArea[a] = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda100[cv,mat];

		num trocaArea{ProdutoSet} init 1;
		for{<cv,mat> in ProdutoSet, org in AreaSet: <cv,mat,org> in ProdutoAreaSet} do;
			if varAloca[cv,mat,org] >= 0.1 then
				trocaArea[cv,mat] = 0;
		end;
		for{<cv,mat> in LancaSet} do;
				trocaArea[cv,mat] = 0;
		end;

		create data WRSTEMP.BLS2_sol_trocas3 from [AREA_ORG AREA_DEST COD_VENDA MATERIAL]={<org,dest,cv,mat> in TrocaSetMass}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat];
		create data WRSTEMP.BLS2_sol_mapa3 from [COD_VENDA MATERIAL AREA]={<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat] volume[cv,mat] trocaArea[cv,mat];

		num cntArea{AreaSet};
		for{a in AreaSet}
			cntArea[a] = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a];
		Title;
		print cntArea capArea;

	quit;
	DATA WRSTEMP.BLS2_SOLUCAO_AREA;
		SET WRSTEMP.BLS2_sol_mapa3;
	RUN;
	/*Ajusta replic��es no AFRAME para respeitar o par�metro max_trocas_repl_AFRAME*/
	%ajustaRepl
%end;
%mend AlocaArea;
