/* Classe PREPROC (PRP)*/

%macro PRP_ciclosEnvolvidos(data_ini, data_fin, cod_cd);
	/* Devolve ciclos envolvidos na otimização em WORK.CICLOS */
	PROC SQL noprint;
	   CREATE TABLE WORK.CICLOS_01 AS 
	   SELECT DISTINCT t1.ANO, 
	          t1.CICLO
	      FROM SIMULA.BLE_SAIDA_DEMANDA_DETALHADA t1
	      WHERE t1.DATA BETWEEN "&data_ini"d AND "&data_fin"d AND t1.COD_CD = &cod_cd;
	QUIT;
	PROC SQL noprint;
	   CREATE TABLE WORK.CICLOS AS 
	   SELECT DISTINCT t1.ANO, 
	          t1.CICLO,
			  min(t1.data) FORMAT=DATE9. as DATA_INI,
			  max(t1.data) FORMAT=DATE9. as DATA_FIN
	      FROM SIMULA.BLE_SAIDA_DEMANDA_DETALHADA t1
		  inner join CICLOS_01 t2 on t1.ano=t2.ano and t1.ciclo=t2.ciclo
			group by t1.ano, t2.ciclo;
	QUIT;
%mend PRP_ciclosEnvolvidos;

%macro PRP_verificaTabela(lib,nome,rc,padrao);
	%let existe = 0;
	proc sql noprint;
	select count(memname) into :existe
	   from dictionary.tables
	   where libname="&lib" and memname="&nome";
	quit;
	%let &rc = 0; 
	%if &existe = 0 %then %do;
		%LOG_Insere(ERRO, Tabela não encontrada, &nome, N/A)
		%let &rc = 1;
	%end;
	/* Trata colunas de acordo com tabela padrão*/
	%if &padrao. ne and &&&rc = 0 %then %do;
		/* Verifica colunas*/
		proc sql;
			create table str_Tabela as select 
				name,
				type as type_org,
				length
			from dictionary.columns 
			where libname='WORK' and memname="&padrao";
		quit;
		proc sql;
			create table str_TabelaBruta as select 
				name,
				type 
			from dictionary.columns 
			where libname="&lib" and memname="&nome";
		quit;
		data erro;
			length TIPO $ 10 DESCRICAO $ 100 TABELA1 $ 30 TABELA2 $ 30;
			if _N_=1 then do;
				if 0 then set work.str_TabelaBruta;
				declare hash P(dataset:"work.str_TabelaBruta");
				P.definekey('name');      
				P.definedata('type');
				P.definedone();
			end;
			set str_Tabela;
			if P.find()~=0 then do;
				TIPO = 'ERRO';
				DESCRICAO = "Coluna: '" || trim(name) || "' não encontrada.";
				TABELA1 = "&nome.";
				TABELA2 = 'N/A';
				output;
			end;
			else if type ~= type_org then do;
				TIPO = 'ERRO';
				DESCRICAO = "Coluna: '" || trim(name) || "' tipo errado. Importar novamente.";
				TABELA1 = "&nome.";
				TABELA2 = 'N/A';
				output;
			end;
			keep TIPO DESCRICAO TABELA1 TABELA2;
		run;
		%local cnt i;
		proc sql noprint;
			select count(*) into :cnt from erro;
		quit;
		%if &cnt ~= 0 %then %do;
			%LOG_InsereTabela(erro)
			%let &rc = 1;
		%end;
	%end;
%mend PRP_verificaTabela;
%macro PRP_InitTabelas;
	proc sql;
		create table PLIN 
			('Estrutura Comercial (RE)'n CHAR(12),
			'Tipo de Evento (Estimativa de Ve'n CHAR(42),
			'Nome (Estimativa de Venda)'n CHAR(373),
			'Categoria SIPATESP (Produto da E'n CHAR(29),
			'Código de Venda (Produto)'n CHAR(5),
			Nome CHAR(50),
 			'Quantidade Dada Estimada'n NUM FORMAT=COMMA12.,
			'Quantidade Vendida Estimada'n NUM FORMAT=COMMA12.,
			TABELA CHAR(30));
	quit;
	proc sql;
		create table SALDAO 
			(CD NUM,
			'Cód. de Venda'n NUM,
			'Cód. de Material'n NUM,
			'Descrição Produto'n CHAR(40),
			Estoque NUM,
			TABELA CHAR(30));
	quit;
	proc sql;
		create table ZEST( 
			'Mat. Pai'n	CHAR(8),
			'Desc. Pai'n CHAR(41),
			'T.Mat'n CHAR(4),
			'C.Venda'n CHAR(5),
			Material CHAR(8),
			Descricao CHAR(43),
			'Qtde.'n NUM,
			TABELA CHAR(30));
	quit;
	proc sql;
		create table PAPER( 
			'Saída Plural Original'n num,
			'COD CD'n num,
			'COD VENDA'n num,
			'Cód Material'n num,
			'Descrição Material'n char(46),
			'Qtde Exemplares'n num,
			TABELA CHAR(30));
	quit;
%mend PRP_InitTabelas;
%macro PRP_concatenaTabela(lib, TabelaBruta, Tabela);
	/* Verifica colunas*/
	proc sql;
		create table str_Tabela as select 
			name,
			type as type_org,
			length
		from dictionary.columns 
		where libname='WORK' and memname="&Tabela";
	quit;
	proc sql;
		create table str_TabelaBruta as select 
			name,
			type 
		from dictionary.columns 
		where libname="&lib" and memname="&TabelaBruta";
	quit;
	data erro;
		length TIPO $ 10 DESCRICAO $ 100 TABELA1 $ 30 TABELA2 $ 30;
		if _N_=1 then do;
			if 0 then set work.str_TabelaBruta;
			declare hash P(dataset:"work.str_TabelaBruta");
			P.definekey('name');      
			P.definedata('type');
			P.definedone();
		end;
		set str_Tabela;
		if P.find()~=0 and name ~= 'TABELA' then do;
			TIPO = 'ERRO';
			DESCRICAO = "Coluna: '" || trim(name) || ' não encontrada.';
			TABELA1 = "&TabelaBruta.";
			TABELA2 = 'N/A';
			output;
		end;
		else if type ~= type_org and name ~= 'TABELA' then do;
			TIPO = 'ERRO';
			DESCRICAO = "Coluna: '" || trim(name) || "' tipo errado. Importar novamente.";
			TABELA1 = "&TabelaBruta.";
			TABELA2 = 'N/A';
			output;
		end;
		keep TIPO DESCRICAO TABELA1 TABELA2;
	run;
	%local cnt i;
	proc sql noprint;
		select count(*) into :cnt from erro;
	quit;
	%if &cnt ~= 0 %then %do;
		%LOG_InsereTabela(erro)
	%end;
	%else %do;
		/* concatena dados em &Tabela*/
		PROC SQL NOPRINT;
			select count(*)-1 into :cnt from str_Tabela;
			%let cnt=&cnt;
			select name,length into :name1-:name&cnt, :len1-:len&cnt from str_Tabela;
		   CREATE TABLE WORK.Tabela_01 AS 
		   SELECT 
				%do i=1 %to &cnt;
					"&&name&i"n length=&&len&i,
				%end;
				  "&TabelaBruta" LENGTH=30 as TABELA
		      FROM &lib..&TabelaBruta.;
		QUIT;		
		proc append base=&Tabela data=Tabela_01;
		quit;
	%end;
%mend PRP_concatenaTabela;
%macro PRP_finalizaTabelas;
	/* PLIN*/
	data PLIN_01;
		set PLIN;
		ANO = input(substr(TABELA,10,4),8.);
		CICLO = input(substr(TABELA,14,2),8.);
		WHERE nome not contains 'USO EXCLUSIVO PLIN';
	run;
	PROC SQL;
	   CREATE TABLE WORK.PLIN AS 
	   SELECT t1.'Estrutura Comercial (RE)'n AS RE, 
	          t1.'Tipo de Evento (Estimativa de Ve'n AS TIPO_EVENTO, 
	          t1.'Nome (Estimativa de Venda)'n AS NOME_EVENTO, 
	          t1.'Categoria SIPATESP (Produto da E'n AS CAT_SIPATESP, 
	          INPUT(t1.'Código de Venda (Produto)'n,8.) AS COD_VENDA, 
	          SUBSTR(t1.Nome,9) AS DESCRICAO, 
	          t1.'Quantidade Dada Estimada'n AS QTD_DADA, 
	          t1.'Quantidade Vendida Estimada'n AS QTD_VENDIDA, 
	          t1.TABELA, 
	          t1.ANO, 
	          t1.CICLO
	      FROM WORK.PLIN_01 t1;
	QUIT;	
	/* SALDAO*/
	data SALDAO_01;
		set SALDAO;
		ANO = input(substr(TABELA,12,4),8.);
		CICLO = input(substr(TABELA,16,2),8.);
	run;
	PROC SQL;
	   CREATE TABLE WORK.SALDAO AS 
	   SELECT t1.CD AS COD_CD, 
	          t1.'Cód. de Venda'n AS COD_VENDA, 
	          t1.'Cód. de Material'n AS MATERIAL, 
	          t1.'Descrição Produto'n AS DESCRICAO, 
	          t1.Estoque, 
	          t1.TABELA, 
	          t1.ANO, 
	          t1.CICLO
	      FROM WORK.SALDAO_01 t1;
	QUIT;
	/* ZEST*/
	DATA ZEST_ORG;
		SET ZEST;
	RUN;
	PROC SQL;
	   CREATE TABLE WORK.ZEST1 AS 
	   SELECT t1.Material, 
	          t1.'C.Venda'n
	      FROM WORK.ZEST t1
	      WHERE t1.'T.Mat'n = 'ZEST';
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.ZEST AS 
	   SELECT distinct INPUT(t2.'C.Venda'n,8.) AS COD_VENDA_PAI, 
	          INPUT(t1.'Mat. Pai'n,8.) AS MAT_PAI, 
	          t1.'Desc. Pai'n AS DESC_PAI, 
	          INPUT(t1.'C.Venda'n,8.) AS COD_VENDA, 
	          INPUT(t1.Material,8.) AS MATERIAL, 
	          t1.Descricao, 
	          t1.'Qtde.'n AS QTD, 
	          t1.TABELA
	      FROM WORK.ZEST t1
	           INNER JOIN WORK.ZEST1 t2 ON (t1.'Mat. Pai'n = t2.Material)
			WHERE t1.'T.Mat'n in ('ZPAC','ZPRO');
	QUIT;
	/* Tira materiais sem demanda (pai ou filho) ==> Deprecated -> pode ser saldão*/
/*	PROC SQL;*/
/*	   CREATE TABLE WORK.ZEST AS */
/*	   SELECT DISTINCT t1.COD_VENDA_PAI, */
/*	          t1.MAT_PAI, */
/*	          t1.DESC_PAI, */
/*	          t1.COD_VENDA, */
/*	          t1.MATERIAL, */
/*	          t1.Descricao, */
/*	          t1.QTD, */
/*	          t1.TABELA*/
/*	      FROM WORK.ZEST2 t1*/
/*	           INNER JOIN WORK.PLIN t2 ON (t1.COD_VENDA = t2.COD_VENDA OR t1.COD_VENDA_PAI=t2.COD_VENDA);*/
/*	QUIT;*/
	/* PAPER*/
	data PAPER_01;
		set PAPER;
		ANO = input(substr(TABELA,21,4),8.);
		CICLO = input(substr(TABELA,25,2),8.);
		WHERE 'COD CD'n ~= .;
	run;
	PROC SQL;
	   CREATE TABLE WORK.PAPER AS 
	   SELECT t1.'COD CD'n AS COD_CD, 
	          t1.'COD VENDA'n AS COD_VENDA, 
	          t1.'Cód Material'n AS MATERIAL, 
	          t1.'Descrição Material'n AS DESCRICAO, 
	          /* SUM_of_Qtde Exemplares */
	            (SUM(t1.'Qtde Exemplares'n)) AS ESTOQUE, 
	          t1.TABELA, 
	          t1.ANO, 
	          t1.CICLO
	      FROM WORK.PAPER_01 t1
	      GROUP BY t1.'COD CD'n,
	               t1.'COD VENDA'n,
	               t1.'Cód Material'n,
	               t1.'Descrição Material'n,
	               t1.TABELA,
	               t1.ANO,
	               t1.CICLO;
	QUIT;	
%mend PRP_finalizaTabelas;

%macro PRP_trataESTOQUE(cd);
	PROC SQL;
	   CREATE TABLE WORK.ESTOQUE AS 
	   SELECT &cd. AS COD_CD, 
	          t1.MATERIAL, 
	          /* SUM_of_Utiliz.livre */
	            (SUM(t1.ESTOQUE)) FORMAT=COMMA12.3 AS ESTOQUE
	      FROM WRSTEMP.BLE_ESTOQUE_&cd t1
	      GROUP BY t1.Material;
	QUIT;
%mend PRP_trataESTOQUE;

%macro PRP_verificaEntradas(ciclos,cd);
	/* Verifica se as tabelas de entrada estão disponíveis*/
	%local erro i cnt;
	/* CADASTRO_MATERIAIS*/
	proc sql noprint;
		create table CAD_MAT 
			(Material NUM FORMAT=BEST12.,
			'Descrição do material'n CHAR(41),
			'Código de Venda'n NUM FORMAT=BEST12.,
			Volume NUM FORMAT=BEST12.,
			UVl CHAR(11),
			TMat CHAR(11),
			'Cmpr.'n NUM FORMAT=BEST12.,
			'Unidade de medida'n CHAR(2),
			Largura NUM FORMAT=BEST12.,
			'Unidade de medida_2'n CHAR(2),
			Altura NUM FORMAT=BEST12.,
			'Unidade de medida_3'n CHAR(2),
			'Qtd.para número de notas EM'n NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(SIMULA,BLE_CADASTRO_MATERIAIS,erro,CAD_MAT)
	%if &erro = 0 %then %do;
		PROC SQL;
		   CREATE TABLE WORK.CADASTRO_MATERIAIS AS 
		   SELECT t1.Material AS MATERIAL, 
		          t1.'Descrição do material'n AS DESCRICAO, 
		          t1.'Código de Venda'n AS COD_VENDA, 
		          t1.Volume AS VOLUME, 
		          t1.UVl, 
		          t1.TMat, 
		          t1.'Cmpr.'n AS COMPRIMENTO, 
		          t1.'Unidade de medida'n AS UMC, 
		          t1.Largura AS LARGURA, 
		          t1.'Unidade de medida_2'n AS UML, 
		          t1.Altura AS ALTURA, 
		          t1.'Unidade de medida_3'n AS UMA,
				  t1.'Qtd.para número de notas EM'n AS ITENS_CAIXA
		      FROM SIMULA.BLE_CADASTRO_MATERIAIS t1;
		QUIT;
	%end;
	proc sql noprint;
		select count(*) into :cnt from ciclos;
		%let cnt = &cnt;
		select ano, ciclo into :ano1-:ano&cnt, :ciclo1-:ciclo&cnt from ciclos;
	quit;
	%PRP_InitTabelas
	/* PLIN*/
	%do i=1 %to &cnt;
		%let ano = &&ano&i;
		%let ciclo = &&ciclo&i;
		%PRP_verificaTabela(SIMULA,BLE_PLIN_&ano&ciclo,erro)
		%if &erro = 0 %then %do;
			%PRP_concatenaTabela(SIMULA,BLE_PLIN_&ano&ciclo,PLIN)
		%end;
	%end;
	/* SALDÃO */
	%do i=1 %to &cnt;
		%let ano = &&ano&i;
		%let ciclo = &&ciclo&i;
		%PRP_verificaTabela(SIMULA,BLE_SALDAO_&ano&ciclo,erro)
		%if &erro = 0 %then %do;
			%PRP_concatenaTabela(SIMULA,BLE_SALDAO_&ano&ciclo,SALDAO)
		%end;
	%end;
	/* ZEST */
	%do i=1 %to &cnt;
		%let ano = &&ano&i;
		%let ciclo = &&ciclo&i;
		%PRP_verificaTabela(SIMULA,BLE_ZEST_&ano&ciclo,erro)
		%if &erro = 0 %then %do;
			%PRP_concatenaTabela(SIMULA,BLE_ZEST_&ano&ciclo,ZEST)
		%end;
	%end;
	/* PAPER */
	%do i=1 %to &cnt;
		%let ano = &&ano&i;
		%let ciclo = &&ciclo&i;
		%PRP_verificaTabela(SIMULA,BLE_PAPER_DISPENSER_&ano&ciclo,erro)
		%if &erro = 0 %then %do;
			%PRP_concatenaTabela(SIMULA,BLE_PAPER_DISPENSER_&ano&ciclo,PAPER)
		%end;
	%end;
	%PRP_finalizaTabelas
	/*Mapa da linha*/
	proc sql noprint;
		create table MAPA 
			(AREA CHAR(15),
			MATERIAL NUM FORMAT=BEST12.,
			DESC_MATERIAL CHAR(41),			
			CANAL CHAR(11)
			);
	quit;
	%let atual = 1;
	%PRP_verificaTabela(WRSTEMP,BLE_MAPA_&cd.,erro,MAPA)
	%if &erro = 0 %then %do;
		/* Cria tabela MAPA*/
		data MAPA;
			length AREA_ESTACAO $ 15 CANAL $ 11 DESCRICAO $ 41;
			set WRSTEMP.BLE_MAPA_&cd.(where=(MATERIAL not is missing));

			AREA_ESTACAO = AREA;
			DESCRICAO = DESC_MATERIAL;
			KEEP AREA_ESTACAO CANAL MATERIAL DESCRICAO;
		run;
		%LOG_Mapa(erro)
		%if &erro = 0 %then %do;
			/* Tira duplicações*/
			data MAPA_01;
				set MAPA;
			run;
			PROC SQL;
			   CREATE TABLE WORK.MAPA AS 
			   SELECT DISTINCT t1.AREA_ESTACAO, 
			          t1.CANAL, 
			          t2.'Código de Venda'n AS COD_VENDA, 
			          t1.MATERIAL, 
			          t2.'Descrição do material'n AS DESCRICAO
			      FROM WORK.MAPA_01 t1
			           INNER JOIN SIMULA.BLE_CADASTRO_MATERIAIS t2 ON (t1.MATERIAL = t2.Material);
			QUIT;
		%end;
	%end;
	/*ESTOQUE*/
	proc sql noprint;
		create table ESTOQUE 
			(MATERIAL NUM FORMAT=BEST12.,
			ESTOQUE NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_ESTOQUE_&cd,erro,ESTOQUE)
	%if &erro = 0 %then %do;
		%PRP_trataESTOQUE(&cd)
	%end;

	/*ABRE_CANAL*/
	proc sql noprint;
		create table ABRE_CANAL 
			(AREA CHAR(15),
			FAIXA CHAR(3),			
			DEMANDA_INI NUM FORMAT=BEST12.,
			DEMANDA_FIM NUM FORMAT=BEST12.,
			REPOSICAO_INI NUM FORMAT=BEST12.,
			REPOSICAO_FIM NUM FORMAT=BEST12.,
			MODULOS NUM FORMAT=BEST12.,
			CANAIS_MODULO NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_ABRE_CANAL_&cd.,erro,ABRE_CANAL)

	/*OBJ_AREA*/
	proc sql noprint;
		create table OBJ_AREA (
			TECNOLOGIA CHAR(10),
			AREA CHAR(7),			
			OBJETIVO NUM FORMAT=PERCENT9.2,
			TROCAS NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_OBJ_AREA_&cd.,erro,OBJ_AREA)
	

	/*INCOMPATIBILIDADE*/
	proc sql noprint;
		create table INCOMPATIBILIDADE (
			COD_VENDA NUM FORMAT=BEST12.,
			'DESCRIÇÃO MATERIAL'n CHAR(41),
			'ROBÔ-PICK'n CHAR(14),			
			AFRAME CHAR(14),			
			'AFRAME MAQ'n CHAR(14),
			NIVEL_PBL NUM FORMAT=8.0);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_INCOMPATIBILIDADE_&cd.,erro,INCOMPATIBILIDADE)

	/*OBJ_MODULO*/
	proc sql noprint;
		create table OBJ_MODULO (
			AREA CHAR(7),
			MODULO CHAR(10),
			CARGA NUM FORMAT=PERCENT9.2,
			ORDEM NUM FORMAT=BEST12.,
			TROCAS NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_OBJ_MODULO_&cd.,erro,OBJ_MODULO)

	/*ESTRUTURA_CD*/
	proc sql noprint;
		create table ESTRUTURA_CD (
			COD_CD NUM FORMAT=BEST12.,
			AREA CHAR(7),
			ESTACAO NUM FORMAT=BEST12.,
			MODULO CHAR(3),			
			CANAL CHAR(11),			
			STATUS CHAR(20),			
			CLASSIFICACAO CHAR(3),			
			ESPELHO CHAR(1),			
			X NUM FORMAT=BEST12.,
			Y NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_ESTRUTURA_CD_&cd.,erro,ESTRUTURA_CD)

	/*RESTRICAO_AREA*/
	proc sql noprint;
		create table RESTRICAO_AREA (
			COD_CD NUM FORMAT=BEST12.,
			CD CHAR(5),
			AREA CHAR(7),
			RESTR_SIMILAR NUM FORMAT=BEST12.,
			FIXA NUM FORMAT=BEST12.,
			CAPACIDADE NUM FORMAT=BEST12.,
			REPLICACAO NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_RESTRICAO_AREA_&cd.,erro,RESTRICAO_AREA)
	
	/*PARAMETROS*/
	proc sql noprint;
		create table PARAMETROS (
			COD_CD NUM FORMAT=BEST12.,
			DATA_INICIAL NUM FORMAT=DATE9.,
			DATA_FINAL NUM FORMAT=DATE9.,
			PRODUTIVIDADE NUM FORMAT=BEST12.,
			ITENS_POR_VOLUME NUM FORMAT=BEST12.,
			MAX_TROCA_AREA NUM FORMAT=BEST12.,
			MAX_TROCA_MODULO NUM FORMAT=BEST12.,
			MAX_TROCA_CANAL NUM FORMAT=BEST12.,
			ALOCA_AREA NUM FORMAT=BEST12.,
			ALOCA_MODULO NUM FORMAT=BEST12.,
			ALOCA_CANAL NUM FORMAT=BEST12.,
			MAX_ITENS_AFRAME NUM FORMAT=BEST12.,
			MAX_ITENS_AFRAME_MAQ NUM FORMAT=BEST12.,
			ALT_COLUNA_AFRAME NUM FORMAT=BEST12.,
			REGRA_ESTOQUE CHAR(9),
			PREENCHE_MASS_PICKING NUM FORMAT=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_PARAMETROS,erro,PARAMETROS)

%mend PRP_verificaEntradas;
%macro PRP_previsaoPercentual(data_ini, data_fin, cd);
	/* Acha o percentual da CD/Ciclo na RE e no período*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_01 AS 
	   SELECT t1.RE, 
	          t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          t1.DATA, 
	            (SUM(t1.VOLUME_SEPARADO)) FORMAT=BEST12. AS SUM_of_SUM_of_VOLUME_CAPTADO
	      FROM SIMULA.BLE_SAIDA_DEMANDA_DETALHADA t1
	      GROUP BY t1.RE,
	               t1.COD_CD,
	               t1.ANO,
	               t1.CICLO,
	               t1.DATA;
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_02 AS 
	   SELECT t1.RE, 
	          t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          t1.DATA, 
	          /* DEMANDA_PERC */
	          COALESCE(t1.SUM_of_SUM_of_VOLUME_CAPTADO / sum(t1.SUM_of_SUM_of_VOLUME_CAPTADO),0) FORMAT=PERCENT8.2 AS DEMANDA_PERC
	      FROM WORK.PREV_PERC_01 t1
	      GROUP BY t1.RE,
	               t1.ANO,
	               t1.CICLO;
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_03 AS 
	   SELECT t1.RE, 
	          t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          /* SUM_of_DEMANDA_PERC */
	            (SUM(t1.DEMANDA_PERC)) FORMAT=PERCENT8.2 AS DEMANDA_PERC
	      FROM WORK.PREV_PERC_02 t1
	      WHERE t1.DATA BETWEEN "&data_ini"d AND "&data_fin"d AND t1.COD_CD = &cd
	      GROUP BY t1.RE,
	               t1.COD_CD,
	               t1.ANO,
	               t1.CICLO;
	QUIT;	
	/* Aplicar o percentual no PLIN correspondente ==> saída demanda por material*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_04 AS 
	   SELECT t1.COD_VENDA, 
	          /* DEMANDA */
	            (SUM(sum(t1.QTD_DADA,t1.QTD_VENDIDA)*t2.DEMANDA_PERC)) 
	            FORMAT=COMMA12. AS DEMANDA
	      FROM WORK.PLIN t1, WORK.PREV_PERC_03 t2
	      WHERE (t1.ANO = t2.ANO AND t1.CICLO = t2.CICLO AND t1.RE = t2.RE)
	      GROUP BY t1.COD_VENDA;
	QUIT;
	/*Tratar Saldão*/
	PROC SQL;
	   CREATE TABLE WORK.SALDAO_01 AS 
	   SELECT t1.COD_CD, 
	          t1.COD_VENDA, 
	          t1.MATERIAL, 
	          t1.DESCRICAO, 
	          t1.ESTOQUE, 
	          t1.TABELA, 
	          t1.ANO, 
	          t1.CICLO, 
	          t2.DATA_INI as ABERTURA, 
	          t2.DATA_FIN as FECHAMENTO
	      FROM WORK.SALDAO t1, WORK.CICLOS t2
	      WHERE (t1.ANO = t2.ANO AND t1.CICLO = t2.CICLO) AND t1.COD_CD = &cod_cd;
	QUIT;
	/* Faz demanda por dia do período de saldão ==> Hipótese 70% na primeira semana e 30% no resto*/
	data saldao_01(drop=data);
		set ciclos;
		format data date9. perc_ciclo percent8.2;

		do data=data_ini to data_fin;
			if data <= data_ini+6 then do;
				if data >= "&data_ini"d and data <= "&data_fin"d then
					perc_ciclo + 0.1; /* 10% por dia na primeira semana do ciclo*/
			end;
			else if data > data_ini+6 and data >= "&data_ini"d and data <= "&data_fin"d then do;
				perc_ciclo + 0.3/(data_fin - data_ini+6); /* 30% nos outros dias do ciclo*/
			end;
		end;
	run;
	PROC SQL;
	   CREATE TABLE WORK.SALDAO_03 AS 
	   SELECT t1.COD_VENDA, 
	          /* SUM_of_demanda */
	            (SUM(t1.estoque*t2.perc_ciclo)) AS SUM_of_demanda
	      FROM WORK.SALDAO t1
		  inner join saldao_01 t2 on t1.ano=t2.ano and t1.ciclo=t2.ciclo and t1.cod_cd= &cod_cd
	      GROUP BY t1.COD_VENDA;
	QUIT;
	/* Junta com a previsão*/
	proc sql;
		create table PREV_PERC_05 as select
			coalesce(t1.COD_VENDA,t2.COD_VENDA) as COD_VENDA,
			SUM(t1.demanda, t2.SUM_of_demanda) AS DEMANDA
		from PREV_PERC_04 t1
		full join SALDAO_03 t2 on t1.COD_VENDA=t2.COD_VENDA;
	quit;
	/* Tratar ZEST*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_06a AS 
	   SELECT DISTINCT /* COD_VENDA */
	            (coalesce(t2.COD_VENDA,t1.cod_venda)) AS COD_VENDA, 
				t2.COD_VENDA_PAI,
	            (IFN(t2.qtd~=.,t1.DEMANDA*t2.qtd,t1.DEMANDA)) AS DEMANDA
	      FROM WORK.PREV_PERC_05 t1
	           LEFT JOIN WORK.ZEST t2 ON (t1.cod_venda = t2.COD_VENDA_PAI)
			   ORDER BY (CALCULATED COD_VENDA);
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_06b AS 
	   SELECT t1.COD_VENDA, 
	          /* SUM_of_DEMANDA */
	            (SUM(t1.DEMANDA)) AS DEMANDA
	      FROM WORK.PREV_PERC_06A t1
	      GROUP BY t1.COD_VENDA;
	QUIT;
	/* Explodir em código de material*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_07a AS 
	   SELECT t1.COD_VENDA, 
	          t2.MATERIAL, 
	          t2.DESCRICAO, 
	          t2.TMat, 
	          t2.VOLUME, 
	          t2.COMPRIMENTO, 
	          t2.UMC, 
	          t2.LARGURA, 
	          t2.UML, 
	          t2.ALTURA, 
	          t2.UMA, 
	          COALESCE(t3.ESTOQUE,0) AS ESTOQUE,
			  t1.DEMANDA
	      FROM WORK.PREV_PERC_06b t1
			LEFT JOIN CADASTRO_MATERIAIS t2 ON t1.COD_VENDA = t2.COD_VENDA
			LEFT JOIN WORK.ESTOQUE t3 ON t2.Material = t3.Material
			where comprimento > 0
	      ORDER BY t1.COD_VENDA,
	               t3.ESTOQUE desc;
	QUIT;
/* Trata PAPER DISPENSER*/
	PROC SQL;
   CREATE TABLE WORK.PREV_PAPER_001 AS 
   SELECT t1.COD_CD, 
          t1.ANO, 
          t1.CICLO, 
          t1.DATA, 
          /* SUM_of_SUM_of_VOLUME_CAPT */
            (SUM(t1.SUM_of_SUM_of_VOLUME_CAPTADO)) FORMAT=BEST12. AS SUM_of_SUM_of_VOLUME_CAPTADO
      FROM WORK.PREV_PERC_01 t1
      GROUP BY t1.COD_CD,
               t1.ANO,
               t1.CICLO,
               t1.DATA;
	QUIT;
	

	PROC SQL;
	   CREATE TABLE WORK.PREV_PAPER_01 AS 
	   SELECT t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          t1.DATA, 
	          /* DEMANDA_PERC */
	          COALESCE(t1.SUM_of_SUM_of_VOLUME_CAPTADO / sum(t1.SUM_of_SUM_of_VOLUME_CAPTADO),0) FORMAT=PERCENT8.2 AS DEMANDA_PERC
	      FROM WORK.PREV_PAPER_001 t1
	      GROUP BY t1.COD_CD,
	               t1.ANO,
	               t1.CICLO;
	QUIT;

	PROC SQL;
	   CREATE TABLE WORK.PREV_PAPER_02 AS 
	   SELECT t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          /* SUM_of_DEMANDA_PERC */
	            (SUM(t1.DEMANDA_PERC)) FORMAT=PERCENT8.2 AS DEMANDA_PERC
	      FROM WORK.PREV_PAPER_01 t1
	      WHERE t1.DATA BETWEEN "&data_ini"d AND "&data_fin"d AND t1.COD_CD = &cd
	      GROUP BY t1.COD_CD,
	               t1.ANO,
	               t1.CICLO;
	QUIT;	
	/* Aplicar o percentual no PAPER correspondente ==> saída demanda por material*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PAPER_03 AS 
	   SELECT t1.COD_VENDA, 
	          t1.MATERIAL,
	          /* DEMANDA */
	            SUM(t1.ESTOQUE*t2.DEMANDA_PERC) FORMAT=COMMA12. AS DEMANDA
	      FROM WORK.PAPER t1, WORK.PREV_PAPER_02 t2
	      WHERE (t1.ANO = t2.ANO AND t1.CICLO = t2.CICLO AND t1.COD_CD=t2.COD_CD)
	      GROUP BY t1.COD_VENDA, t1.MATERIAL;
	QUIT;

	PROC SQL;
	   CREATE TABLE WORK.PREV_PAPER_04 AS 
	   SELECT t1.COD_VENDA, 
	          t1.MATERIAL, 
	          t2.DESCRICAO, 
	          t2.TMat, 
	          t2.VOLUME, 
	          t2.COMPRIMENTO, 
	          t2.UMC, 
	          t2.LARGURA, 
	          t2.UML, 
	          t2.ALTURA, 
	          t2.UMA, 
	          t1.DEMANDA AS ESTOQUE,
			  t1.DEMANDA
	      FROM WORK.PREV_PAPER_03 t1
			LEFT JOIN CADASTRO_MATERIAIS t2 ON t1.COD_VENDA = t2.COD_VENDA AND t1.MATERIAL=t2.MATERIAL;
	QUIT;
/* Junta com demanda normal*/

	PROC SQL;
	   CREATE TABLE WORK.PREV_PRD AS 
	   SELECT t2.'Código de Venda'n AS COD_VENDA, 
	          t1.MATERIAL, 
	          t1.'Desc Material'n AS DESCRICAO, 
	          t2.TMat, 
	          t2.VOLUME, 
	          t2.'Cmpr.'n AS COMPRIMENTO, 
	          t2.'Unidade de medida'n AS UMC, 
	          t2.Largura, 
	          t2.'Unidade de medida_2'n AS UML, 
	          t2.Altura, 
	          t2.'Unidade de medida_3'n AS UMA, 
	          t3.ESTOQUE, 
	          t1.Unidades AS DEMANDA
	      FROM WRSTEMP.BLE_PRD_&cd. t1, SIMULA.BLE_CADASTRO_MATERIAIS t2, WRSTEMP.BLE_ESTOQUE_&cd. t3
	      WHERE (t1.Material = t2.Material AND t1.Material = t3.MATERIAL);
	QUIT;


	data PREV_PERC_07b1;
		set PREV_PERC_07a PREV_PAPER_04 PREV_PRD;
	run;

	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_07B AS 
	   SELECT DISTINCT 
			  t1.COD_VENDA, 
	          t1.MATERIAL, 
	          t1.DESCRICAO, 
	          t1.TMat, 
	          t1.VOLUME, 
	          t1.COMPRIMENTO, 
	          t1.UMC, 
	          t1.LARGURA, 
	          t1.UML, 
	          t1.ALTURA, 
	          t1.UMA, 
	          sum(t1.ESTOQUE) as ESTOQUE, 
	          /* DEMANDA */
	            (SUM(t1.DEMANDA)) FORMAT=COMMA12. AS DEMANDA
	      FROM WORK.PREV_PERC_07B1 t1
	      GROUP BY t1.COD_VENDA,
	               t1.MATERIAL;
	QUIT;
	/* Faz demanda percentual por cod_venda*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_07c AS 
	   SELECT t1.*, 
	          t1.DEMANDA/(SUM(t1.DEMANDA)) AS DEMANDA_PERC
	      FROM WORK.PREV_PERC_07b t1;
	QUIT;
	proc sql;
		create table prev_perc_07 as 	
			select t1.*,
				estoque/sum(estoque) as ESTOQUE_PERC
		from prev_perc_07c t1
			group by cod_venda;
	quit;
	/* Verifica qual a regra 1-usa o material com o maior estoque 2-usa todos com estoque*/
%if &regra_estoque = USA_MAT_MAIOR_ESTOQUE %then %do;
	/*Verifica quais materiais já estão na linha*/
	PROC SQL;
		CREATE TABLE WORK.PREV_PERC_071 AS 
			SELECT DISTINCT t1.*, 
				(IFN(t2.MATERIAL~=.,1,0)) AS IS_NA_LINHA
			FROM WORK.PREV_PERC_07 t1
				LEFT JOIN WRSTEMP.BLE_MAPA_&cd. t2 ON (t1.MATERIAL = t2.MATERIAL);
	QUIT;

	proc sort data=prev_perc_071;
		by COD_VENDA DESCENDING IS_NA_LINHA DESCENDING ESTOQUE;
	quit;
	data PREV_PERC_08a;
		set PREV_PERC_071;
		by COD_VENDA;


		
		if first.COD_VENDA then output;
		drop demanda_perc;
	run;
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_08 AS 
	   SELECT t1.*, 
	          t1.DEMANDA/(SUM(t1.DEMANDA)) AS DEMANDA_PERC,
	          t1.DEMANDA/(SUM(t1.DEMANDA)) AS DEMANDA_PERC_100
	      FROM WORK.PREV_PERC_08a t1;
	QUIT;

%end;
%else %do;
	/* Log material com menos de 5% do estoque de cod_venda e tira da base*/
	Title "Aviso. Materiais com estoque percentual menor que limite não considerados. Tratar manualmente";
	PROC SQL;
		create table log_estoque_5perc as SELECT DISTINCT
			'AVISO' AS TIPO,
			"Produto '" || trim(put(t1.material,8.)) || "-" || trim(t1.descricao) || "' estoque menor que limite." AS DESCRICAO,
			'N/A' AS TABELA1,
			'N/A' AS TABELA2
		FROM prev_perc_07 t1
		WHERE t1.ESTOQUE_PERC <= 0.05 AND t1.ESTOQUE_PERC is not missing and t1.ESTOQUE_PERC ~= 0;
		select * from log_estoque_5perc;
	QUIT;
/*	%LOG_InsereTabela(log_estoque_5perc)*/
	Title ;
	proc sql;
		create table PREV_PERC_071(drop=demanda_perc) as
			select distinct * from prev_perc_07
			where ESTOQUE_PERC > 0.05 or ESTOQUE_PERC is missing;
	quit;
	/* Refaz a demanda_perc para somar 100%*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_PERC_08 AS 
	   SELECT t1.*, 
	          t1.DEMANDA/(SUM(t1.DEMANDA)) AS DEMANDA_PERC,
	          t1.DEMANDA/(SUM(t1.DEMANDA)) AS DEMANDA_PERC_100
	      FROM WORK.PREV_PERC_071 t1;
	QUIT;
%end;
	/*Previsão Percentual Final*/
PROC SQL;
	CREATE TABLE WRSTEMP.BLS1_PRODUTOS_&cd AS 
		SELECT t1.COD_VENDA, 
			t1.MATERIAL, 
			t1.DESCRICAO, 
			t1.TMAT, 
			t1.VOLUME, 
			t1.COMPRIMENTO, 
			t1.UMC, 
			t1.LARGURA, 
			t1.UML, 
			t1.ALTURA, 
			t1.UMA,
			IFN(t2.ITENS_CAIXA=1,50,t2.ITENS_CAIXA) AS ITENS_CAIXA,
			t1.ESTOQUE, 
			t1.ESTOQUE_PERC format=percent8.2, 
			t1.DEMANDA format=comma12., 
			t1.DEMANDA_PERC format=percent8.2,
			t1.DEMANDA_PERC_100 format=percent8.2
		FROM WORK.PREV_PERC_08 t1
			INNER JOIN CADASTRO_MATERIAIS t2 ON t1.MATERIAL=t2.MATERIAL;
QUIT;
/* Relatório de demanda tratada*/
%PRP_rel_demanda
%mend PRP_previsaoPercentual;

%macro PRP_PrevisaoDiaria(data_ini, data_fin, cd);
	/* Acha o percentual da CD/Ciclo na RE e no período*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_DIA_01 AS 
	   SELECT t1.RE, 
	          t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          t1.DATA, 
	          /* SUM_of_SUM_of_VOLUME_CAPTADO */
	            (SUM(t1.VOLUME_SEPARADO)) FORMAT=BEST12. AS SUM_of_SUM_of_VOLUME_CAPTADO
	      FROM SIMULA.BLE_SAIDA_DEMANDA_DETALHADA t1
	      GROUP BY t1.RE, t1.COD_CD, t1.ANO, t1.CICLO, t1.DATA;
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.PREV_DIA_02 AS 
	   SELECT t1.RE, 
	          t1.COD_CD, 
	          t1.ANO, 
	          t1.CICLO, 
	          t1.DATA, 
	          /* DEMANDA_PERC */
	          COALESCE(t1.SUM_of_SUM_of_VOLUME_CAPTADO / sum(t1.SUM_of_SUM_of_VOLUME_CAPTADO),0) FORMAT=PERCENT8.2 AS DEMANDA_PERC
	      FROM WORK.PREV_DIA_01 t1
	      GROUP BY t1.RE, t1.ANO, t1.CICLO
		ORDER BY DATA
		;
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.PREV_DIA_03 AS 
	   SELECT t1.*
	      FROM WORK.PREV_DIA_02 t1
	      WHERE t1.DATA BETWEEN "&data_ini"d AND "&data_fin"d AND t1.COD_CD = &cd AND DEMANDA_PERC ~= 0
		ORDER BY DATA;
	QUIT;	
	/* Aplicar o percentual no PLIN correspondente ==> saída demanda por material*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_DIA_04 AS 
	   SELECT t1.COD_VENDA, 
	          t2.DATA,
	          /* DEMANDA */
	            (SUM(sum(t1.QTD_DADA,t1.QTD_VENDIDA)*t2.DEMANDA_PERC)) 
	            FORMAT=COMMA12. AS DEMANDA
	      FROM WORK.PLIN t1, WORK.PREV_DIA_03 t2
	      WHERE (t1.ANO = t2.ANO AND t1.CICLO = t2.CICLO AND t1.RE = t2.RE)
	      GROUP BY t1.COD_VENDA,t2.DATA;
	QUIT;
	/*Tratar Saldão*/
	PROC SQL;
	   CREATE TABLE WORK.SALDAO_01 AS 
	   SELECT t1.COD_CD, 
	          t1.COD_VENDA, 
	          t1.MATERIAL, 
	          t1.DESCRICAO, 
	          t1.ESTOQUE, 
	          t1.TABELA, 
	          t1.ANO, 
	          t1.CICLO, 
	          t2.DATA_INI as ABERTURA, 
	          t2.DATA_FIN as FECHAMENTO
	      FROM WORK.SALDAO t1, WORK.CICLOS t2
	      WHERE (t1.ANO = t2.ANO AND t1.CICLO = t2.CICLO) AND t1.COD_CD = &cod_cd;
	QUIT;
	/* Faz demanda por dia do período de saldão ==> Hipótese 70% na primeira semana e 30% no resto*/
	data saldao_01;
		set ciclos;
		format data date9. perc_ciclo percent8.2;

		do data=data_ini to data_fin;
			if data <= data_ini+6 and weekday(data) > 1 then do;
				if data >= "&data_ini"d and data <= "&data_fin"d then do;
					perc_ciclo = 0.12; /* 12% por dia na primeira semana do ciclo*/
					output;
				end;
			end;
			else if data > data_ini+6 and data >= "&data_ini"d and data <= "&data_fin"d  and weekday(data)>1 then do;
				perc_ciclo = 0.30/(data_fin - data_ini+6); /* 30% nos outros dias do ciclo*/
				output;
			end;
		end;
	run;
	PROC SQL;
	   CREATE TABLE WORK.SALDAO_03 AS 
	   SELECT t1.COD_VENDA, 
	          t2.DATA,
	          /* SUM_of_demanda */
	            (SUM(t1.estoque*t2.perc_ciclo)) AS SUM_of_demanda
	      FROM WORK.SALDAO t1
		  inner join saldao_01 t2 on t1.ano=t2.ano and t1.ciclo=t2.ciclo and t1.cod_cd= &cod_cd
	      GROUP BY t1.COD_VENDA,T2.DATA;
	QUIT;
	/* Junta com a previsão*/
	proc sql;
		create table PREV_DIA_05 as select
			coalesce(t1.data,t2.data) FORMAT=DATE7. as DATA,
			coalesce(t1.COD_VENDA,t2.COD_VENDA) as COD_VENDA,
			SUM(t1.demanda, t2.SUM_of_demanda) AS DEMANDA
		from PREV_DIA_04 t1
		full join SALDAO_03 t2 on t1.COD_VENDA=t2.COD_VENDA
			order by calculated cod_venda, CALCULATED data;
	quit;
	/* Tratar ZEST*/
	PROC SQL;
	   CREATE TABLE WORK.PREV_DIA_06a AS 
	   SELECT DISTINCT t1.DATA,
	            (coalesce(t2.COD_VENDA,t1.cod_venda)) AS COD_VENDA, 
				t2.COD_VENDA_PAI,
	            (IFN(t2.qtd~=.,t1.DEMANDA*t2.qtd,t1.DEMANDA)) AS DEMANDA
	      FROM WORK.PREV_DIA_05 t1
	           LEFT JOIN WORK.ZEST t2 ON (t1.cod_venda = t2.COD_VENDA_PAI)
			   ORDER BY (CALCULATED COD_VENDA);
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.PREV_DIA_06 AS 
	   SELECT t1.COD_VENDA, 
	          t1.DATA,
	          /* SUM_of_DEMANDA */
	            (SUM(t1.DEMANDA)) AS DEMANDA
	      FROM WORK.PREV_DIA_06A t1
	      GROUP BY t1.COD_VENDA,t1.DATA;
	QUIT;
	PROC TRANSPOSE DATA=WORK.PREV_DIA_06 OUT=WRSTEMP.BLS1_PREVISAO_DIA NAME=FONTE;
		BY COD_VENDA;
		ID DATA;
		VAR DEMANDA;

	RUN; QUIT;
%mend PRP_PrevisaoDiaria;

%macro PRP_rel_demanda;
	%local cnt;
	proc sql noprint;
		select count(*) into :cnt from ciclos;
		%let cnt = &cnt;
		select 100*ano+ciclo into :ciclo1-:ciclo&cnt from ciclos;
	quit;
	/* PLIN */
	PROC SQL;
	   CREATE TABLE WORK.REL_DEM_PLIN01 AS 
	   SELECT DISTINCT t1.COD_VENDA, 
	            (SUM(sum(t1.QTD_DADA,t1.QTD_VENDIDA)))FORMAT=COMMA12. as DEMANDA_BRUTA_PLIN,
	          t1.ANO*100+t1.CICLO AS CICLO,
			  t2.DEMANDA_PERC AS PERCENTUAL_CICLO_PLIN
	      FROM WORK.PLIN t1, WORK.PREV_PERC_03 t2
	      WHERE (t1.ANO = t2.ANO AND t1.CICLO = t2.CICLO AND t1.RE = t2.RE)
	      GROUP BY t1.COD_VENDA, t1.ANO, t1.CICLO;
	QUIT;
	/* Transpose*/
	data REL_DEM_PLIN02(keep=COD_VENDA 
			%do i=1 %to &cnt;
				PLIN_bruto_&&ciclo&i perc_PLIN_&&ciclo&i PLIN_&&ciclo&i
			%end;
			);
		format cod_venda 8.;
		format 
			%do i=1 %to &cnt;
				PLIN_bruto_&&ciclo&i comma12. perc_PLIN_&&ciclo&i percent8.2 PLIN_&&ciclo&i comma12.
			%end;
			;
		set REL_DEM_PLIN01;
		array PLIN_bruto{*}
			%do i=1 %to &cnt; 
				PLIN_bruto_&&ciclo&i
			%end;
			;
		array perc_PLIN{*}
			%do i=1 %to &cnt; 
				perc_PLIN_&&ciclo&i
			%end;
			;
		array PLIN{*}
			%do i=1 %to &cnt; 
				PLIN_&&ciclo&i
			%end;
			;
		by cod_venda;
		retain i PLIN perc_PLIN PLIN_bruto;

		if first.cod_venda then do i=1 to dim(PLIN);
			PLIN_bruto[i] = .;
			perc_PLIN[i] = .;
			PLIN[i] = .;
		end;
		do i=1 to dim(PLIN);
			anociclo=symget(compress('ciclo' || put(i,1.)));
			if ciclo=anociclo then do;
				PLIN_bruto[i] = demanda_bruta_PLIN;
				perc_PLIN[i] = percentual_ciclo_PLIN;
				PLIN[i] = PLIN_bruto[i]*perc_PLIN[i];
			end;
		end;
		if last.cod_venda then output;	
	run;
	/* PLIN */
	PROC SQL;
	   CREATE TABLE WORK.rel_dem_saldao01 AS 
	   SELECT distinct t1.COD_VENDA, 
	            (SUM(t1.estoque)) AS demanda_bruta_saldao,
		      t1.ANO*100+t1.CICLO AS CICLO,
			  t2.perc_ciclo as percentual_ciclo_saldao
	      FROM WORK.SALDAO t1
		  inner join saldao_01 t2 on t1.ano=t2.ano and t1.ciclo=t2.ciclo and t1.cod_cd= &cod_cd
	      GROUP BY t1.COD_VENDA, calculated ciclo;
	QUIT;
	/* Transpose*/
	data REL_DEM_SALDAO02(keep=COD_VENDA 
			%do i=1 %to &cnt;
				SALDAO_bruto_&&ciclo&i perc_SALDAO_&&ciclo&i SALDAO_&&ciclo&i
			%end;
			);
		format cod_venda 8.;
		format 
			%do i=1 %to &cnt;
				SALDAO_bruto_&&ciclo&i comma12. perc_SALDAO_&&ciclo&i percent8.2 SALDAO_&&ciclo&i comma12.
			%end;
			;
		set REL_DEM_SALDAO01;
		array SALDAO_bruto{*}
			%do i=1 %to &cnt; 
				SALDAO_bruto_&&ciclo&i
			%end;
			;
		array perc_SALDAO{*}
			%do i=1 %to &cnt; 
				perc_SALDAO_&&ciclo&i
			%end;
			;
		array SALDAO{*}
			%do i=1 %to &cnt; 
				SALDAO_&&ciclo&i
			%end;
			;
		by cod_venda;
		retain i SALDAO perc_SALDAO SALDAO_bruto;

		if first.cod_venda then do i=1 to dim(SALDAO);
			SALDAO_bruto[i] = .;
			perc_SALDAO[i] = .;
			SALDAO[i] = .;
		end;
		do i=1 to dim(SALDAO);
			anociclo=symget(compress('ciclo' || put(i,1.)));
			if ciclo=anociclo then do;
				SALDAO_bruto[i] = demanda_bruta_SALDAO;
				perc_SALDAO[i] = percentual_ciclo_SALDAO;
				SALDAO[i] = SALDAO_bruto[i]*perc_SALDAO[i];
			end;
		end;
		if last.cod_venda then output;	
	run;
	/* Junta os dois*/
	proc sort data=work.rel_dem_plin02;
		by cod_venda;
	quit;
	proc sort data=work.rel_dem_saldao02;
		by cod_venda;
	quit;
	data rel_dem01;
		merge rel_dem_plin02 rel_dem_saldao02;
		by cod_venda;
		format DEMANDA_TOTAL DEMANDA_TOTAL_BRUTA COMMA12.;
		DEMANDA_TOTAL = sum(
			%do i=1 %to &cnt;
				%if &i~=&cnt %then %do;
					SALDAO_&&ciclo&i, PLIN_&&ciclo&i,
				%end;
				%else %do;
					SALDAO_&&ciclo&i, PLIN_&&ciclo&i);
				%end;
			%end;
		DEMANDA_TOTAL_BRUTA = sum(
			%do i=1 %to &cnt;
				%if &i~=&cnt %then %do;
					SALDAO_BRUTO_&&ciclo&i, PLIN_BRUTO_&&ciclo&i,
				%end;
				%else %do;
					SALDAO_BRUTO_&&ciclo&i, PLIN_BRUTO_&&ciclo&i);
				%end;
			%end;
	run;
	PROC SQL;
	   CREATE TABLE WORK.REL_DEM02 AS 
	   SELECT t2.COD_VENDA, 
	          t2.DESCRICAO,
			  t2.TMAT
	      FROM WORK.REL_DEM01 t1
	           INNER JOIN WORK.CADASTRO_MATERIAIS t2 ON (t1.cod_venda = t2.COD_VENDA)
			ORDER BY t2.COD_VENDA;
	QUIT;
	DATA REL_DEM03;
		SET REL_DEM02;
		BY COD_VENDA;

		IF FIRST.COD_VENDA THEN OUTPUT;
	RUN;
	DATA WRSTEMP.BLS1_REL_DEMANDA_INICIAL;
		SET REL_DEM03; SET REL_DEM01(DROP=COD_VENDA);
	RUN;
	/* Tratar ZEST*/
	PROC SQL;
	   CREATE TABLE WORK.rel_DEM_ZEST01 AS 
	   SELECT DISTINCT t2.COD_VENDA,
	          t2.COD_VENDA_PAI,
	          t2.QTD,
	          t1.DEMANDA_TOTAL*t2.qtd AS DEMANDA
	      FROM WORK.rel_dem01 t1
	           INNER JOIN WORK.ZEST t2 ON (t1.cod_venda = t2.COD_VENDA_PAI)
	      ORDER BY t2.COD_VENDA;
	QUIT;
	PROC SQL;
	   CREATE TABLE WORK.REL_DEM_ZEST02 AS 
	   SELECT t1.COD_VENDA, 
	          /* COUNT_of_COD_VENDA_PAI */
	            (COUNT(t1.COD_VENDA_PAI)) AS COUNT_of_COD_VENDA_PAI
	      FROM WORK.REL_DEM_ZEST01 t1
	      GROUP BY t1.COD_VENDA;
	QUIT;
	%local zest_cnt;
	PROC SQL NOPRINT;
	   SELECT /* MAX_of_COUNT_of_COD_VENDA_PAI */
	            (MAX(t1.COUNT_of_COD_VENDA_PAI)) into :zest_cnt
	      FROM WORK.REL_DEM_ZEST02 t1;
	QUIT;
	%let zest_cnt=&zest_cnt;
	/* Transpose*/
	data REL_DEM_ZEST03;
		set REL_DEM_ZEST01;
		array ZEST[*] ZEST1-ZEST&zest_cnt; array qtdz[*] QTD1-QTD&zest_cnt; array DEM[*] DEM1-DEM&zest_cnt;
		by cod_venda;
		retain ZEST qtdz DEM j TOTAL;
		format DEM1-DEM&zest_cnt DEMANDA_TOTAL comma12.;

		if first.cod_venda then do i=1 to dim(ZEST);
			ZEST[i] = .;
			qtdz[i] = .;
			DEM[i] = .;
			j = 1;
			DEMANDA_TOTAL = 0;
		end;
		else j+1;
		ZEST[j] = cod_venda_pai;
		qtdz[j] = QTD;
		DEM[j] = demanda;
		DEMANDA_TOTAL + demanda;
		if last.cod_venda then
			output;
		keep cod_venda ZEST1-ZEST&zest_cnt QTD1-QTD&zest_cnt DEM1-DEM&zest_cnt DEMANDA_TOTAL;
	run;
	PROC SQL;
		CREATE TABLE REL_DEM_ZEST04 AS SELECT DISTINCT
			t1.COD_VENDA,
			t2.DESCRICAO,
			t2.TMAT
		FROM  REL_DEM_ZEST03 t1
		INNER JOIN CADASTRO_MATERIAIS t2 ON t1.COD_VENDA=t2.COD_VENDA;
	QUIT;
	DATA REL_DEM_ZEST05;
		SET REL_DEM_ZEST04;
		BY COD_VENDA;

		IF FIRST.COD_VENDA THEN OUTPUT;
	RUN;
	DATA WRSTEMP.BLS1_REL_DEMANDA_ZEST;
		SET REL_DEM_ZEST05; SET REL_DEM_ZEST03(DROP=COD_VENDA);
	RUN;
	/* Junta os dois*/
	data REL_DEMANDA_FINAL01;
		set REL_DEM_ZEST03(keep=COD_VENDA DEMANDA_TOTAL) 
			rel_dem01(keep=COD_VENDA DEMANDA_TOTAL);
	run;
	PROC SQL;
	   CREATE TABLE WORK.REL_DEMANDA_FINAL02 AS 
	   SELECT t1.COD_VENDA, 
	          /* SUM_of_DEMANDA_TOTAL */
	            (SUM(t1.DEMANDA_TOTAL)) FORMAT=COMMA12. AS DEMANDA_TOTAL
	      FROM WORK.REL_DEMANDA_FINAL01 t1
	      GROUP BY t1.COD_VENDA
	      ORDER BY t1.COD_VENDA;
	QUIT;
	PROC SQL;
		CREATE TABLE REL_DEMANDA_FINAL03 AS SELECT DISTINCT
			t1.COD_VENDA,
			t2.DESCRICAO,
			t2.TMAT
		FROM  REL_DEMANDA_FINAL02 t1
		INNER JOIN CADASTRO_MATERIAIS t2 ON t1.COD_VENDA=t2.COD_VENDA;
	QUIT;
	DATA REL_DEMANDA_FINAL04;
		SET REL_DEMANDA_FINAL03;
		BY COD_VENDA;

		IF FIRST.COD_VENDA THEN OUTPUT;
	RUN;
	DATA WRSTEMP.BLS1_REL_DEMANDA_FINAL(WHERE=(TMAT~='ZEST'));
		SET REL_DEMANDA_FINAL04; SET REL_DEMANDA_FINAL02(DROP=COD_VENDA);
	RUN;
%mend PRP_rel_demanda;

%macro PRP_mapaArea(cd);
	/* Gera tabelas: PRODUTO_AREA, DESCONTINUADOS e LANCAMENTOS. Entrada: PRODUTOS e MAPA*/
	PROC SQL;
	   CREATE TABLE WRSTEMP.BLS1_PRODUTO_AREA_&cd AS 
	   SELECT distinct
	            (COALESCE(t2.AREA,t1.AREA_ESTACAO)) AS AREA, 
	          t1.CANAL, 
	          t2.ESTACAO, 
	          t2.MODULO, 
	          t1.COD_VENDA, 
	          t1.MATERIAL, 
	          t1.DESCRICAO
	      FROM WORK.MAPA t1
	           LEFT JOIN WRSTEMP.BLE_ESTRUTURA_CD_&cd. t2 ON (t1.CANAL = t2.CANAL AND COD_CD=&cd)
	      ORDER BY AREA,
	               t1.CANAL,
	               t2.ESTACAO,
	               t2.MODULO;
	QUIT;
	/* material descontinuado*/
	PROC SQL;
	   CREATE TABLE WRSTEMP.BLS1_DESCONTINUADOS_&cd AS 
	   SELECT distinct t1.AREA, 
	          t1.CANAL, 
	          t1.COD_VENDA, 
	          t1.MATERIAL, 
	          t1.DESCRICAO
	      FROM WRSTEMP.BLS1_PRODUTO_AREA_&cd t1
	           LEFT JOIN WRSTEMP.BLS1_PRODUTOS_&cd t2 ON (t1.COD_VENDA = t2.COD_VENDA)
	      WHERE t2.COD_VENDA IS MISSING
	      ORDER BY t1.AREA,
	               t1.CANAL,
	               t1.COD_VENDA;
	QUIT;
	/* lançamentos */
	PROC SQL;
	   CREATE TABLE WRSTEMP.BLS1_LANCAMENTOS_&cd AS 
	   SELECT DISTINCT t1.COD_VENDA, 
	          t1.Material, 
	          t1.DESCRICAO
	      FROM WRSTEMP.BLS1_PRODUTOS_&cd t1
	           LEFT JOIN WRSTEMP.BLS1_PRODUTO_AREA_&cd t2 ON (t1.COD_VENDA = t2.COD_VENDA)
	      WHERE t2.COD_VENDA IS MISSING
	      ORDER BY t1.COD_VENDA;
	QUIT;
%mend PRP_mapaArea;
%macro PRP_abertura_canais(cd);
proc optmodel printlevel=0;
	/*Lê RESTRICAO_AREA*/
	set<str> AreaSet;
	read data WRSTEMP.BLE_RESTRICAO_AREA_&cd into AreaSet=[AREA];
	/*Lê PRODUTOS_&cd*/
	set<num,num> ProdutoSet;
	str descricao{ProdutoSet};
	num demanda{ProdutoSet};
	num demanda100{ProdutoSet};
	num comprimento{ProdutoSet};
	num largura{ProdutoSet};
	num altura{ProdutoSet};
	num volume{ProdutoSet};
	num itens_caixa{ProdutoSet};
	read data WRSTEMP.BLS1_PRODUTOS_&cd into ProdutoSet=[COD_VENDA MATERIAL] demanda=DEMANDA_PERC demanda100=DEMANDA_PERC_100
		descricao comprimento largura altura volume itens_caixa;
	/*Lê DESCONTINUADOS_&cd*/
	set<str,str,num,num> XDescSet;
	read data WRSTEMP.BLS1_DESCONTINUADOS_&cd into XDescSet=[AREA CANAL COD_VENDA MATERIAL]; 
	set DescSet = setof{<a,can,cv,mat> in XDescSet} <cv>;
	/*Lê PRODUTOS_AREA_&cd*/
	set<str,str,num,num> XProdutoAreaSet;
	str modulo{XProdutoAreaSet};
	read data WRSTEMP.BLS1_PRODUTO_AREA_&cd into XProdutoAreaSet=[AREA CANAL COD_VENDA MATERIAL] modulo;
	set<num,num,str> MapaSet = setof{<a,can,cv,mat> in XProdutoAreaSet: cv not in DescSet}<cv,mat,a>;
	/* Lê regra de abertura de canais*/
	set<str,str> AbreCanSet;
	num demanda_ini{AbreCanSet};
	num demanda_fim{AbreCanSet};
	num reposicao_ini{AbreCanSet};
	num reposicao_fim{AbreCanSet};
	num fxCardMod{AbreCanSet};
	num fxRepl{AbreCanSet};
	read data WRSTEMP.BLE_ABRE_CANAL_&cd. into AbreCanSet=[AREA FAIXA] demanda_ini demanda_fim reposicao_ini reposicao_fim
		fxCardMod=modulos fxRepl=canais_modulo;
		
	set ProdutoAreaSet = setof{<cv,mat> in ProdutoSet, a in AreaSet}<cv,mat,a>;

	num repl{ProdutoAreaSet} init 1;
	num cardMod{ProdutoAreaSet} init 1;
	num reposicao{ProdutoAreaSet} init 1;
	for{<cv,mat,a> in ProdutoAreaSet} do;
		for{<(a),fx> in AbreCanSet} do;
			if demanda_ini[a,fx] ~=  0 or demanda_fim[a,fx] ~= 0 then do;
				/* Faixa por demanda PBL*/
				if demanda_ini[a,fx] <= demanda[cv,mat] <= demanda_fim[a,fx] then do;
					repl[cv,mat,a] = fxRepl[a,fx];
					cardMod[cv,mat,a] = fxCardMod[a,fx];
					leave;
				end;
			end;
			else do;
				/* Faixa por demanda AFRAME*/
				reposicao[cv,mat,a] = demanda[cv,mat]*&produtividade./itens_caixa[cv,mat];
				if reposicao_ini[a,fx] <= reposicao[cv,mat,a] <= reposicao_fim[a,fx] then do;
					repl[cv,mat,a] = fxRepl[a,fx];
					cardMod[cv,mat,a] = fxCardMod[a,fx];
					leave;
				end;
			end;
		end;
	end;

	create data WRSTEMP.BLS1_REPLICACAO_&cd from [COD_VENDA MATERIAL AREA]={<cv,mat,a> in ProdutoAreaSet}
		demanda[cv,mat] repl cardMod reposicao;
quit;
%mend PRP_abertura_canais;
%macro PRP_verificaParametros;
	/*OBJ_MODULO*/
	proc sql noprint;
		create table PARAMETROS (
			COD_CD num format=BEST12.,
			DATA_INICIAL num format=DATE9.,
			DATA_FINAL num format=DATE9.,
			PRODUTIVIDADE num format=BEST12.,
			ITENS_POR_VOLUME num format=BEST12.,
			MAX_TROCA_AREA num format=BEST12.,
			MAX_TROCA_MODULO num format=BEST12.,
			MAX_TROCA_CANAL num format=BEST12.,
			ALOCA_AREA num format=BEST12.,
			ALOCA_MODULO num format=BEST12.,
			ALOCA_CANAL	num format=BEST12.,
			MAX_ITENS_AFRAME num format=BEST12.,
			MAX_ITENS_AFRAME_MAQ num format=BEST12.,
			ALT_COLUNA_AFRAME num format=BEST12.,
			REGRA_ESTOQUE char(30),			
			PREENCHE_MASS_PICKING num format=BEST12.);
	quit;
	%PRP_verificaTabela(WRSTEMP,BLE_PARAMETROS,erro,PARAMETROS)
%mend PRP_verificaParametros;
%macro PRP_Main;
	%let erros = 0;
	%LOG_Init
	/* Verifica ciclos envolvidos. Usa tabela PARAMETROS*/
	%PRP_verificaParametros
	%LOG_Erros(erros)
	%if &erros. ~=0 %then %do;
		Title "Erros nas entradas. Otimização não executada.";
		%LOG_Show;
		Title;
		%return;
	%end;
	%PRP_ciclosEnvolvidos(&data_ini, &data_fin, &cod_cd)
	/* Verifica se todas as informações estão disponíveis*/
	%PRP_verificaEntradas(work.ciclos,&cod_cd)
	/* Faz log*/
	%LOG_Executa

	/* Verifica se houve erro até aqui*/
	%LOG_Erros(erros)
	%if &erros ~= 0 %then %do;
		Title "Erros nas entradas. Otimização não executada.";
		%LOG_Show;
		Title;
	%end;
	%else %do;
		/* Faz previsão percentual por produto */
		%PRP_previsaoPercentual(&data_ini, &data_fin, &cod_cd)
		%LOG_prev
		/* Faz previsão diária por produto */
		%PRP_PrevisaoDiaria(&data_ini, &data_fin, &cod_cd)
		/* Mapa por área*/
		%PRP_mapaArea(&cod_cd)
		/* Verifica se tem produto incompatível na área*/
		%LOG_incomp
		/* Calcula abertura de canais*/
		%PRP_abertura_canais(&cod_cd)
		%if &erros ~= 0 %then %do;
			Title "Erros nas entradas. Otimização não executada.";
			%LOG_Show;
			Title;
		%end;
		%else %do;
			Title "Pré processamento executado com sucesso.";
			%LOG_Show;
			Title;
		%end;
	%end;
%mend PRP_Main;