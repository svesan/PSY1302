options nosource;
%macro cleanup(__func__, content=N) / des='MEB macro CLEANUP 2.0';

%*--------------------------------------------------------------------------------------;
%* 941207: A time stamp is sent to the log immediately as the macro starts              ;
%* ......: Version set 1.1/SSANDIN                                                      ;
%* 941207: A time stamp is sent to the log immediately as the macro starts/SSANDIN      ;
%*--------------------------------------------------------------------------------------;
%* 961129: LCB/ISR contents procedures implemented                                      ;
%* ......: _last_ dataset saved                                                         ;
%*--------------------------------------------------------------------------------------;
%* 030827: a) Replaced lcb2util macro with the sca2util macro                           ;
%*         b) Added the CONTENT parameter                                               ;
%*         c) No longer report warnings for titles/footnotes to long for graphs         ;
%*--------------------------------------------------------------------------------------;

%if %upcase(&__func__)=HELP %then %do;
  %put;
  %put %str( ---------------------------------------------------------------------------);
  %put %str( HELP: MEB macro CLEANUP                                                    );
  %put %str( ---------------------------------------------------------------------------);
  %put %str( A MEB utility macro: Re-route output after MEB macro PRINTTO               );
  %put %str(                                                                            );
  %put %str( CONTENT=N.....: No or Yes. If Yes a list of contents is added on top of the);
  %put %str(                 output file.                                               );
  %put %str(----------------------------------------------------------------------------);
  %put;
  %goto exit2;
%end;
%else %if "&__func__"^="" %then %do;
  %if &__mmsg__=Y %then %put Error: %upcase(&__func__) request not recognised. Macro aborts;
  %let __err__=ERROR; %let _reason=_=SYNTAX;
  %goto exit2;
%end;

%local _tpdsn1_ _tpopt1_ __func__ _tstamp1 _tstamp2;

%*-- Save options -----------------------------------------------------------------------;
options nonotes;
proc sql noprint;
  select compress(setting) into : _tpdsn1_ from dictionary.options where (optname='_LAST_');
  select compress(setting) into : _tpopt1_ from dictionary.options where (optname='SERROR');
quit;
%let _tpdsn1_=&_tpdsn1_; %let _tpopt1_=&_tpopt1_;

%*-- Send footnote to output log file ----------------------------------------;
data _null_;
  call symput('_tstamp1',repeat('-',65));
  call symput('_tstamp2',"Note: MEB macro CLEANUP running, SAS&sysver"
              ||", OP:&sysscp, "||put(datetime(),datetime13.));
  run;
%put &_tstamp1;%put &_tstamp2;%put &_tstamp1;
proc printto;run;
%put Note: MEB macro CLEANUP running;

%*----------------------------------------------------------------------------------;
%* Check file for errors and warnings                                               ;
%*----------------------------------------------------------------------------------;
%sca2util(_mexist_=_lcbrfl_);
%if "&_REASON_"="RESOLVE" or "&_lcbrfl_"="" %then %do;
  %put Note: Output file from PRINTTO macro not found. No check for errors and warnings.;
  %goto skipchk;
%end;
%else %do;
  %*--- Check if LOG file exist. Else use LST file -----------;
  %put Note: Start seaching PRINTTO file for Errors and Warnings;
  data _null_;
    length txt txt2 name $ 200;
    txt="&_lcbrfl_";
    %if "&sysscp"="WIN" %then %do;
      index2=index(txt,'\sasout\');
      name=reverse(scan(reverse(txt),2,'.\'));
      if index2>0 then txt2=substr(txt,1,index2-1)||'\saslog\'||compress(name)||'.log';
    %end;
    %else %if "&sysscp"="LINUX" %then %do;
      index2=index(txt,'/sasout/');
      name=reverse(scan(reverse(txt),2,'./'));
      if index2>0 then txt2=substr(txt,1,index2-1)||'/saslog/'||compress(name)||'.log';
    %end;
    call symput('__tmp2__',compress(txt2));
  run;
  filename __tmp__ "&__tmp2__";
  %if &sysfilrc ne 0 %then %do;
    %put Note: LOG file &__tmp2__ do not exist. Using .LST file instead.;
    %let __tmp2__=&_lcbrfl_;
  %end;
  filename __tmp__ clear;

  %*--- Check if appendix empty: No tables created -----------;
  %if "&__tmp2__"="" %then %do;
    %put Warning: Macro PRINTTO output file not found.;
    %goto skipchk;
  %end;

  filename __tmp__ "&__tmp2__";
  %if &sysfilrc ne 0 %then %do;
    %put Warning: Macro PRINTTO outfile not found.;
    filename __tmp__ clear;
    %goto skipchk;
  %end;
  filename __tmp__ clear;

  data ___m1___;
    informat txt $1.;
    infile "&__tmp2__" obs=1;
    input txt 1;
    run;
  %sca2util(__dsn__=___m1___,_exist_=Y,__mmsg__=N);
  proc datasets lib=work mt=data nolist;delete ___m1___;quit;

  %if &__nobs__=0 %then %do;
    %put Note: No tables detected in PRINTTO outfile.;
    %goto skipchk;
  %end;

  %*-- Start searching log file for errors and warnings -------------------------;
  data _null_;
    retain se_n sw_n me_n mw_n 0 file file2 lf;
    length file file2 $ 50 line $ 80;
    line=repeat('-',80);
    infile "&__tmp2__" end=eof truncover;
    input txt $ 1-200;
    if index(txt,'|Name..........:')>0 then do;
      file=input(substr(txt,25,175),$20.);file2='('||compress(file)||')';
      lf=length(file2);
    end;
    if index(substr(txt,1,6),'ERROR:')>0 then do;
      put line / 'Note: SAS ERROR found on line ' @@;
      if file^='' then put _n_ file2 $varying. LF '. The message was:' txt /;
      else put _n_ '. The message was:' txt /;
      se_n=se_n+1;
    end;

    else if index(substr(txt,1,8),'WARNING:')>0 then do;
      *- Do not report warnings for too long titles/footnotes in graphs 030827;
      if index(txt,'too long. Height has been reduced to')=0 then do;
        put line / 'Note: SAS WARNING found on line ' @@;
        if file^='' then put _n_ file2 $varying. LF '. The message was:' txt /;
        else put _n_ '. The message was:' txt /;
        sw_n=sw_n+1;
      end;
    end;

    else if index(substr(txt,1,6),'Error:')>0 then do;
      put line / 'Note: MEB macro ERROR found on line ' @@;
      if file^='' then put _n_ file2 $varying. LF '. The message was:' txt /;
      else put _n_ '. The message was:' txt /;
      me_n=me_n+1;
    end;

    else if index(substr(txt,1,8),'Warning:')>0 then do;
      put line / 'Note: MEB macro WARNING found on line ' @@;
      if file^='' then put _n_ file2 $varying. LF '. The message was:' txt /;
      else put _n_ '. The message was:' txt /;
      mw_n=mw_n+1;
    end;

    if eof then do;
      put @1 line / 'SAS LOG Summary. No of events:' / line;
      put @2 'SAS ERROR' @20 'SAS WARNING' @40 'MEB macro Error' @60 'MEB macro Warning';
      put @5 se_n @25 sw_n @45 me_n @65 mw_n / line;
    end;
    run;
%end;
%SKIPCHK:

%*----------------------------------------------------------------------------------;
%* MEB environment variables and metadatsets                                        ;
%*----------------------------------------------------------------------------------;
options noserror;
%if "&_lcbmod_"="2" or "&_lcbmod_"="3" and "&_lcbtbl_"="Y" %then %do;
  %*--- Check if appendix empty: No tables created -----------;
  %if "&_lcbrfl_"="" %then %do;
    %put Warning: Macro PRINTTO outfile not found.;
    %goto exit;
  %end;

  filename __tmp__ "&_lcbrfl_";
  %if &sysfilrc ne 0 %then %do;
    %put Warning: Macro PRINTTO outfile not found.;
    filename __tmp__ clear;
    %goto exit;
  %end;
  filename __tmp__ clear;

  data ___m1___;
    informat txt $1.;
    infile "&_lcbrfl_" obs=1;
    input txt 1;
    run;
  %sca2util(__dsn__=___m1___,_exist_=Y,__mmsg__=N);
  proc datasets lib=work mt=data nolist;delete ___m1___;quit;

  %if &__nobs__=0 %then %do;
    %put Note: No tables detected in PRINTTO outfile.;
  %end;
  %else %if &__nobs__>0 %then %do;
    %put Note: Updating tables meta dataset;
    proc sql noprint;
      update _isrfil_(alter=gnu write=gnu)
      set empty='N'
      where (lcbrfl="&_lcbrfl_" and appendix=&_lcbt1_);
    quit;
  %end;

  %*--- Check if graphs in appendix --------------------------;
  %if "&_lcbgrf_"="Y" %then %do;
    %sca2util(__dsn__=_lcbgw_,_exist_=Y,__mmsg__=N);
    %if &__err__ ne ERROR %then %do;
      proc sort data=_isrfil_(alter=gnu);by lcbrfl appendix;run;
      proc sort data=_lcbgw_(keep=lcbrfl) out=___m2___ nodupkey;by lcbrfl;run;
      data _isrfil_(alter=gnu write=gnu);
        merge _isrfil_(in=isr) ___m2___(in=gw);by lcbrfl;
        if gw and not isr then do;
          put 'Error: Please check tables and graphs meta datasets. Filename mis-match.;';
          delete;
        end;
        else if gw and isr then graph='Y';
        run;
      proc datasets lib=work mt=data nolist;delete ___m2___;quit;
    %end;
    %else %put Note: MEB/SAS ISR graph meta dataset do not exist. Assuming no graphs created.;
  %end;
%end;

%sca2util(_yesno_=content);

*-- Add list of contents to the output file ;
%if "&content"="Y" %then %do;
  proc sql;
    create table __bort1 as
    select compress(table,':') as table, tit1, pageno
    from _isrcon_(where=(appendix=&_lcbt1_ and tabfig='Tab')) order by pageno, table desc;
  quit;
  data __bort2;
    drop _c_;
    retain _c_ 3;
    set __bort1 end=eof;by pageno descending table;
    if first.pageno then _c_=_c_+1;

    if eof then call symput('slask',compress(put(int(_c_/43)+1,5.)));
  run;
  data __bort3;
    format txt $char250.;
    infile "&_lcbrfl_" lrecl=12000 truncover;
    input txt $char250.;
  run;
  data _null_;
    file "&_lcbrfl_" lrecl=12000;
    retain _d_ 0;
    set __bort2 end=eof;
    if _n_=1 or _d_>43 then _d_=0;
    _d_=_d_+1;

    if _d_=1 then put 'Table' '09'x 'Table content' '09'x 'Page' /;

    pageno=pageno+&slask;
    put table '09'x tit1 '09'x pageno;

    if eof or _d_=43 then do;_e_=byte(12);put _e_;end;
  run;
  data _null_;
    file "&_lcbrfl_" mod lrecl=12000;
    set __bort3;
    put txt $char250.;
  run;

  proc datasets lib=work mt=data nolist;delete __bort1-__bort3;quit;

%end;

%let _lcbrfl_=;

%EXIT:
  title;footnote;
  options notes &_tpopt1_ %if "&_tpdsn1_"^="" %then %str(_last_=&_tpdsn1_;);
%EXIT2:
  %put Note: Macro CLEANUP finished execution.;%put;
*options nomprint nomacrogen nosymbolgen nomtrace;

%mend;
options source;
