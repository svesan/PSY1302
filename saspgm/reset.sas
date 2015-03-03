options nosource;
%macro reset(__func__,mode=, reset=, pageno=, app=, section=, subsec=, formchar=ANSI,
             options=Y, gpageno=Y, prefix=, cgmname=, titmode=3, gdisplay=N)
             /des='SCA macro RESET 3.0';

%*---------------------------------------------------------------------------------------;
%* Updated      Action
%*---------------------------------------------------------------------------------------;
%* 97-06-10 (a) Previous version mode=1 default. Now mode is blank. If blank mode is set ;
%*              to set to _lcbmod_ value. If _lcbmod_ blank as well mode set to 1.       ;
%*          (b) Version 1.0 retained / SSANDIN                                           ;
%*---------------------------------------------------------------------------------------;
%* 98-07-02 (a) The length of variable TABLE in dataset _ISRCON_ changed from 10 to 20   ;
%*          (b) The parameter PREFIX added. Used by the simultansously updated TIT macro ;
%*          (c) Version 1.0 retained / SSANDIN                                           ;
%*---------------------------------------------------------------------------------------;
%* 98-07-06 (a) The RESET=CGM functionallity was added to the macro.                     ;
%*          (b) Version 1.0 retained / SSANDIN                                           ;
%*---------------------------------------------------------------------------------------;
%* 00-07-19 (a) The CGMNAME= functionallity was added to the macro. Including the use of ;
%*              global macro variables _lcbgm_ and _lcbgn_.                              ;
%*---------------------------------------------------------------------------------------;
%* 00-07-19 (a) The CGMNAME= functionallity was added to the macro. Including the use of ;
%*              global macro variables _lcbgm_ and _lcbgn_.                              ;
%*          (b) Increased length from 10 to 16 of the table variable in the              ;
%*             _isrcon_ dataset.                                                         ;
%*          (c) Added TITMODE parameter and associated _lcbtmd_ global macro variable.   ;
%*          (d) Changed GPAGENO=N to Y as default                                        ;
%*          (e) Updated HELP text                                                        ;
%*          (f) GDISPLAY parameter added and global macro variable _lcbgd_               ;
%*          (g) Version set to 2.0                                                       ;
%* 03-08-26 (a) Updated macro with sca2util macro                                        ;
%*          (b) Changed type to SCA                                                      ;
%*          (c) Version set to 3.0                                                       ;
%*---------------------------------------------------------------------------------------;

%if %upcase(&__func__)=HELP %then %do;
  %put;
  %put %str( ---------------------------------------------------------------------------);
  %put %str( HELP: LCB macro RESET                                                      );
  %put %str( ---------------------------------------------------------------------------);
  %put %str( A LCB utility macro: Reset the LCB/SAS options and usage mode              );
  %put %str(                                                                            );
  %put %str( MODE.....: Usage mode: Control use of LCB/SAS metadatasets                 );
  %put %str( RESET=...: Reset target: ALL, CONTENT, GRAPH, TABLE, PAGENO, CGM, PREFIX   );
  %put %str( OPTIONS=Y: Reset LCB/SAS options                                           );
  %put %str( ---- Detail setting -------------------------------------------------------);
  %put %str( GPAGENO=Y: Order LCB/SAS to manage page nos of cgm files created by the    );
  %put %str(            macro. When Y all graphs will be inserted on proper page no when);
  %put %str(            inserting SAS output into MS-Word                               );
  %put %str( PAGENO=..: Set pagno. Integer>0                                            );
  %put %str( APP==....: Set appendix no. Integer>0                                      );
  %put %str( SECTION=.: Set section no. Integer>0                                       );
  %put %str( SUBSEC=..: Set sub-section no. Integer>0                                   );
  %put %str( PREFIX=..: Define prefix of max length of 5 to be used in all titles, list );
  %put %str(            of content and frontpage. Only valid when MODE=3.);
  %put %str( FORMCHAR=: Chose formchar: ANIS, OEM or SASANSI. Default ANSI              );
  %put %str( TITMODE=.: 1, 2 or 3. Use 1, 2 or 3 digits in the title indexes. Has no    );
  %put %str( .........: meaning when MODE<3. Default TITMODE=3.                         );
  %put %str( CGMNAME.=: A text string of length 1-5. If assigned the GRFUT macro will   );
  %put %str( .........: automatically assign unique names on CGM files without having to);
  %put %str( .........: use the NAME parameter.                                         );
  %put %str(----------------------------------------------------------------------------);
  %put;
  %goto exit2;
%end;
%else %if "&__func__"^="" %then %do;
  %if &__mmsg__=Y %then %put Error: %upcase(&__func__) request not recognised. Macro aborts;
  %let __err__=ERROR; %let _reason=_=SYNTAX;
  %goto exit2;
%end;

%global _lcbmod_ _lcbcon_ _lcbtbl_ _lcbgrf_ _lcbpno_ _lcbrfl_ _lcbt1_ _lcbt2_ _lcbt3_
        _oldtit_ _oldprg_ _lcbgp_ _prefix_
        _lcbgm_ _lcbgn_ _lcbtmd_ _lcbgd_;

%local _q_ temp __func__ _tpdsn1_ _tpopt1_ _dir_;

%*-- Save options -----------------------------------------------------------------------;
options nonotes;
proc sql noprint;
  select compress(setting) into : _tpdsn1_ from dictionary.options where (optname='_LAST_');
  select compress(setting) into : _tpopt1_ from dictionary.options where (optname='SERROR');
quit;

%let _tpdsn1_=&_tpdsn1_;    %* Remove trailing blanks ----;
%let _tpopt1_=&_tpopt1_;    %* Remove trailing blanks ----;

%*---------------------------------------------------------------------------------------;
%*  LOGICAL CHECK SECTION                                                                ;
%*---------------------------------------------------------------------------------------;
%sca2util(___mn___=reset, ___mv___=3.0, ___mt___=SCA, _upcase_=reset formchar cgmname,
          _mexist_=pageno app section subsec titmode,_mtype_=INTEGER2,
          _yesno_=options gpageno gdisplay);
%if &__err__=ERROR %then %goto exit;

%if "&mode"="" and "&reset" ne "" %then %do;
  %put Error: Parameter MODE blank. Macro aborts.;
  %goto exit;
%end;
%else %if "&mode"="" and "&reset" = "" %then %goto noreset;

%if (&mode<1 or &mode>3) %then %do;
  %put Error: Parameter MODE=&mode. Please change to 1, 2 or 3. Macro aborts.;
  %goto exit;
%end;

%if (&titmode<3 and &mode<3) %then %do;
  %put Warning: Parameter TITMODE<3 only in use for MODE=3. Setting TITMODE=3;
  %goto exit;
%end;

%if (&titmode<1 or &titmode>3) %then %do;
  %put Error: Parameter TITMODE=&titmode. Please change to 1, 2 or 3. Macro aborts.;
  %goto exit;
%end;

%if ("&pageno"^="" and &pageno<1) or ("&app"^="" and &app<1) or ("&section"^="" and &section<1)
     or ("&subsec"^="" and &subsec<1) %then %do;
  %put Error: Error(s) found in parameters PAGENO, APP, SECTION or SUBSEC. Macro aborts.;
  %goto exit;
%end;

%if "&formchar"^="" and "&formchar"^="ANSI" and "&formchar"^="OEM" and "&formchar"^="SASANSI" %then %do;
  %put Error: FORMCHAR=%bquote(&formchar) not allowed. Macro aborts.;
  %goto exit;
%end;

%if "&reset"^="" and &mode=1 %then %do;
  %put Warning: Mode=1 not possbile when resetting %bquote(&reset). Mode 2 set.;
  %let mode=2;
%end;

%if &mode=1 %then %do;
  %put Note: LCB/SAS titles mode=1 chosen.;
  %let _lcbmod_=1;%let _lcbtbl_=N;%let _lcbcon_=N;%let _lcbgrf_=N;

  %put;
  %goto skipmod2;
%end;
%else %if &mode>1 %then %do;
  %put Note: LCB/SAS mode=&mode chosen.;
  %let _lcbmod_=&mode;
  %if "&reset"="" %then %put Note: Please reset TABLE, CONTENTS, PAGENO, GRAPH, PREFIX and/or CGM.;
  %put;
%end;


%sca2util(___mc___=&reset);
%do _q_=1 %to &_nmvar_;
  %let temp=%scan(%bquote(&reset),&_q_,' ');
  %if ("&temp"^="ALL" and "&temp"^="TABLE" and "&temp"^="GRAPH" and "&temp"^="CONTENT"
      and "&temp"^="PAGENO" and "&temp"^="CGM" and "&temp"^="PREFIX") %then %do;
    %put Error: %bquote(&temp) not valid input to parameter RECORD. Macro aborts.;
    %goto exit;
  %end;
%end;

%do _q_=1 %to &_nmvar_;
  %let temp=%scan(%bquote(&reset),&_q_,' ');
  %if &temp=TABLE or &temp=ALL %then %do;
    %put Note: Start record LCB appendix s_* files set by PRINTTO macro;
    %let _lcbtbl_=Y;
    %*-- Reset ISR tables meta dataset -----------------------------------;
    %put Note: Resetting ISR tables meta dataset;%put;
    data _isrfil_(alter=gnu write=gnu);
      label lcbrfl='LCB/SAS ISR appendix file name' empty='Tables (Y/N)' graph='Graphs (Y/N)'
            appendix='Appendix No.' appstudy='Study Id' appuser='Statistician' apptitle='Appendix title';
      length lcbrfl apptitle $ 200 appuser $ 20 appstudy $ 15;
      appendix=1; lcbrfl="";empty='Y';graph='N';
      delete;
      run;
  %end;

  %if &temp=GRAPH or &temp=ALL %then %do;
    %put Note: Start record LCB graph files created by GRFUT macro;
    %let _lcbgrf_=Y;
    %*-- Reset ISR graph meta dataset --------------------------------------;
    %put Note: Resetting graph meta dataset;%put;
    data _lcbgw_(alter=gnu write=gnu);
      label lcbrfl='File name' desc='Description';
      length dir lcbrfl $ 200 ysize xsize extfile $ 8 desc size $ 40;
      pageno=1;gorder=1;
      delete;
      run;
    %if &gpageno=Y and &mode>1 %then %do;
      %put Note: Allow collecting of pageno for graphs.;
      %let _lcbgp_=Y;
    %end;
    %else %if &gpageno=Y and &mode=1 %then %do;
      %put Warning: GPAGENO=Y but PAGENO=N. GPAGENO will be set to N.;
      %let _lcbgp_=N;
    %end;

  %end;

  %if &temp=CONTENT or &temp=ALL %then %do;
    %put Note: Start record LCB/SAS ISR contents data;
    %let _lcbcon_=Y;
    %*-- Reset ISR contents meta dataset -----------------------------------;
    %put Note: Resetting contents meta dataset;
    %put Note: Resetting table appendix, section and sub-section no;%put;

    data _isrcon_(alter=gnu write=gnu);
      label appendix='Appendix' section='Section' subsec='Sub section'
            pageno='Page No' program='Program' table='Table' tabfig='Table/Figure'
            lcbrfl='Appendix file';
      length tit1-tit10 lcbrfl $ 200 program $ 20 table $ 16 tabfig $ 3;
      appendix=.;section=.;subsec=.;pageno=.;
      delete;
    run;

    %let _oldprg_=;%let _oldtit_=;
    %let _lcbt1_=;%let _lcbt2_=;%let _lcbt3_=;
  %end;

  %if &temp=PAGENO or &temp=ALL %then %do;
    %put Note: Start record page no in LCB/SAS meta datasets;
    %put Note: Resetting page no;%put;
    options pageno=1;
    %let _lcbpno_=Y;
  %end;

  %if &temp=CGM or &temp=ALL %then %do;
    proc sql noprint;
      select compress(upcase(xpath)) into : _dir_
      from dictionary.extfiles
      where fileref="%upcase(RESULT)";
    quit;
    %let _dir_=&_dir_;

    %if "&_dir_"="" %then %do;
      %put Warning: Fileref RESULT not defined. Graphical CGM files will not be erased.;
      %goto skipcgm;
    %end;
    %else %do;

      %sca2util(__file__=&_dir_, __mmsg__=N);
      %if "&__err__"="ERROR" %then %do;
        %put Error: Directory associated with fileref RESULT is not valid. CGM files will not be erased.;
        %put %str(       Path: &_dir_);%put;
        %goto skipcgm;
      %end;

      %put Note: Erasing all graphical CGM files in &_dir_;

      options noxwait;
      data _null_;
        call system("erase &_dir_\*.cgm");
      run;
    %end;

    %skipcgm:
  %end;

  %if &temp=PREFIX or &temp=ALL %then %do;
    %put Note: Resetting prefix ;%put;
    %let _prefix_=;
  %end;

%end;

%noreset:


%*--- Set SAS graph display parameter ---------------------------------------------------;
%if &gdisplay=Y %then %do;
  %put Note: GRESET macro will set goption display;
  %let _lcbgd_=Y;
%end;
%else %do;
  %put Note: GRESET macro will set goption nodisplay;
  %let _lcbgd_=N;
%end;


%*--- Set pageno no ---------------------------------------------------------------------;
%if "&pageno"^="" %then %do;
  %put Note: Reset pageno=&pageno;
  options pageno=&pageno;
  %let _lcbpno_=Y;
%end;
%*else %put Note: Retains pageno &_lcbpno_;


%*--- Set appendix no -------------------------------------------------------------------;
%if "&app"^="" %then %do;
  %put Note: Table appendix no=&app has been set;
  %let _lcbt1_=&app;
%end;
%*else %put Note: Retain appendix no &_lcbt1_;


%*--- Set section no --------------------------------------------------------------------;
%if "&section"^="" %then %do;
  %put Note: Table section no=&section has been set;
  %let _lcbt2_=&section;
%end;
%*else %put Note: Retain section no &_lcbt2_;


%*--- Set sub-section no ----------------------------------------------------------------;
%if "&subsec"^="" %then %do;
  %put Note: Table sub-section no=&subsec has been set;
  %let _lcbt3_=&subsec;
%end;
%*else %put Note: Retain sub-section no &_lcbt3_;


%*--- Set sub-section no ----------------------------------------------------------------;
%if "&prefix" ne "" %then %do;
  %if &mode<3 or "&mode"="" %then %put Note: The PREFIX parameter has no meaning when MODE<3.;
  %else %do;
    %if %length(&prefix)>5 %then %do;
      %put Warning: PREFIX=&prefix. A max length of 5 allowed. Prefix truncated (%substr(&prefix,1,5));
      %let prefix=%substr(&prefix,1,5);
    %end;
    %let _prefix_=&prefix;
  %end;
%end;

%SKIPMOD2:

%*--- CGM-name  / ssandin 000719 --------------------------------------------------------;
%if %qupcase(&cgmname)^= %then %do;

  %let _lcbgm_=; %let _lcbgn_=;

  %sca2util(___mc___=&cgmname, __mmsg__=N);
  %if &_nmvar_>1 %then %do;
    %put Error: Only one word allowed in CGMNAME parameter. CGMNAME set to blank.;
    %let cgmname=;
  %end;
  %else %if %length(&cgmname)>5 %then %do;
    %put Warning: CGMNAME must not be longer than five characters. CGMNAME truncated.;
    %let _lcbgm_=%substr(&cgmname,1,5);
    %let _lcbgn_ =1;
    %put Note: CGM files created by the LCB macro GRFUT will be named &_lcbgm_.1, &_lcbgm_.2 etc;%put ;
  %end;
  %else %do;
    %let _lcbgm_=&cgmname;
    %let _lcbgn_ =1;
    %put Note: CGM files created by the LCB macro GRFUT will be named &_lcbgm_.1, &_lcbgm_.2 etc;%put ;
  %end;

%end;



%*--- Select the number system used in the titles by TIT / ssandin 000719---*;
%if &mode=3 %then %do;
  %if %qupcase(&titmode)=3 %then %do;
    %put Note: Title index including three digits will be used "Table a.b.c";
    %put %str(      a.b.c updated for each new appendix, program and title);
    %put %str(      b and c reset for each new appendix, c reset for each new program);
    %let _lcbtmd_=3;
  %end;
  %else %if %qupcase(&titmode)=2 %then %do;
    %put Note: Title index including two digits will be used "Table b.c";
    %put %str(      b.c updated for each new program and title);
    %put %str(      b and c reset for each new appendix, c reset for each new program);
    %let _lcbtmd_=2;
  %end;
  %else %do;
    %put Note: Title index including two digits will be used "Table c";
    %put %str(      c updated for each new program and title);
    %put %str(      c reset for each new appendix);
    %let _lcbtmd_=1;
  %end;
%end;



%if &options=Y %then %do;
  %put Note: Resetting SAS options using formchar=&formchar;%put;
  options ls=130 ps=43 nodate nonumber nocenter nostimer source source2
          notes dsnferr serror fmterr details
          fmtsearch=(work sasfmt psasfmt)
          %if &formchar=OEM %then %str(formchar='³ÄÚÂ¿ÃÅ´ÀÁÙ+=|-/\<>*');
          %else %if &formchar=SASANSI %then %str(formchar='‚ƒ„…†‡ˆ‰Š‹Œ+=|-/\<>*');
          %else %if &formchar=NONE %then %str(formchar='                    ');
          %else %str(formchar='|----|+|---+=|-/\<>*');
          nomacrogen nosymbolgen nomtrace nomlogic nomprint
          mergenoby=WARN validvarname=upcase
;


*-- 30sep2004 removing the options on the next line;
* mautosource sasautos=("&__scasdsk/sasmacro/code") nomstored mrecall;


%end;


%EXIT:
  options notes _last_=&_tpdsn1_ &_tpopt1_;
%EXIT2:
  %put Note: Macro RESET finished execution.;%put;

%mend;
options source;
