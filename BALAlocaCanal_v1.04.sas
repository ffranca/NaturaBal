%macro alocaPBL(cd);
proc optmodel printlevel=0;
	%let val_areas = 'PBL AAG' 'PBL AG' 'PBL MG' 'PBL BG' 'MASS PICKING' 'PFL';
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
	read data WRSTEMP.BLS1_PRODUTO_AREA_&cd(where=(area in (&val_areas) and estacao=1)) into XProdutoAreaSet=[AREA MODULO CANAL COD_VENDA MATERIAL];
	set<num,num,str,str,str> ProdutoCanalSet = setof{<a,mod,can,cv,mat> in XProdutoAreaSet: <cv,mat> not in DescSet}<cv,mat,a,mod,can>;
	/*Lê INCOMPATIBILIDADES*/
	set<num,num> IncompSet;
	read data WRSTEMP.BLE_INCOMPATIBILIDADE_&cd(where=(NIVEL_PBL~=.)) into IncompSet=[COD_VENDA NIVEL_PBL];
	/*Lê RESTRICAO_AREA*/
	set<str> AreaSet;
	num capArea{AreaSet};
	num replArea{AreaSet};
	num restr_similar{AreaSet};
	num fixaArea{AreaSet};
	read data WRSTEMP.BLE_RESTRICAO_AREA_&cd(where=(COD_CD=&cd and area in (&val_areas))) into AreaSet=[AREA]
		capArea=CAPACIDADE replArea=REPLICACAO restr_similar fixaArea=fixa;
	/*Lê SIMILARES*/
	set<num,num> SimilarSet;
	str grupo{SimilarSet};
	read data SIMULA.BLE_SIMILARES into SimilarSet=[COD_VENDA MATERIAL] grupo;
	set<str> GrupoSet = setof{<cv,mat> in SimilarSet} <grupo[cv,mat]>;
	set<num,num> CVSimilarSet{gp in GrupoSet} = setof{<cv,mat> in SimilarSet: grupo[cv,mat]=gp}<cv,mat>;
	/*Lê ESTRUTURA_CD*/
	set<str> CanalSet;
	str areaCanal{CanalSet};
	str modCanal{CanalSet};
	num estacao{CanalSet};
	num X{CanalSet};
	num Y{CanalSet};
	str classificacao{CanalSet};
	read data WRSTEMP.BLE_ESTRUTURA_CD_&cd(where=(STATUS~='INDISPONÍVEL' AND ESTACAO=1 and area in (&val_areas))) into CanalSet=[CANAL]
		areaCanal=AREA modCanal=MODULO estacao classificacao X Y; 
	/* Lê solução de alocação de área*/
	set<num,num,str,str> ProdutoModSet;
	num trocaModulo{ProdutoModSet};
	read data solucao_modulo(where=(area in (&val_areas))) into ProdutoModSet=[COD_VENDA MATERIAL AREA MODULO] trocaModulo=TROCA;
	/* Lê OBJ_MODULO*/
	set<str,str> ObjModuloSet;
	num max_trocas{ObjModuloSet};
	read data WRSTEMP.BLE_OBJ_MODULO_&cd. into ObjModuloSet=[AREA MODULO] max_trocas=trocas;

	/****************** Prepara modelo ******************/
	set<str> ClasseSet = /AA A B C D E F/;
	num tempo{ClasseSet} = [1 1.5 2 2.5 3 3.5 4];
	str Modulo;
	Modulo = 'BA1_COSTAS';
	set ModuloSet = setof{can in CanalSet}<modCanal[can]>;
	set CanSet = setof{can in CanalSet: modCanal[can]=Modulo}<can>;
	set<num,num,str> AlocaCanalSet = setof{<cv,mat,a,mod> in ProdutoModSet, can in CanSet: mod=Modulo}<cv,mat,can>;
	var varAloca{<cv,mat,can> in AlocaCanalSet} binary;

	/* Area intereira está fixa*/
	num fixaCanal{CanSet} init 0;

	set canFixaSet = setof{<cv,mat,a,mod,can> in ProdutoCanalSet: mod=Modulo and <cv,mat,can> in AlocaCanalSet and fixaArea[a] = 1} <cv,mat,can>;
	con fixarArea1{<cv,mat,can> in canFixaSet}:
		varAloca[cv,mat,can] = 1;
	con fixarArea2{<cv,mat,can> in AlocaCanalSet: fixaCanal[can]=1 and <cv,mat,can> not in canFixaSet}:
		varAloca[cv,mat,can] = 0;

	/* Cada produto deve estar alocado */
	con alocaProd{<cv,mat,a,mod> in ProdutoModSet: mod = Modulo}:
		sum{<(cv),(mat),can> in AlocaCanalSet} varAloca[cv,mat,can] = 1;
	/* Cada canal tem no máximo um produto*/
	con umProd{can in CanSet}:
		sum{<cv,mat,(can)> in AlocaCanalSet} varAloca[cv,mat,can] <= 1;
	/* Incompatibilidade */
	set<num,num,str> matIncompSet = setof{<cv,mat,can> in AlocaCanalSet, <(cv),nv> in IncompSet: Y[can]=nv}<cv,mat,can>;
	con incomp{<cv,mat,can> in matIncompSet}:
		varAloca[cv,mat,can] = 0;

	/* Número de trocas*/
	var varTrocas >= 0;
	str areaMod{ModuloSet};
	for{<cv,mat,a,mod> in ProdutoModSet} do;
		areaMod[mod] = a;
	end;
	con maxTrocas:
		varTrocas <= max_trocas[areaMod[Modulo],Modulo];
	set<num,num> ProdContaTroca = setof{<cv,mat,a,mod> in ProdutoModSet: mod=Modulo and trocaModulo[cv,mat,a,mod]=0}<cv,mat>;
	set<num,num,str> AlocaAnterior = setof{<cv,mat,a,mod,can> in ProdutoCanalSet: can in CanSet and <cv,mat> in ProdContaTroca}<cv,mat,can>;
	con trocas:
		varTrocas = sum{<cv,mat,can> in AlocaAnterior: <cv,mat,can> not in matIncompSet} (1-varAloca[cv,mat,can]); 

	/* PRODUTOS SIMILARES*/
	con simLadoCon{gp in GrupoSet, <cv1,mat1> in CVSimilarSet[(gp)], <cv2,mat2> in CVSimilarSet[(gp)], 
		<(cv1),(mat1),can1> in AlocaCanalSet, <(cv2),(mat2),can2> in AlocaCanalSet : 
		fixaCanal[can1]=0 and fixaCanal[can2]=0 and mat1~=mat2 and Y[can1]=Y[can2] and X[can1]-X[can2] = 1}:
			varAloca[cv1,mat1,can1] + varAloca[cv2,mat2,can2] <= 1;
	con simCimaCon{gp in GrupoSet, <cv1,mat1> in CVSimilarSet[(gp)], <cv2,mat2> in CVSimilarSet[(gp)], 
		<(cv1),(mat1),can1> in AlocaCanalSet, <(cv2),(mat2),can2> in AlocaCanalSet : 
		fixaCanal[can1]=0 and fixaCanal[can2]=0 and mat1~=mat2 and X[can1]=X[can2] and Y[can1]-Y[can2] = 1}:
			varAloca[cv1,mat1,can1] + varAloca[cv2,mat2,can2] <= 1;

	/* FO ==> minimizar tempo de separação*/
	
	num tempoCanal{can in CanSet} = &produtividade.*&prev_itens_volume.*tempo[classificacao[can]]/replArea[areaCanal[can]];
	min obj=sum{<cv,mat,can> in AlocaCanalSet} varAloca[cv,mat,can]*demanda[cv,mat]*tempoCanal[can];

	str SolCanal{ProdutoModSet} init '';
	num cargaModulo{ModuloSet};
	set<num,str,str> AlertaSet init {};
	str Alerta{AlertaSet} init 'NÍVEL INCOMPATÍVEL';
	set<str,str,str,str> AlertaSimSet init {};
	str AlertaSim{AlertaSimSet} init 'SIMILARES';
	for{mod in ModuloSet} do;
		Modulo = mod;
		for{can in CanSet} fixaCanal[can]=fixaArea[AreaCanal[can]];
		if restr_similar[areaMod[mod]] = 1 then do;
			if card(CanSet) <= 80 then
				solve with milp/ maxtime=120;
			else 
				solve with milp/ maxtime=500;
			if _SOLUTION_STATUS_ = 'INFEASIBLE' then do;
				print Modulo _SOLUTION_STATUS_;
				drop incomp;
				if card(CanSet) <= 80 then
					solve with milp/ maxtime=120;
				else 
					solve with milp/ maxtime=500;
				restore incomp;
				print 'Alerta: restrição de incompatibilidade de nível no PBL não considerada para o módulo.';
				AlertaSet = AlertaSet union setof{<cv,mat,can> in matIncompSet: varAloca[cv,mat,can]>= 0.1}
					<cv,(trim(left(put(mat,8.))) || '-' || descricao[cv,mat]) ,can>;
				print Alerta;
				AlertaSet = {};
				if _SOLUTION_STATUS_ = 'INFEASIBLE' then do;
					print Modulo _SOLUTION_STATUS_;
					drop simLadoCon;
					drop simCimaCon;
					if card(CanSet) <= 80 then
						solve with milp/ maxtime=120;
					else 
						solve with milp/ maxtime=500;
					restore simLadoCon;
					restore simCimaCon;
					print 'Alerta: restrição de similaridade não considerada para o módulo.';
					AlertaSet = AlertaSet union setof{<cv,mat,can> in matIncompSet: varAloca[cv,mat,can]>= 0.1}
						<cv,(trim(left(put(mat,8.))) || '-' || descricao[cv,mat]) ,can>;
					print Alerta;
					AlertaSet = {};
					AlertaSimSet = AlertaSimSet union 
						setof{gp in GrupoSet, <cv1,mat1> in CVSimilarSet[(gp)], <cv2,mat2> in CVSimilarSet[(gp)], 
						<(cv1),(mat1),can1> in AlocaCanalSet, <(cv2),(mat2),can2> in AlocaCanalSet : 
						fixaArea[AreaCanal[can1]]=0 and mat1~=mat2 and Y[can1]=Y[can2] and X[can1]-X[can2] = 1 and 
						varAloca[cv1,mat1,can1]>= 0.1 and varAloca[cv2,mat2,can2]>= 0.1}
							<(trim(left(put(mat1,8.))) || '-' || descricao[cv1,mat1]),can1,
							(trim(left(put(mat2,8.))) || '-' || descricao[cv2,mat2]),can2>;
					AlertaSimSet = AlertaSimSet union 
						setof{gp in GrupoSet, <cv1,mat1> in CVSimilarSet[(gp)], <cv2,mat2> in CVSimilarSet[(gp)], 
						<(cv1),(mat1),can1> in AlocaCanalSet, <(cv2),(mat2),can2> in AlocaCanalSet : 
						fixaArea[AreaCanal[can1]]=0 and mat1~=mat2 and Y[can1]-Y[can2]=1 and X[can1]=X[can2] and 
						varAloca[cv1,mat1,can1]>= 0.1 and varAloca[cv2,mat2,can2]>= 0.1}
							<(trim(left(put(mat1,8.))) || '-' || descricao[cv1,mat1]),can1,
							(trim(left(put(mat2,8.))) || '-' || descricao[cv2,mat2]),can2>;
					print AlertaSim;
					AlertaSimSet = {};
				end;
			end;
		end;
		else do;
			drop simLadoCon;
			drop simCimaCon;
			if card(CanSet) <= 80 then
				solve with milp/ maxtime=100;
			else 
				solve with milp/ maxtime=400;
			restore simLadoCon;
			restore simCimaCon;
		end;
		print Modulo _SOLUTION_STATUS_;
		cargaModulo[Modulo] = sum{<cv,mat,can> in AlocaCanalSet} varAloca[cv,mat,can]*demanda[cv,mat]*tempoCanal[can]/3600;
		for{<cv,mat,can> in AlocaCanalSet} do;
			if varAloca[cv,mat,can] > 0.1 then
				SolCanal[cv,mat,areaCanal[can],modCanal[can]] = can;
		end;
	end;
	print cargaModulo percent8.2;
	set<str,str,str,num,num> SolucaoSet = setof{<cv,mat,a,mod> in ProdutoModSet}<a,mod,SolCanal[cv,mat,a,mod],cv,mat>;
	create data solucao_canal_PBL from [AREA MODULO CANAL COD_VENDA MATERIAL]={<a,mod,can,cv,mat> in SolucaoSet}
		DESCRICAO[cv,mat] CLASSIFICACAO[can] DEMANDA[cv,mat] COMPRIMENTO[cv,mat] ALTURA[cv,mat] LARGURA[cv,mat] VOLUME[cv,mat];
quit;
%mend alocaPBL;
%macro alocaAFRAME(cd,area,modulo);
proc optmodel printlevel=0;
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
	read data WRSTEMP.BLS1_PRODUTO_AREA_&cd(where=(area = "&area" and modulo="&modulo" and estacao=1)) into XProdutoAreaSet=[AREA MODULO CANAL COD_VENDA MATERIAL];
	set<num,num,str,str,str> ProdutoCanalSet = setof{<a,mod,can,cv,mat> in XProdutoAreaSet: <cv,mat> not in DescSet}<cv,mat,a,mod,can>;
	/*Lê RESTRICAO_AREA*/
	set<str> AreaSet;
	num capArea{AreaSet};
	num replArea{AreaSet};
	num restr_similar{AreaSet};
	num fixaArea{AreaSet};
	read data WRSTEMP.BLE_RESTRICAO_AREA_&cd(where=(COD_CD=&cd and area = "&area")) into AreaSet=[AREA]
		capArea=CAPACIDADE replArea=REPLICACAO restr_similar fixaArea=fixa;
	/*Lê SIMILARES*/
	set<num> SimilarSet;
	str grupo{SimilarSet};
	read data SIMULA.BLE_SIMILARES into SimilarSet=[COD_VENDA] grupo;
	set<str> GrupoSet = setof{cv in SimilarSet} <grupo[cv]>;
	set<num> CVSimilarSet{gp in GrupoSet} = setof{cv in SimilarSet: grupo[cv]=gp}<cv>;
	/*Lê ESTRUTURA_CD*/
	set<str> CanalSet;
	str areaCanal{CanalSet};
	str modCanal{CanalSet};
	num estacao{CanalSet};
	num xX{CanalSet};
	num Y{CanalSet};
	str classificacao{CanalSet};
	read data WRSTEMP.BLE_ESTRUTURA_CD_&cd(where=(STATUS~='INDISPONÍVEL' AND ESTACAO=1 and area = "&area" and modulo="&modulo")) into CanalSet=[CANAL]
		areaCanal=AREA modCanal=MODULO estacao classificacao xX=X Y; 
	/* Lê solução de alocação de área*/
	set<num,num,str,str> ProdutoModSet;
	num trocaModulo{ProdutoModSet};
	num ncanais{ProdutoModSet};
	read data solucao_modulo(where=(area = "&area" and modulo="&modulo")) into ProdutoModSet=[COD_VENDA MATERIAL AREA MODULO] trocaModulo=TROCA ncanais;

	/****************** Prepara modelo ******************/
	str Modulo,Area;
	Modulo = "&modulo";
	Area = "&area";
	set<str> CanSet;
	CanSet = CanalSet union {'Primeiro','Ultimo'};
	num X{CanSet} init 0;
	for{can in CanSet: can not in {'Primeiro','Ultimo'}}
		X[can] = xX[can];
	X['Ultimo'] = max{can in CanSet}X[can]+1;
	set<num,num,str> AlocaCanalSet = setof{<cv,mat,a,mod> in ProdutoModSet, can in CanSet}<cv,mat,can>;
	var varAloca{AlocaCanalSet} binary;

	/* Area intereira está fixa*/
	num fixaCanal{CanSet} init 0;
	for{can in CanalSet} fixaCanal[can]=fixaArea[AreaCanal[can]];
	set canFixaSet = setof{<cv,mat,a,mod,can> in ProdutoCanalSet: <cv,mat,can> in AlocaCanalSet and fixaArea[a] = 1} <cv,mat,can>;
	con fixarArea1{<cv,mat,can> in canFixaSet}:
		varAloca[cv,mat,can] = 1;
	con fixarArea2{<cv,mat,can> in AlocaCanalSet: fixaCanal[can]=1 and <cv,mat,can> not in canFixaSet}:
		varAloca[cv,mat,can] = 0;

	/* Cada produto deve estar alocado */
	con alocaProd{<cv,mat,a,mod> in ProdutoModSet: mod = Modulo and a = Area and fixaArea[a]=0}:
		sum{<(cv),(mat),can> in AlocaCanalSet} varAloca[cv,mat,can] = ncanais[cv,mat,a,mod];
/*	expand alocaProd;*/
	/* Cada canal tem no máximo um produto*/
	con umProd{can in CanSet}:
		sum{<cv,mat,(can)> in AlocaCanalSet} varAloca[cv,mat,can] <= 1;
	/* Número de trocas*/
	var varTrocas >= 0;
	set ProdContaTroca = setof{<cv,mat,a,mod> in ProdutoModSet: mod=Modulo and a=Area and trocaModulo[cv,mat,a,mod]=0}<cv,mat>;
	set<num,num,str> AlocaAnterior = setof{<cv,mat,a,mod,can> in ProdutoCanalSet: can in CanSet and <cv,mat> in ProdContaTroca}<cv,mat,can>;
	con trocas:
		varTrocas = sum{<cv,mat,can> in AlocaAnterior} (1-varAloca[cv,mat,can]); 
	
	/* número de buracos*/
	str nextCan{CanSet} init '';
	set<str> redCanSet;

	/* Produtos iguais ficam lado a lado*/
	set<num,num> cvReplSet = setof{<cv,mat,a,mod> in ProdutoModSet: mod=Modulo and a=Area and ncanais[cv,mat,a,mod] > 1}<cv,mat>;
	var varBuracoCV{cvReplSet,redCanSet} binary;
	con buracoCV_plus{<cv,mat> in cvReplSet, can in redCanSet}:
		varBuracoCV[cv,mat,can] >= varAloca[cv,mat,can]-varAloca[cv,mat,nextCan[can]];
	con buracoCV_minus{<cv,mat> in cvReplSet, can in redCanSet}:
		varBuracoCV[cv,mat,can] >= varAloca[cv,mat,nextCan[can]]-varAloca[cv,mat,can];
	con umBuracoCV{<cv,mat> in cvReplSet}:
		sum{can in redCanSet} varBuracoCV[cv,mat,can] <= 2;

	/* PRODUTOS SIMILARES*/
	con simLadoCon{gp in GrupoSet, cv1 in CVSimilarSet[(gp)], cv2 in CVSimilarSet[(gp)], 
		<(cv1),mat1,can1> in AlocaCanalSet, <(cv2),mat2,can2> in AlocaCanalSet : cv1~=cv2 and can2=nextCan[can1]}:
		varAloca[cv1,mat1,can1] + varAloca[cv2,mat2,can2] <= 1;

	min obj=varTrocas;
	drop simLadoCon;
	/* Não Aloca nos canais fake*/
	con naoAlocaPU{<cv,mat,can> in AlocaCanalSet: can in {'Primeiro','Ultimo'}}:
		varAloca[cv,mat,can] = 0;

	set<str> SolCanal{ProdutoModSet} init {};
	put Area = Modulo =;
	for{can1 in CanSet} do;
		for{can2 in CanSet} do;
			if X[can1] = X[can2] - 1 then do;
				nextCan[can1] = can2;
				leave;
			end;
		end;
	end;
	redCanSet = setof{can in CanSet: nextCan[can] ~= ''} <can>;
	if restr_similar[Area] = 1 then do;
		restore simLadoCon;
		solve with milp/ maxtime=120;
	end;
	else do;
		drop simLadoCon;
		solve with milp/ maxtime=30;
	end;
	print Modulo (scan(symget("_OROPTMODEL_"),3));
	for{<cv,mat,can> in AlocaCanalSet} do;
		if varAloca[cv,mat,can] > 0.1 then
			SolCanal[cv,mat,areaCanal[can],modCanal[can]] = SolCanal[cv,mat,areaCanal[can],modCanal[can]] union {can};
	end;
	set<str,str,str,num,num> SolucaoSet = 
		setof{<cv,mat,a,mod> in ProdutoModSet, can in SolCanal[(cv),(mat),(a),(mod)]}<a,mod,can,cv,mat>;
	create data solucao_canal_AFRAME from [AREA MODULO CANAL COD_VENDA MATERIAL]={<a,mod,can,cv,mat> in SolucaoSet}
		DESCRICAO[cv,mat] CLASSIFICACAO='' DEMANDA[cv,mat] COMPRIMENTO[cv,mat] ALTURA[cv,mat] LARGURA[cv,mat] VOLUME[cv,mat];
quit;
%mend alocaAFRAME;

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
      WHERE t1.AREA IN ('AFRAME','AFRAME MAQ','PBL AAG','PBL AG','PBL MG','PBL BG','PFL');
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
	select count(*) into :aframe_cnt from areas where area in ('AFRAME','AFRAME MAQ');
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

%if &aframe_cnt ~= 0 %then %do;
	proc sql noprint;
		create table sol_aframe as select distinct area, modulo from solucao_modulo 
			where area in ('AFRAME','AFRAME MAQ');
		select count(*) into :cnt from sol_aframe;
		%let cnt = &cnt;
		select area, modulo into :area1-:area&cnt, :modulo1-:modulo&cnt from sol_aframe;
	quit;
	%do i=1 %to &cnt;
		%alocaAFRAME(&cd,&&area&i,&&modulo&i)
		data WRSTEMP.BLS4_solucao_canal;
			set WRSTEMP.BLS4_solucao_canal solucao_canal_AFRAME;
		run;
	%end;
%end;

proc sort data=WRSTEMP.BLS4_solucao_canal;
	by AREA MODULO CANAL;
run;
%mend AlocaCanal;

