*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_runall_1.sas                                                ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Run all SAS programs for the analysis of the PSY1001 study    ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...:                                                               ;
* Data created:                                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M0P061913                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
%inc saspgm(mebpoisint5) / source;  *-- Macro for splitting time for poisson regression;

/*
%inc saspgm(printto) /nosource;
%inc saspgm(cleanup) /nosource;
%inc saspgm(tit)     /nosource;
%inc saspgm(reset)   /nosource;
%inc saspgm(scapno)  /nosource;
*/

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;
options ls=130 ps=43 nodate nonumber nocenter source source2 nostimer msglevel=N
        notes dsnferr serror fmterr details
        mautosource nomstored mrecall
        fmtsearch=(work psfmt rsfmt)
        nomacrogen nosymbolgen nomtrace nomlogic nomprint
        mergenoby=WARN validvarname=upcase
        formchar='|----|+|---+=|-//<>*'
;

%reset(mode=3, reset=content pageno table prefix, gpageno=N);
options source source2;

*===================================================================;
* Data management                                                   ;
*===================================================================;
%printto(s_dm_ver1);
  options ls=135 ps=43 source source2;

  %inc saspgm(s_dm2);    *-- Data management;

  endrsubmit;

  %inc saspgm(s_fmt1);   *-- Define SAS formats to be used ;

  proc copy in=sasperm out=work;
  run;

%cleanup;


*----------------------------;
* Summary statistics         ;
*----------------------------;
*%reset(mode=3, reset=content pageno table prefix, gpageno=N);
*%printto(s_appendix_1_ver1);
*  options notes source source2;

*  %inc saspgm(s_missing) /source;     *-- Print missing value patterns;

*%cleanup(content=Y);


*----------------------------------------------;
* Statistical analysis: SAS output and figures ;
*----------------------------------------------;
%printto(s_appendix_2_ver1);
  options ls=160 ps=43 notes source source2;

  %inc saspgm(s_poana_long1) /source;  *-- Poisson regression -12 to +12 month;

  %inc saspgm(s_poana_ppd1) /source;   *-- Poisson regression PPD starting follow-up from birth;

%cleanup(content=Y);



*--------------------------------------;
* Statistical analysis: Nice printouts ;
*--------------------------------------;
%printto(s_appendix_3_ver1);
  options ls=135 ps=43 notes source source2;

  %inc saspgm(s_niceprt1) /source;    *-- Print rates by ART and by IVFCODE ;

%cleanup(content=Y);



*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete _null_;
quit;
*-- End of File --------------------------------------------------------------;
