libname SIMULA "D:\SASCONFIG\Lev1\SASApp\Data\natura\balanceamento_compartilhado";
libname WRSTEMP "D:\SASCONFIG\Lev1\SASApp\Data\natura\balanceamento_compartilhado\&cod_cd";
/* Classe Main*/
/*%let CLASS_PATH= C:\Users\Fabio\Google Drive\Projetos\Natura\Balanceamento\Programas\v1.01;*/
%let CLASS_PATH=D:\SASCONFIG\Lev1\SASApp\Data\natura\balanceamento_compartilhado\REPOSITORIO STP;
/*options mprint symbolgen mlogic;*/
%include "&CLASS_PATH/BALLog_v1.09.sas";
%include "&CLASS_PATH/BALPreProc_v1.09.sas";
%include "&CLASS_PATH/BALAlocaArea_v1.07.sas";
%include "&CLASS_PATH/BALAlocaModulo_v1.09.sas";
%include "&CLASS_PATH/BALAlocaCanal_v1.08.sas";
%include "&CLASS_PATH/BALPosProc_v1.06.sas";

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