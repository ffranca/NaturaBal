%macro posProc(CD);
/* Fazer novo mapa da linha ==> demanda soma 100%*/
/* Robô-Pick e SCS não têm módulo*/
PROC SQL;
   CREATE TABLE WORK.MAPA_01 AS 
   SELECT t1.AREA length=15, 
          /* MODULO */
            ('') length=20 AS MODULO, 
          /* CANAL */
            ('') length=11 AS CANAL, 
          /* CLASSIFICACAO */
            ('') length=10 AS CLASSIFICACAO, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.descricao length=40, 
          t1.DEMANDA AS DEMANDA_VENDA
      FROM WRSTEMP.BLS2_SOL_MAPA3 t1
      WHERE t1.AREA IN ('SCS','Robô-Pick');
QUIT;
/* Paper dispenser: alocar canais*/
PROC SQL;
   CREATE TABLE WORK.MAPA_01a AS 
   SELECT t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.AREA, 
          t1.descricao length=40, 
          t1.demanda as DEMANDA_VENDA
      FROM WRSTEMP.BLS2_SOLUCAO_AREA t1
      WHERE t1.AREA = 'PAPER DISPENSER';
QUIT;
PROC SQL;
   CREATE TABLE WORK.MAPA_01b AS 
   SELECT t1.AREA, 
          t1.MODULO, 
          t1.CANAL LENGTH=11, 
          t1.CLASSIFICACAO
      FROM WRSTEMP.BLE_ESTRUTURA_CD_&cd. t1
      WHERE t1.AREA = 'PAPER DISPENSER';
QUIT;
DATA MAPA_01c;
	set MAPA_01b; set MAPA_01a;
RUN;
/* O resto tem*/
PROC SQL;
   CREATE TABLE WORK.MAPA_02 AS 
   SELECT t1.AREA length=15, 
          /* MODULO */
          t1.MODULO LENGTH=20, 
          /* CANAL */
          t1.CANAL length=11, 
          /* CLASSIFICACAO */
          t1.CLASSIFICACAO length=10, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.descricao  length=40, 
          t1.DEMANDA AS DEMANDA_VENDA
      FROM WRSTEMP.BLS4_SOLUCAO_CANAL t1;
QUIT;
DATA MAPA_03;
	SET MAPA_01 MAPA_01c MAPA_02;
RUN;
proc sql;
	create table MAPA_04 as
		select cod_venda, count(*) as mat_cnt
		from MAPA_03
		group by cod_venda;
quit;
/* Inclui os produtos do paper dispenser em PRODUTOS: não é necessário*/

/*PROC SORT DATA=MAPA_01c;*/
/*	BY COD_VENDA MATERIAL;*/
/*QUIT;*/
/*PROC SORT DATA=WRSTEMP.BLS1_PRODUTOS_&CD;*/
/*	BY COD_VENDA MATERIAL;*/
/*QUIT;*/
/**/
/*DATA PRODUTOS;*/
/*	MERGE WRSTEMP.BLS1_PRODUTOS_&CD MAPA_01c(RENAME=(DEMANDA_VENDA=DEMANDA) DROP=AREA MODULO CANAL CLASSIFICACAO);*/
/*	BY COD_VENDA MATERIAL;*/
/*RUN;*/
DATA PRODUTOS;
	set WRSTEMP.BLS1_PRODUTOS_&CD;
RUN;

PROC SQL;
   CREATE TABLE WRSTEMP.BLS5_NOVO_MAPA_&CD AS 
   SELECT t1.AREA, 
          t1.MODULO, 
          t1.CANAL, 
          t1.CLASSIFICACAO, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.descricao, 
          t1.DEMANDA_VENDA AS DEMANDA_PERC_VENDA, 
          /* DEMANDA_CANAL */
            (t1.DEMANDA_VENDA / t2.mat_cnt) AS DEMANDA_PERC_CANAL,
		  t3.DEMANDA AS DEMANDA_VENDA,
		  t2.MAT_CNT AS NCANAIS
      FROM WORK.MAPA_03 t1
           INNER JOIN WORK.MAPA_04 t2 ON (t1.COD_VENDA = t2.COD_VENDA)
           INNER JOIN WORK.PRODUTOS t3 ON (t1.COD_VENDA = t3.COD_VENDA and t1.MATERIAL=t3.MATERIAL)
		ORDER BY AREA,MODULO,CANAL;
QUIT;

/* Agora as movimentações*/
PROC SQL;
   CREATE TABLE WORK.PROD_AREA_1 AS 
   SELECT t1.*
      FROM WRSTEMP.BLS1_PRODUTO_AREA_&cd t1
      WHERE t1.ESTACAO = 1 or (t1.area in ('SCS','Robô-Pick') and t1.ESTACAO is missing);
QUIT;
/* Produtos faltantes*/
PROC SQL;
   CREATE TABLE WORK.PROD_AREA_2 AS 
   SELECT DISTINCT t1.AREA, 
          t1.CANAL, 
          t1.ESTACAO, 
          t1.MODULO, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.DESCRICAO
      FROM WRSTEMP.BLS1_PRODUTO_AREA_&cd. t1
           LEFT JOIN WORK.PROD_AREA_1 t2 ON (t1.COD_VENDA = t2.COD_VENDA)
      WHERE t2.COD_VENDA IS MISSING
      ORDER BY t1.COD_VENDA,
               t1.AREA,
               t1.ESTACAO;
QUIT;
/* Seleciona os primeiros*/
data PROD_AREA_3;
	set prod_area_2;
	by COD_VENDA AREA;

	if first.area then output;
run;
data prod_area;
	set prod_area_1 prod_area_3;
run;
/* Fazer de-para de prosutos que não mudaram de canal*/
PROC SQL;
   CREATE TABLE depara_01 AS 
   SELECT DISTINCT t2.AREA AS AREA_ORG, 
          t1.AREA, 
          t2.MODULO AS MODULO_ORG, 
          t1.MODULO, 
          t2.CANAL AS CANAL_ORG, 
          t1.CANAL, 
          t1.CLASSIFICACAO, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.descricao, 
          t1.DEMANDA_PERC_VENDA, 
          t1.DEMANDA_PERC_CANAL, 
          t1.DEMANDA_VENDA, 
          IFN(t2.AREA=t1.AREA AND t2.MODULO=t1.MODULO AND t2.CANAL=t1.CANAL,0,1) AS MOVIMENTACAO, 
          t1.NCANAIS
      FROM WRSTEMP.BLS5_NOVO_MAPA_&CD t1
           inner JOIN PROD_AREA t2 ON (t1.COD_VENDA = t2.COD_VENDA and t1.material=t2.material and t1.canal=t2.canal)
	ORDER BY t1.AREA,t1.MODULO,t1.CANAL;
QUIT;
/* Pega o que sobrou no mapa*/
proc sql;
	create table depara_02 as select distinct 
   		  t1.AREA, 
          t1.MODULO, 
          t1.CANAL, 
          t1.CLASSIFICACAO, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.descricao, 
          t1.DEMANDA_PERC_VENDA, 
          t1.DEMANDA_PERC_CANAL, 
          t1.DEMANDA_VENDA, 
          t1.NCANAIS
    from WRSTEMP.BLS5_NOVO_MAPA_&cd. t1
	left join depara_01 t2 on (t1.COD_VENDA = t2.COD_VENDA and t1.material=t2.material and t1.canal=t2.canal)
	where t2.cod_venda is missing order by material;
quit;
/* pega o que sobrou de mapa anterior*/
proc sql;
	create table depara_03 as select distinct 
   		  t1.AREA as AREA_ORG, 
          t1.MODULO AS MODULO_ORG, 
          t1.CANAL AS CANAL_ORG, 
          t1.COD_VENDA, 
          t1.MATERIAL, 
          t1.descricao length=40
	from PROD_AREA t1
	left join depara_01 t2 on (t1.COD_VENDA = t2.COD_VENDA and t1.material=t2.material and t1.canal=t2.canal)
	where t2.cod_venda is missing 
	order by material;
quit;
/* Junta novamente*/
data DEPARA_04;
	merge depara_03(in=B) depara_02(in=a);
	by material;
	retain cn;

	if area not in ('SCS','Robô-Pick') and canal = cn then do;
		cn = canal;
		area = '';
		modulo = '';
		canal = '';
		DEMANDA_PERC_VENDA = .; 
		DEMANDA_PERC_CANAL = .;
		DEMANDA_VENDA = .; 
		CLASSIFICACAO = '';
	end;
	else cn = canal;
	movimentacao=1;
/*	if a;*/
run;
/* Faz tabela final*/
data WRSTEMP.BLS5_BALANCEAMENTO;
	set depara_01 depara_04;
run;
proc sort data=WRSTEMP.BLS5_BALANCEAMENTO;
	by cod_venda area modulo canal;
run;
%mend posProc;

