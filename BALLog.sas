/* Classe:LOG*/
%macro LOG_init;
	/* Inicializa tabela de logs => WORK.LOG*/
	proc sql;
		create table WRSTEMP.BLS1_LOG
			(TIPO CHAR(10),
			DESCRICAO CHAR(150),
			TABELA1 CHAR(30),
			TABELA2 CHAR(30));
	quit;
%mend LOG_init;
%macro LOG_Insere(tipo, desc, tab1, tab2);
	proc sql;
		insert into WRSTEMP.BLS1_LOG 
			set tipo="&tipo", descricao="&desc", tabela1="&tab1", tabela2="&tab2";
	quit;
%mend LOG_Insere;
%macro LOG_InsereTabela(tab_erros);
	proc sql;
		insert into WRSTEMP.BLS1_LOG 
			select * from &tab_erros;
	quit;
%mend LOG_InsereTabela;
%macro LOG_Show;
	proc sql;
		select * from WRSTEMP.BLS1_LOG;
	quit;
%mend LOG_Show;
%macro LOG_Erros(var);
	%local cnt;
	proc sql noprint;
		select count(*) into :cnt from WRSTEMP.BLS1_LOG where tipo="ERRO";
	quit;
	%let &var=&cnt;
%mend LOG_Erros;
%macro LOG_Mapa(erro);
	/* Faz log MAPA*/
	%local cnt_ini cnt_fin;
	PROC SQL NOPRINT;
		select count(*) into :cnt_ini from WRSTEMP.BLS1_LOG;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto '" || trim(put(t1.material,8.)) || "-" || 
				trim(t1.descricao) || "' não encontrado." AS DESCRICAO,
			'MAPA' AS TABELA1,
			'CADASTRO_MATERIAIS' AS TABELA2
		FROM MAPA t1
		LEFT JOIN SIMULA.BLE_CADASTRO_MATERIAIS t2 ON(t1.material=t2.Material)
		WHERE t2.Material IS MISSING;
		select count(*) into :cnt_fin from WRSTEMP.BLS1_LOG;
	QUIT;
	%let &erro = %eval(&cnt_fin - &cnt_ini);
%mend LOG_Mapa;

%macro LOG_Executa;
	/*ZEST: log Material xxxxxx-yyyyyyyyy filho de xxxxx sem código de vendas.*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'AVISO' AS TIPO,
			"Material '" || trim(put(t1.MATERIAL,8.)) || "-" || trim(t1.DESCRICAO) || 
				" filho de '" || compress(put(t1.cod_venda_pai,8.)) ||"' sem código de vendas." AS DESCRICAO,
			t1.TABELA AS TABELA1,
			'N/A' AS TABELA2
	      FROM WORK.ZEST t1
	      WHERE t1.COD_VENDA IS MISSING;
	QUIT;
	/* Retira de ZEST com cod_venda missing*/
	data zest_org;
		set zest;
	run;
	data zest;
		set zest_org;
		where cod_venda ~= .;
	run;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto '" || trim(put(t1.COD_VENDA,8.)) || "' não encontrado." AS DESCRICAO,
			t1.tabela AS TABELA1,
			'CADASTRO_MATERIAIS' AS TABELA2
		FROM ZEST t1
		left JOIN CADASTRO_MATERIAIS t2 ON(t1.COD_VENDA=t2.COD_VENDA)
		WHERE t2.COD_VENDA is missing;
	QUIT;
/* Faz log PLIN*/
/* Tira todo plin que seja pai*/
	PROC SQL;
	   CREATE TABLE WORK.PLIN_SEM_PAI AS 
	   SELECT DISTINCT t1.COD_VENDA, 
	          t1.DESCRICAO, 
	          t1.TABELA
	      FROM WORK.PLIN t1
	           LEFT JOIN WORK.ZEST t2 ON (t1.COD_VENDA = t2.COD_VENDA_PAI)
	      WHERE t2.COD_VENDA IS MISSING;
	QUIT;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto '" || compress(put(t1.COD_VENDA,8.)) || "-" || trim(t1.DESCRICAO) || "' não encontrado." AS DESCRICAO,
			t1.TABELA AS TABELA1,
			'CADASTRO_MATERIAIS' AS TABELA2
		FROM PLIN_SEM_PAI t1
		LEFT JOIN CADASTRO_MATERIAIS t2 ON(t1.COD_VENDA=t2.COD_VENDA)
		WHERE t2.COD_VENDA IS MISSING;
	QUIT;	

	/* Log ZEST*/

	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto(ZEST) '" || trim(put(t1.COD_VENDA,8.)) || "-" || trim(t1.DESCRICAO) || "' não encontrado." AS DESCRICAO,
			t1.tabela AS TABELA1,
			'ZEST' AS TABELA2
		FROM PLIN t1
		left JOIN CADASTRO_MATERIAIS t2 ON(t1.COD_VENDA=t2.COD_VENDA)
		left JOIN ZEST t3 ON(t1.COD_VENDA=t3.COD_VENDA_PAI)
		WHERE t2.TMat = 'ZEST' and t3.COD_VENDA_PAI is missing;
	QUIT;	


	/* Log SALDAO*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto '" || trim(put(t1.COD_VENDA,8.)) || "-" ||
				trim(t1.DESCRICAO) || "' não encontrado." AS DESCRICAO,
			t1.TABELA AS TABELA1,
			'CADASTRO_MATERIAIS' AS TABELA2
		FROM SALDAO t1
		LEFT JOIN CADASTRO_MATERIAIS t2 ON(t1.COD_VENDA=t2.COD_VENDA)
		WHERE t2.COD_VENDA IS MISSING;
	QUIT;
	/* Se tiver algum ZEST em SALDAO*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto (ZEST)'" || trim(put(t1.COD_VENDA,8.)) || "-" ||
				trim(t1.DESCRICAO) || "' não encontrado." AS DESCRICAO,
			t1.TABELA AS TABELA1,
			'ZEST' AS TABELA2
		FROM SALDAO t1
		left JOIN CADASTRO_MATERIAIS t2 ON(t1.COD_VENDA=t2.COD_VENDA)
		left JOIN ZEST t3 ON(t1.COD_VENDA=t3.COD_VENDA_PAI)
		WHERE t2.TMat = 'ZEST' and t3.COD_VENDA_PAI is missing;
	QUIT;
	/*Saldão sem estoque*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto '" || trim(left(put(t1.COD_VENDA,8.))) || "-" ||
				trim(t1.DESCRICAO) || "' sem estoque." AS DESCRICAO,
			t1.TABELA AS TABELA1,
			'N/A' AS TABELA2
		FROM SALDAO t1
		WHERE t1.estoque is missing and t1.cod_cd=&cod_cd.;
	QUIT;
	
	/* Log ESTOQUE*/
	PROC SQL;
	   CREATE TABLE WORK.ESTOQUE2 AS 
	   SELECT DISTINCT t2.COD_VENDA, 
	          t2.MATERIAL, 
	          t2.Tmat
	      FROM WORK.ESTOQUE t1
			   INNER JOIN CADASTRO_MATERIAIS t2 ON(t1.MATERIAL=t2.MATERIAL)
	      ;
	QUIT;
/* Não ativar este log. Na hora do planejamento alguns produtos ainda estão sem estoque!*/
/*	PROC SQL;*/
/*		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT*/
/*			'ERRO' AS TIPO,*/
/*			"Produto '" || strip(put(t1.COD_VENDA,8.)) || "-" || trim(t1.DESCRICAO) || "' não encontrado." AS DESCRICAO,*/
/*			t1.TABELA AS TABELA1,*/
/*			'ESTOQUE' AS TABELA2*/
/*		FROM PLIN_SEM_PAI t1*/
/*		left JOIN ESTOQUE2 t3 ON(t1.COD_VENDA=t3.COD_VENDA)*/
/*		WHERE t3.TMat ~= 'ZEST' and t3.COD_VENDA is missing;*/
/*	QUIT;	*/

/* Log PAPER*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Produto '" || compress(put(t1.COD_VENDA,8.)) || "/" ||compress(put(t1.MATERIAL,8.)) || "-" || trim(t1.DESCRICAO) || "' não encontrado." AS DESCRICAO,
			t1.TABELA AS TABELA1,
			'CADASTRO_MATERIAIS' AS TABELA2
		FROM PAPER t1
		LEFT JOIN CADASTRO_MATERIAIS t2 ON(t1.COD_VENDA=t2.COD_VENDA AND t1.MATERIAL=t2.MATERIAL)
		WHERE t2.MATERIAL IS MISSING and cod_cd = &cod_cd.;
	QUIT;	
	/* Qtd de canais em RESTRICAO_AREA*/
	proc sql noprint;
		select count(memname) into :existe
			from dictionary.tables
			where libname="WRSTEMP" and memname="BLE_ESTRUTURA_AFRAME_&cod_cd.";
	quit;	
	%if &existe. = 1 %then %do;
		PROC SQL;
			CREATE TABLE WORK.CAP_AREA AS 
				SELECT t1.AREA,
					CASE
						WHEN t1.AREA IN ('AFRAME','AFRAME MAQ') THEN COUNT(DISTINCT(t2.CANAL_VIRTUAL))
						ELSE (COUNT(t1.CANAL)) 
					END AS COUNT_of_CANAL
				FROM WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t1
				LEFT JOIN WRSTEMP.BLE_ESTRUTURA_AFRAME_&cod_cd. t2 ON t1.CANAL=t2.CANAL
					WHERE t1.ESTACAO = 1 AND t1.STATUS = '' AND t2.STATUS NOT = 'INDISPONÍVEL'
					GROUP BY t1.AREA;
		QUIT;
	%end; %else %do;
		PROC SQL;
		   CREATE TABLE WORK.CAP_AREA AS 
		   SELECT t1.AREA, 
		          /* COUNT_of_CANAL */
		            (COUNT(t1.CANAL)) AS COUNT_of_CANAL
		      FROM WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t1
		      WHERE t1.ESTACAO = 1 AND t1.STATUS NOT = 'INDISPONÍVEL'
		      GROUP BY t1.AREA;
		QUIT;
	%end;
	PROC SQL;
	   CREATE TABLE WORK.ERR_CAP_AREA AS 
	   SELECT t1.AREA, 
	          t1.CAPACIDADE, 
	          coalesce(t2.COUNT_of_CANAL, 0) as COUNT_of_CANAL, 
	          /* DIFERENCA */
	            (t1.CAPACIDADE~=coalesce(t2.COUNT_of_CANAL, 0)) AS DIFERENCA
	      FROM WRSTEMP.BLE_RESTRICAO_AREA_&cod_cd. t1
	           left JOIN WORK.CAP_AREA t2 ON (t1.AREA = t2.AREA)
	      WHERE (CALCULATED DIFERENCA) = 1 and (CALCULATED COUNT_of_CANAL) ~= 0;
	QUIT;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Area '" || t1.AREA || "' capacidade (" || strip(put(t1.CAPACIDADE,8.)) || ") diferente de n canais (" 
				|| strip(put(t1.COUNT_of_CANAL,8.)) || ")." AS DESCRICAO,
			'RESTRICAO_AREA' AS TABELA1,
			'ESTRUTURA_CD' AS TABELA2
		FROM ERR_CAP_AREA t1;
	QUIT;
/* Área com Capacidade = 0 objArea = 0*/
	PROC SQL;
	   INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Area '" || t1.AREA || "' capacidade (" || strip(put(t1.CAPACIDADE,8.)) || ") incompatível com obj (" 
				|| strip(put(t2.OBJETIVO,PERCENT8.2)) || ")." AS DESCRICAO,
			'RESTRICAO_AREA' AS TABELA1,
			'OBJ_AREA' AS TABELA2
	      FROM WRSTEMP.BLE_RESTRICAO_AREA_&cod_cd. t1
	           INNER JOIN WRSTEMP.BLE_OBJ_AREA_&cod_cd. t2 ON (t1.AREA = t2.AREA)
	      WHERE t1.CAPACIDADE = 0 AND t2.OBJETIVO NOT = 0;
	QUIT;
/* Mapa com área inexistente em restrição área*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) ||"' não encontrada." AS DESCRICAO,
			'MAPA' AS TABELA1,
			'RESTRICAO_AREA' AS TABELA2
		FROM WRSTEMP.BLE_MAPA_&cod_cd. t1
		LEFT JOIN WRSTEMP.BLE_RESTRICAO_AREA_&cod_cd. t2 ON(t1.AREA=t2.AREA)
		WHERE t2.AREA IS MISSING;
	QUIT;
/* Obj módulo com área módulo não encontrados em estrutura_cd*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) ||"' Módulo '" || trim(t1.modulo) || "' não encontrados." AS DESCRICAO,
			'OBJ_MODULO' AS TABELA1,
			'ESTRUTURA_CD' AS TABELA2
	      FROM WRSTEMP.BLE_OBJ_MODULO_&cod_cd. t1
	           LEFT JOIN WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t2 ON (t1.AREA = t2.AREA) AND (t1.MODULO = t2.MODULO)
	      WHERE t2.MODULO IS MISSING;
	QUIT;
/* Módulo em ESTRUTURA_CD não encontrado em OBJ_MODULO*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) ||"' Módulo '" || trim(t1.modulo) || "' não encontrados." AS DESCRICAO,
			'ESTRUTURA_CD' AS TABELA1,
			'OBJ_MODULO' AS TABELA2
	      FROM WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t1
	           LEFT JOIN WRSTEMP.BLE_OBJ_MODULO_&cod_cd. t2 ON (t1.AREA = t2.AREA) AND (t1.MODULO = t2.MODULO)
	      WHERE t1.ESTACAO = 1 AND t2.MODULO IS MISSING;
	QUIT;
/* Área em ESTRUTURA_CD não encontrado em OBJ_AREA*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) || "' não encontrada." AS DESCRICAO,
			'ESTRUTURA_CD' AS TABELA1,
			'OBJ_AREA' AS TABELA2
	      FROM WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t1
	           LEFT JOIN WRSTEMP.BLE_OBJ_AREA_&cod_cd. t2 ON (t1.AREA = t2.AREA)
	      WHERE t1.ESTACAO = 1 AND t2.AREA IS MISSING;
	QUIT;
/* Classificação de canal não reconhecida*/
	PROC SQL;
	   CREATE TABLE WORK.QUERY_FOR_BLE_ESTRUTURA_CD1 AS 
	   SELECT t1.AREA, 
	          t1.MODULO, 
	          t1.CANAL, 
	          t1.CLASSIFICACAO
	      FROM WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t1
	      WHERE t1.AREA CONTAINS 'PBL' AND t1.ESTACAO = 1 AND t1.STATUS = '' AND t1.CLASSIFICACAO NOT IN 
	           ('AA','A','B','C','D','E','F');
	QUIT;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) ||"' Módulo '" || trim(t1.modulo) || 
			"' Canal '" || trim(t1.canal) || "' Classificação '" || trim(t1.classificacao) || "' inválida." AS DESCRICAO,
			'ESTRUTURA_CD' AS TABELA1,
			'N/A' AS TABELA2
	      FROM WORK.QUERY_FOR_BLE_ESTRUTURA_CD1 t1;
	QUIT;
/* Replicação > 0*/
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) || "' com REPLICAÇÃO(0) inválida." AS DESCRICAO,
			'BLE_RESTRICAO_AREA' AS TABELA1,
			'N/A' AS TABELA2
	      FROM WRSTEMP.BLE_RESTRICAO_AREA_&cod_cd. t1
	      WHERE t1.REPLICACAO = 0;
	QUIT;
/* XY duplicados em ESTRUTURA_CD*/
	PROC SQL;
	   CREATE TABLE WORK.XYDUPL_01 AS 
	   SELECT DISTINCT t1.AREA, 
	          t1.MODULO, 
	          /* XY */
	            (t1.X * 10+t1.Y) AS XY, 
	          /* COUNT_of_CANAL */
	            (COUNT(t1.CANAL)) AS COUNT_of_CANAL
	      FROM WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd t1
	      WHERE t1.ESTACAO = 1 AND t1.STATUS = '' AND t1.X NOT IS MISSING AND t1.Y NOT IS MISSING
	      GROUP BY t1.AREA,
	               t1.MODULO,
	               (CALCULATED XY)
	      HAVING (CALCULATED COUNT_of_CANAL) > 1;
	QUIT;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'ERRO' AS TIPO,
			"Área '" || trim(t1.area) ||"' Módulo '" || trim(t1.modulo) || "' com XY repetido." AS DESCRICAO,
			'ESTRUTURA_CD' AS TABELA1,
			'N/A' AS TABELA2
	      FROM WORK.XYDUPL_01 t1;
	QUIT;
%mend LOG_executa;

%macro LOG_incomp;
/* Aviso: produto alocado em área incompatível. Movimentação não será contabilizada em trocas.*/
	PROC SQL;
	   CREATE TABLE WORK.PRODUTO_AREA_INCOMPATIVEL AS 
	   SELECT DISTINCT t1.COD_VENDA, 
	          t1.DESCRICAO, 
	          t1.AREA
	      FROM WRSTEMP.BLS1_PRODUTO_AREA_&cod_cd. t1, WRSTEMP.BLE_INCOMPATIBILIDADE_&cod_cd. t2
	      WHERE (t1.COD_VENDA = t2.COD_VENDA AND (
			(t1.AREA = 'Robô-Pick' AND t2.'ROBÔ-PICK'n='x') or
			(t1.AREA = 'AFRAME' AND t2.AFRAME='x') or
			(t1.AREA = 'AFRAME MAQ' AND t2.'AFRAME MAQ'n='x')));
	QUIT;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'AVISO' AS TIPO,
			"Produto '" || compress(put(t1.cod_venda,8.)) || "-" || trim(t1.DESCRICAO) || 
			"' alocado em área(" || trim(t1.AREA) || ") incompatível. Movimentação não será contabilizada em trocas." AS DESCRICAO,
			'BLE_MAPA' AS TABELA1,
			'INCOMPATIBILIDADE' AS TABELA2
		FROM PRODUTO_AREA_INCOMPATIVEL t1;
	QUIT;	
/*  Para o nível do PBL*/
	PROC SQL;
	   CREATE TABLE WORK.PRODUTO_PBL_INCOMPATIVEL AS 
	   SELECT t3.COD_VENDA, 
	          t3.'DESCRIÇÃO MATERIAL'n as DESCRICAO, 
	          t1.CANAL, 
	          t3.NIVEL_PBL
	      FROM WRSTEMP.BLE_MAPA_&cod_cd. t1, WRSTEMP.BLE_ESTRUTURA_CD_&cod_cd. t2, WRSTEMP.BLE_INCOMPATIBILIDADE_&cod_cd. t3,
		  	WRSTEMP.BLS1_PRODUTO_AREA_&cod_cd. t4
	      WHERE (t1.AREA = t2.AREA AND t1.CANAL = t2.CANAL AND (t2.ESTACAO=1) AND t1.MATERIAL=t4.MATERIAL AND 
			t4.COD_VENDA=t3.COD_VENDA AND t2.Y = t3.NIVEL_PBL and t3.NIVEL_PBL is not missing);
	QUIT;
	PROC SQL;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT DISTINCT
			'AVISO' AS TIPO,
			"Produto '" || compress(put(t1.cod_venda,8.)) || "-" || trim(t1.DESCRICAO) || 
			"' alocado no PBL em nível(" || put(t1.NIVEL_PBL,1.) || ") incompatível. Movimentação não será contabilizada em trocas." AS DESCRICAO,
			'BLE_MAPA' AS TABELA1,
			'INCOMPATIBILIDADE' AS TABELA2
		FROM PRODUTO_PBL_INCOMPATIVEL t1;
	QUIT;	
%mend LOG_incomp;

%macro LOG_prev;
	PROC SQL;
		CREATE TABLE WORK.LOG_PREV_00 AS 
			SELECT t1.RE, 
				t1.COD_CD, 
				t1.ANO, 
				t1.CICLO, 
				t1.DEMANDA_PERC
			FROM WORK.PREV_PERC_03 t1
				WHERE t1.DEMANDA_PERC = 0;
	QUIT;

	PROC SQL;
		create table erro_prev as select distinct
			'ERRO' AS TIPO,
			"Região (" || compress(RE) || ") CD (" || compress(put(COD_CD,4.)) || ") CICLO (" || compress(put(CICLO,z2.)) || "). Sem demanda (VOLUME_SEPARADO)." AS DESCRICAO,
			'BLE_SAIDA_DEMANDA_DETALHADA' AS TABELA1,
			'N/A' AS TABELA2
	      FROM WORK.LOG_PREV_00 t1;
	QUIT;
	PROC SQL noprint;
		select count(*) into :erros from erro_prev;
	QUIT;
%if &erros. > 0 %then %do;
	proc sql;
		INSERT INTO WRSTEMP.BLS1_LOG SELECT * from erro_prev;
	quit;
	proc sort data=WRSTEMP.BLS1_LOG;
		by DESCENDING tipo;
	run;
%end;
%mend LOG_prev;