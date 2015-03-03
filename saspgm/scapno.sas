options nosource;
%macro scapno / des='MEB macro SCAPNO 1.2';

  %*------------------------------------------------------------------------------;
  %* 120117 a) Added macro variable slask to control output file                  ;
  %*           Version set to 1.2                                                 ;
  %*------------------------------------------------------------------------------;
  %* 000719 Previous version defined a "data null" dataset instead of data _null_ ;
  %*        Version set to 1.1                                                    ;
  %*------------------------------------------------------------------------------;
  %* 030826 a) Renamed to SCAPNO and version set to 1.0                           ;
  %*------------------------------------------------------------------------------;

  %global __lcbp__;
  %local slask;

  %let slask=%qsysfunc(pathname(work))/__temp__.dat;

  proc printto print="&slask" new;run;

  options number;
  data _null_;
    file print header=gnu;
    put '* ';
    gnu:
    return;
  run;
  options nonumber;

  %if "&_lcbrfl_"^='&_lcbrfl_' and %length(%bquote(&_lcbrfl_))>0 %then %str(proc printto print="&_lcbrfl_";run;);
  %else %str(proc printto;run;);

  data _null_;
    infile "&slask" truncover;
    informat txt $200.;
    input txt 1-200;
    pageno=input(reverse(scan(reverse(txt),1,' ')),8.);
    call symput('__lcbp__',compress(put(pageno,8.)));
    stop;
  run;

  options pageno=&__lcbp__;
%mend;
options source;
