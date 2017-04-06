%let cod_cd = 5700;
libname SIMULA "C:\Users\Fabio\Documents\Logical\Projetos\Natura - Balanceamento\Desenvolvimento\Dados Balanceamento";
libname WRSTEMP "C:\Users\Fabio\Documents\Logical\Projetos\Natura - Balanceamento\Desenvolvimento\Dados\&cod_cd";
/*libname WRSTEMP "C:\Users\Fabio\Documents\Logical\Projetos\Natura - Balanceamento\Desenvolvimento\Dados";*/
/* Classe Main*/
%let CLASS_PATH= C:\Users\Fabio\Google Drive\Projetos\Natura\Balanceamento\Programas\v1.03;
/*%let CLASS_PATH=/sas/users/ffranca/balanceamento/v0.03;*/
options mprint symbolgen mlogic;
%include "&CLASS_PATH/BALLog.sas";
%include "&CLASS_PATH/BALPreProc.sas";
%include "&CLASS_PATH/BALAlocaArea.sas";
%include "&CLASS_PATH/BALAlocaModulo.sas";
%include "&CLASS_PATH/BALAlocaCanal.sas";
%include "&CLASS_PATH/BALPosProc.sas";

%macro main;
	%global erros cod_cd data_ini data_fin produtividade prev_itens_volume max_troca_area
			exec_aloca_area exec_aloca_modulo exec_aloca_canal max_itens_aframe max_itens_aframe_maq alt_coluna_aframe regra_estoque
			preenche_mpick;
	PROC SQL NOPRINT;
		SELECT DATA_INICIAL, DATA_FINAL, PRODUTIVIDADE, ITENS_POR_VOLUME, MAX_TROCA_AREA, 
			   ALOCA_AREA, ALOCA_MODULO, ALOCA_CANAL, MAX_ITENS_AFRAME, MAX_ITENS_AFRAME_MAQ, ALT_COLUNA_AFRAME, REGRA_ESTOQUE,
			   PREENCHE_MASS_PICKING
			INTO :data_ini, :data_fin, :produtividade, :prev_itens_volume, :max_troca_area,
				:exec_aloca_area, :exec_aloca_modulo, :exec_aloca_canal, :max_itens_aframe, :max_itens_aframe_maq, :alt_coluna_aframe, 
				:regra_estoque, :preenche_mpick
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
