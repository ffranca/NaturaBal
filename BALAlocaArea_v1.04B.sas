/* Classe ALA: Alocação otimizada de área*/

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
	          /* MAX_of_REPL */
	            (MAX(t3.repl * t3.cardMod)) AS MAX_of_REPL
	      FROM WRSTEMP.BLS1_PRODUTOS_&cod_cd. t1
	           LEFT JOIN WORK.MAT_FIXO t2 ON (t1.MATERIAL = t2.MATERIAL)
	           INNER JOIN WRSTEMP.BLS1_REPLICACAO_&cod_cd. t3 ON (t1.COD_VENDA = t3.COD_VENDA) AND (t1.MATERIAL = t3.MATERIAL)
	      WHERE t2.MATERIAL IS MISSING
	      GROUP BY t1.COD_VENDA,
	               t1.MATERIAL;
	QUIT;
/* canais necessários*/
	PROC SQL;
	   CREATE TABLE WORK.canal_nesc AS 
	   SELECT /* SUM_of_MAX_of_REPL */
	            (SUM(t1.MAX_of_REPL)) AS SUM_of_MAX_of_REPL
	      FROM WORK.MAT_ALOC t1;
	QUIT;
/* Canais disponíveis*/
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
			"Canais necessários = " || trim(put(t1.SUM_of_MAX_of_REPL,4.)) ||
			" Canais disponíveis = " || trim(put(t2.SUM_of_CAPACIDADE,4.)) || "." AS DESCRICAO,
			'BLS1_PRODUTOS' AS TABELA1,
			'RESTRICAO_AREA' AS TABELA2
	      FROM WORK.canal_nesc t1, WORK.canal_disp t2 WHERE t1.SUM_of_MAX_of_REPL>t2.SUM_of_CAPACIDADE;
	QUIT;
	PROC SQL noprint;
		select count(*) into :erros from erro_area;
	QUIT;
%if &erros. > 0 %then %do;
	Title "ERRO Aloca Área - Otimização não realizada.";
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
	/* ZPRE só no paper ou pbl*/
	con zpre_paper{<cv,mat,a> in AlocaAreaSet: <cv,mat> in MatPaperSet and a not in PaperSet}:
		varAloca[cv,mat,a] = 0;
	/* No paper só zpre*/
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

%macro AlocaArea(cd);
%logArea(&cd.)
%initPaper(&cd.)
%if &erros. = 0 %then %do;
	proc optmodel printlevel=0;
		/*Lê DESCONTINUADOS_&cd*/
		set<str,str,num,num> XDescSet;
		read data WRSTEMP.BLS1_DESCONTINUADOS_&cd into XDescSet=[AREA CANAL COD_VENDA MATERIAL]; 
		set DescSet = setof{<a,can,cv,mat> in XDescSet} <cv>;
		/*Lê LANCAMENTOS_&cd*/
		set<num,num> LancaSet;
		read data WRSTEMP.BLS1_LANCAMENTOS_&cd into LancaSet=[COD_VENDA MATERIAL]; 
		/*Lê PRODUTOS_&cd*/
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
		/*Lê PRODUTOS_AREA_&cd*/
		set<str,str,num,num> XProdutoAreaSet;
		num fixa{XProdutoAreaSet};
		read data WRSTEMP.BLS1_PRODUTO_AREA_&cd into XProdutoAreaSet=[AREA CANAL COD_VENDA MATERIAL];
		set<num,num,str> ProdutoAreaSet = setof{<a,can,cv,mat> in XProdutoAreaSet: cv not in DescSet}<cv,mat,a>;
		num fixaPrd{ProdutoAreaSet} init 0;
		/*Lê INCOMPATIBILIDADES*/
	/*	set<str,num> IncompSet;*/
	/*	read data WRSTEMP.BLS1_INCOMPATIBILIDADE_&cd into IncompSet=[AREA_INCOMPATIVEL COD_VENDA]; */
		set XIncompSet;
		set<str> IncompColSet = / 'Robô-Pick' 'AFRAME' 'AFRAME MAQ' 'PFL'/;
		str incompat{XIncompSet,IncompColSet};
		read data WRSTEMP.BLE_INCOMPATIBILIDADE_&cd into XIncompSet=[COD_VENDA]
				{a in IncompColSet} <incompat[cod_venda,a]=col(a)>; 
		set<num,str> IncompSet = setof{cv in XIncompSet, a in IncompColSet: incompat[cv,a]~=''} <cv,a>;

		/*Lê RESTRICAO_AREA*/
		set<str> AreaSet;
		num capArea{AreaSet};
		num replArea{AreaSet};
		num fixaArea{AreaSet};
		read data WRSTEMP.BLE_RESTRICAO_AREA_&cd into AreaSet=[AREA]
			capArea=CAPACIDADE replArea=REPLICACAO fixaArea=fixa; 
		/*Lê ESTRUTURA_CD*/
		set<str> CanalSet;
		str areaCanal{CanalSet};
		str modCanal{CanalSet};
		read data WRSTEMP.BLE_ESTRUTURA_CD_&cd into CanalSet=[CANAL]
			areaCanal=AREA modCanal=MODULO; 
		/*Lê REPLICACAO  de canais*/
		set<num,num,str> ReplSet;
		num repl{ReplSet};
		num cardMod{ReplSet};
		read data WRSTEMP.BLS1_REPLICACAO_&cd into ReplSet=[COD_VENDA MATERIAL AREA] repl cardMod; 
		
		/************ OBJETIVOS ==> para cada área em termos de % demanda ******************/
		/* Máximo de 11 itens por volume no AFRAME ==> transformar em demanda % máxima*/
		/* Usando o valor fixo de 32.26 itens/volume (previsão itens por volume do dia 13 ao 26/11)*/

	/*	print nModArea;*/
		/****************** Prepara modelo ******************/
		set<num,num,str> AlocaAreaSet = setof{<cv,mat> in ProdutoSet, a in AreaSet}<cv,mat,a>;
		var varAloca{AlocaAreaSet} binary;
		/* Fecha produtos na linha*/
		con naLinha{<cv,mat,a> in AlocaAreaSet: <cv,mat,a> in ProdutoAreaSet}:
			varAloca[cv,mat,a] = 1;
		drop naLinha;
		/* Uma área para cada produto (vai dar problema!)*/
		/* Achar produtos em mais de uma área*/
		set<str> areasProd{<cv,mat> in ProdutoSet} = slice(<cv,mat,*>,ProdutoAreaSet);
		num cardProd{<cv,mat> in ProdutoSet} = card(areasProd[cv,mat]);
	/*	set ProdUmaAreaSet = setof{cv in ProdutoSet: cardProd[cv] <= 1}<cv>;*/
		con umaArea{<cv,mat> in ProdutoSet}:
			sum{a in AreaSet}varAloca[cv,mat,a] = 1;
			
		/* Area intereira está fixa*/
		set areaFixaSet = setof{<cv,mat,a> in ProdutoAreaSet: <cv,mat,a> in AlocaAreaSet and fixaArea[a] = 1} <cv,mat,a>;
		con fixarArea1{<cv,mat,a> in areaFixaSet}:
			varAloca[cv,mat,a] = 1;
		con fixarArea2{<cv,mat,a> in AlocaAreaSet: fixaArea[a] = 1 and <cv,mat,a> not in areaFixaSet}:
			varAloca[cv,mat,a] = 0;

		/* Capacidade */
		con cap{a in AreaSet: fixaArea[a]=0}:
			sum{<cv,mat> in ProdutoSet} varAloca[cv,mat,a]*cardMod[cv,mat,a]*repl[cv,mat,a] <= capArea[a];
		/* Incompatibilidade */
		con incomp{<cv,mat,a> in AlocaAreaSet: <cv,a> in IncompSet and <cv,mat,a> not in areaFixaSet}:
			varAloca[cv,mat,a] = 0;
	/*	con incomp{<cv,mat,a> in AlocaAreaSet: <cv,a> in IncompSet and <cv,mat,a> not in prdFixaSet}:*/
	/*		varAloca[cv,mat,a] = 0;*/
		/* Número de trocas*/
		num trocaProdMult = sum{<cv,mat> in ProdutoSet: cardProd[cv,mat] > 1} (cardProd[cv,mat]-1);
		var varTrocas >= 0 <= &max_troca_area + trocaProdMult;
		con trocas:
			varTrocas = sum{<cv,mat,a> in ProdutoAreaSet: <cv,mat> in ProdutoSet and <cv,a> not in IncompSet} (1-varAloca[cv,mat,a]); 
		/* Fazer ocupação máxima PAPER*/
		%AA_maxPAPER
		/* Fazer ocupação máxima do AFRAME e AFRAME MAQ*/
		drop trocas;
		max obj1 = sum{<cv,mat,a> in AlocaAreaSet: a in {'AFRAME','AFRAME MAQ'}} varAloca[cv,mat,a];
		solve;

		num objDemArea{AreaSet} init 0;
		num prob;
		if card({'AFRAME'} inter AreaSet) = 1 then do;
			for{i in 150..500} do;
				prob = CDF('BINOMIAL',&max_itens_aframe.,i/1000,&prev_itens_volume.);
				objDemArea['AFRAME'] = (i-1)/1000*replArea['AFRAME'];
				if prob < .99 then stop;
			end;
			objDemArea['AFRAME'] = sum{<cv,mat,'AFRAME'> in AlocaAreaSet} varAloca[cv,mat,'AFRAME']*demanda[cv,mat];
		end;
		if card({'AFRAME MAQ'} inter AreaSet) = 1 then do;
			for{i in 150..300} do;
				prob = CDF('BINOMIAL',&max_itens_aframe_maq.,i/1000,&prev_itens_volume.);
				objDemArea['AFRAME MAQ'] = (i-1)/1000*replArea['AFRAME MAQ'];
				if prob < .95 then stop;
			end;	
			objDemArea['AFRAME MAQ'] = sum{<cv,mat,'AFRAME MAQ'> in AlocaAreaSet: varAloca[cv,mat,'AFRAME MAQ'] >0.1} demanda[cv,mat];
		end;
		/* Objetivo para outras áreas*/
		set<str> objSet;
		num objPerc{objSet};
		read data WRSTEMP.BLE_OBJ_AREA_&cd. into objSet=[AREA] objPerc=objetivo;
			
		/* Divide a demanda restante para o PBL*/
		num demanda_total = sum{<cv,mat> in ProdutoSet} demanda[cv,mat];
		num demRestante = demanda_total - sum{a in {'AFRAME','AFRAME MAQ'}: a in AreaSet} objDemArea[a];
		for{a in AreaSet: a not in {'AFRAME','AFRAME MAQ'}}
			objDemArea[a] =objPerc[a]*demRestante;

		/* FO ==> minimizar desvio da distribuição ideal*/
		impvar ivCargaArea{a in AreaSet} = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda[cv,mat];
		num pesoObj{AreaSet} init 1;
		for{a in AreaSet} do;
			if a in {'SCS','Robô-Pick','PFL'} then
				pesoObj[a] = 3;
			if a = 'PBL BG' then 
				pesoObj[a] = 2;
		end;
		var varDesvio{AreaSet} >=0;
		con desvioPlus{a in AreaSet}:
			varDesvio[a] >= (ivCargaArea[a]-objDemArea[a])*pesoObj[a];
		con desvioMinus{a in AreaSet}:
			varDesvio[a] >= (objDemArea[a]-ivCargaArea[a])*pesoObj[a];
		restore trocas;
		min obj2=sum{a in AreaSet} varDesvio[a];

		solve with milp/ maxtime=25;

		num demArea{AreaSet};
		for{a in AreaSet} 
			demArea[a] = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda100[cv,mat];
		Title "Solução Inicial";
		print objDemArea percent8.2 ivCargaArea percent8.2 varDesvio percent8.2;
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
		/* Melhorar a solução do SCS*/
		/* Permite desvios + 0.5%*/
		num desvio1{AreaSet};
		for{a in AreaSet} desvio1[a] = varDesvio[a];
		con desvioSCS{a in AreaSet}:
			varDesvio[a] <= desvio1[a] + 0.005;
		/* Aumenta número de trocas*/
	/*	varTrocas.ub = varTrocas.ub + 10;*/
		/* Objetivo maximizar produtos no SCS*/
		max obj3 = sum{<cv,mat,a> in AlocaAreaSet: a = 'SCS'} varAloca[cv,mat,a];
		solve with milp/ primalin maxtime=60;

		set<str,str,num,num> TrocaSetSCS init {};
		for{<cv,mat> in ProdutoSet, org in AreaSet, dest in AreaSet: <cv,mat,org> in Sol2Set} do;
			if varAloca[cv,mat,org]=0 and varAloca[cv,mat,dest]>0.1 then
				TrocaSetSCS = TrocaSetSCS union {<org,dest,cv,mat>};
		end;
		for{a in AreaSet} 
			demArea[a] = sum{<cv,mat,(a)> in AlocaAreaSet} varAloca[cv,mat,a]*demanda100[cv,mat];
		Title "Melhoria SCS";
		print objDemArea percent8.2 ivCargaArea percent8.2 varDesvio percent8.2;
		create data WRSTEMP.BLS2_sol_trocas2 from [AREA_ORG AREA_DEST COD_VENDA MATERIAL]={<org,dest,cv,mat> in TrocaSetSCS}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat];
		create data WRSTEMP.BLS2_sol_mapa2 from [COD_VENDA MATERIAL AREA]={<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1}
			descricao[cv,mat] demanda[cv,mat] comprimento[cv,mat] altura[cv,mat] largura[cv,mat] volume[cv,mat];

		set<num,num,str> Sol3Set init {};
		for{<cv,mat,a> in AlocaAreaSet: varAloca[cv,mat,a]>0.1} do;
			Sol3Set = Sol3Set union {<cv,mat,a>};
		end;
		/* Melhorar a solução do MASS PICKING*/
		/* Guarda a solução para o SCS*/
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
			Title "Melhoria Mass Picking";
			print objDemArea percent8.2 ivCargaArea percent8.2 varDesvio percent8.2;
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
		print cntArea capArea;

	quit;
	DATA WRSTEMP.BLS2_SOLUCAO_AREA;
		SET WRSTEMP.BLS2_sol_mapa3;
	RUN;
%end;
%mend AlocaArea;
