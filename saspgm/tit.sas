options nosource;
%macro tit(_study_, us=, prog=, type=1, retain=N, h=1.3)/des='MEB macro TIT 2.1';


%*=====================================================================;
%* 940929: Astra Pain Control AB changed to APC in title;
%* 940929: des-statement added to macro-head;
%*---------------------------------------------------------------------;
%* 950222: For titleno>1 footnotes<2 set to missing leading to more    ;
%*         empty space in between                                      ;
%* 950222: Default footnote height set to 1.7;
%* 950222: Versions changed to 1.4;
%*---------------------------------------------------------------------;
%* 950227: Change from 950222 removed. No space in between (request by ;
%*       : ASYREN. Version changed to 1.5                              ;
%*---------------------------------------------------------------------;
%* 950315: Message VMS changed to &sysscp in title and time included in;
%*       : title for non VMS as well. Version changed to 1.6           ;
%*---------------------------------------------------------------------;
%* 9606DD: Stud=HELP and LCBUTIL call added together with some comments;
%* 9606DD: The macro variables L call added together with some comments;
%* 9606DD: If macro variables __LCBUS and STUDY defined. These names   ;
%*         are utomatically used                                       ;
%* 9606DD: Title and footnote shortened to save space in printed output;
%*---------------------------------------------------------------------;
%* 980327: Updated LOCAL statement to include all local variables      ;
%*---------------------------------------------------------------------;
%* 980701: Added use of the global PREFIX parameter to be set by the   ;
%*         reset macro.                                                ;
%*---------------------------------------------------------------------;
%* 000719: Changed type=0 to type=1 as default                         ;
%*         Added control of indexes when mode=3 and titmode parameter  ;
%*          as set by the reset macro. Decided from the global         ;
%*          variable _lcbtmd_.                                         ;
%*         Removed APC from created footnote/title stamps              ;
%*         Changed definition "global t&i" to "local t&i"              ;
%*         Changed code for creating _blank_ variable                  ;
%*         Version set to 2.1                                          ;
%*---------------------------------------------------------------------;
%* 030826: a) Replaced sca2util with sca2util                          ;
%*         b) Removed ability to run under SAS 6.11 and VMS            ;
%*         c) Added the H parameter and updated the help section       ;
%*---------------------------------------------------------------------;
%* 040209: a) Earlier h= was not included in footnote statment. Only &h;
%*=====================================================================;

%if "%upcase(&_study_)"="HELP" %then %do;
  %put;
  %put %str( ----------------------------------------------------------------------);
  %put %str( HELP: MEB macro TIT(pos1, pos2)                                       );
  %put %str( ----------------------------------------------------------------------);
  %put %str( A MEB utility macro: Set MEB default title or footnotes);
  %put %str( POS1.....: Study Number);
  %put %str( POS2.....: User name);
  %put %str( PROG=....: SAS program name, i.e. program calling TIT macro);
  %put %str( TYPE=....: TYPE=0 a title row is created, TYPE>0 a footnote is created);
  %put %str( RETAIN=N.: Yes or No. Retain the title index);
  %put %str( H=1.3....: Default footnote (or title if TYPE=0) height);
  %put %str();
  %put %str(-----------------------------------------------------------------------);
  %put;
  %GOTO EXIT2;
%end;

%local tid usinf _blank_ topt _txt_ __opt1__ _index_ i ___r___ __max__ j __opt2__
       studinf tabfig proginf;


%*----------------------------------------------------------------------------------;
%* INITIALISES MACRO                                                                ;
%*----------------------------------------------------------------------------------;
%let __opt1__=;
proc sql noprint;
  select setting into : __opt2__ from dictionary.options where (optname='MPRINT');
  %let __opt1__=&__opt2__;
  options nomprint;
  select setting into : __opt2__ from dictionary.options where (optname = 'NOTES');
  %let __opt1__=&__opt1__ &__opt2__;
  select setting into : __opt2__ from dictionary.options where (optname = 'SERROR');
  %let __opt1__=&__opt1__ &__opt2__;
  select setting into : __opt2__ from dictionary.options where (optname='MLOGIC');
  %let __opt1__=&__opt1__ &__opt2__;
  select setting into : __opt2__ from dictionary.options where (optname='SYMBOLGEN');
  %let __opt1__=&__opt1__ &__opt2__;
  select compress(setting) into : __opt2__ from dictionary.options where (optname='_LAST_');
  %let __opt1__=&__opt1__ _last_=&__opt2__;
  quit;
options nonotes noserror nomlogic nosymbolgen;

%sca2util(___mn___=TIT, ___mv___=2.1, ___mt___=MEB, _upcase_=prog);

%*-- Set USER and STUDY variables -------------------------------------------;
%if ("&us"="" or "&_study_"="") %then %do;
  %sca2util(_mexist_=__scauser__ _scastudy_, __mmsg__=N);
  %if &__err__=ERROR %then %do;
    %*;
  %end;
  %else %do;
    %if "&us"="" %then %let us=&__scauser__;
    %if "&_study_"=""  %then %let _study_=&_scastudy_;
  %end;
%end;

%if "&us" ne "" and "&_study_" eq "" %then %let usinf= &us;
%else %if "&us" ne "" and "&_study_" ne "" %then %let usinf=/ &us;
%else %let usinf=;

%if "&_study_" ne "" %then %let studinf=Study &_study_;
%else %if "&_study_"="" %then %let studinf=;

%if "&prog"="" %then %let proginf=;
%else %let proginf=Prog: &prog;;

%*-- Set date and time  -----------------------------------------------------;
data _null_;
  call symput('tid',put(date(),yymmdd6.)||' '||put(time(),hhmm5.));
run;

%let _txt_=&studinf.&usinf &proginf SAS&sysver/&sysscpl &TID;

%let h=%str(h=&h);


%*---------------------------------------------------------------------------;
%*  MODE 2 AND 3 SECTION                                                     ;
%*---------------------------------------------------------------------------;
options noserror;
%if ("&_lcbmod_"="2" or "&_lcbmod_"="3") and "&_lcbcon_"="Y" %then %do;
  %*-------------------------------------------------------------------------;
  %* START SETTING OF TITLES AND PAGENOS                                     ;
  %*-------------------------------------------------------------------------;

  %*-------------------------------------------------------------------------------;
  %* _LOGPRG_: Retain program to test if updated                             ;
  %* TIT macro keeps track of tables a.b.c where :                           ;
  %* _lcbt1_: Updates for each new occurance of printto, correspond to appendix    ;
  %* _lcbt2_: Updates for each new non-blank occurance of prog parameter (section) ;
  %* _lcbt3_: Updates when title line 1 uppdates (sub-section)                     ;
  %*-------------------------------------------------------------------------------;


  %*-- Store no of titles and footnotes into macro variables __max__  ;
  proc sql noprint;
    select max(number) into : __max__ from
    sashelp.vtitle
    where (type="T");
    run;quit;
  %if &__max__=. or %bquote(&__max__)= %then %let __max__=0;

  %if &__max__>0 %then %do;
    %*-- Temporarily store the titles in local macro variables --------------;
    %do i=1 %to &__max__;
      %local t&i;
      proc sql noprint;
        select text into : t&i from sashelp.vtitle
        where (type="T" and number=&i);
      quit;
      %let t&i=&&t&i;

      %let ___r___=%length(%bquote(&&t&i));
      %if &___r___>0 %then %let t&i=%substr(%bquote(&&t&i),1,&___r___);
      %else %let t&i=;
      %*if &___r___>0 %then %let t&i=%substr(%nrquote(&&t&i),1,&___r___);
      %if &_lcbmod_=3 and &i=1 %then %do;
        %*-- If first character in title 1 is > then a figure title is assumed ---;
        %if &___r___>0 %then %do;
          %if "%substr(%nrquote(&t1),1,1)"="<" %then %do;
            %let t1=%substr(%nrquote(&t1),2,%length(%bquote(&t1))-1);
            %let tabfig=Figure; %let topt=%str(j=L);
          %end;
          %else %do;
            %let tabfig=Table ; %let topt=;
          %end;
        %end;
      %end;
    %end;
  %end;

  %*-------------------------------------------------------------------------;
  %* Reset _LCBT1_, _LCBT2_, and _LCBT3_ parameters if not done earlier      ;
  %*-------------------------------------------------------------------------;
  %if "&retain"="N" %then %do;
    %if "&_lcbt1_"="" %then %let _lcbt1_=1;

    %*-------------------------------------------------------------------------;
    %* Renumber section no                                                     ;
    %*-------------------------------------------------------------------------;
    %if ("&prog" ne "" and &prog ne &_oldprg_) and (&_lcbtmd_>1) %then %do;
      %if "&_lcbt2_"="" %then %let _lcbt2_=1;
      %else %let _lcbt2_=%eval(&_lcbt2_+1);
      %let _lcbt3_=1;
    %end;
    %else %if "&_oldtit_" ne "&t1" %then %do;
      %*-------------------------------------------------------------------------;
      %* Renumber sub-section                                                    ;
      %*-------------------------------------------------------------------------;
      %if "&prog"="" and "&_oldprg_"^="" %then %put Warning: PROG parameter not set. Assuming &_oldprg_ program still running.;
      %else %if "&prog"="" and "&_oldprg_"="" %then %put Warning: PROG parameter not set and previous program unknown.;
      %else %let _lcbt3_=%eval(&_lcbt3_+1);
    %end;
  %end;


  %if &_lcbtmd_=3 %then %let _index_=&_lcbt1_..&_lcbt2_..&_lcbt3_:;
  %else %if &_lcbtmd_=2 %then %let _index_=&_lcbt2_..&_lcbt3_:;
  %else %if &_lcbtmd_=1 %then %let _index_=&_lcbt3_:;


  %*-------------------------------------------------------------------------;
  %* Adjust _INDEX_ and _BLANK_ variables for PREFIX paramter                ;
  %*-------------------------------------------------------------------------;
  %sca2util(_mexist_=_prefix_, __mmsg__=N);
  %if "&__err__"="ERROR" %then %goto skippref;

  %if "&_prefix_" ne "" %then %do;
    %local __l__;
    %let __l__=%length(&_prefix_);
    %if &__l__>5 %then %do;
      %put Error: PREFIX=&_prefix_ longer than 5 characters. Prefix truncated (%substr(&_prefix_,1,5)));
      %let _prefix_=%substr(&_prefix_,1,5);
      %let __l__=5;
    %end;
    %let _index_=&_prefix_&_index_;

  %end;


  %let _blank_=%qsysfunc(repeat(%str( ),%eval(%length(%bquote(&_index_))-1) ));


  %SKIPPREF:


  %*-------------------------------------------------------------------------;
  %* Set page no                                                             ;
  %*-------------------------------------------------------------------------;
  %if &_lcbpno_=Y %then %SCAPNO;

  %*-------------------------------------------------------------------------;
  %* Set titles                                                              ;
  %*-------------------------------------------------------------------------;
  %if &type=0 %then %do;  %* if title *;
    %if &__max__=0 %then %str(title1 j=L &h "&_txt_";);
    %else %do i=1 %to &__max__;
      %let j=%eval(&i+1);
      %if &i=1 %then %do;
        %str(title1 j=L &h "&_txt_";);
        %if &_lcbmod_=3 %then %str(title&j &topt "&tabfig &_index_ &t1";);
        %else %str(title&j "&t1";);
      %end;
      %else %if &_lcbmod_=3 and &i>1 %then %str(title&j &topt "      &_blank_ &&t&i";);
      %else %str(title&j "&&t&i";);
    %end;
  %end;
  %else %do;  %* if footnote *;
    %if &__max__>0 %then %do i=1 %to &__max__;
      %if &_lcbmod_=3 and &i=1 %then %str(title&i &topt "&tabfig &_index_ &&t&i";);
      %else %if &_lcbmod_=3 and &i>1 %then %str(title&i &topt "      &_blank_ &&t&i";);
      %else %str(title&i "&&t&i";);
    %end;
  %end;

  %if &__max__=0 %then %goto notitles;

  %*-------------------------------------------------------------------------;
  %* Store content information                                               ;
  %*-------------------------------------------------------------------------;
  %if "&retain"="N" %then %do;
    %let _oldprg_=&prog;
    %let _oldtit_=&t1;
    %if &__max__>10 %then %let __max__=10;
    proc sql;
      insert into _isrcon_(alter=gnu write=gnu)
      set appendix=&_lcbt1_,
        %if "&_lcbt2_"^="" %then %str(section=&_lcbt2_,);
        %if ("&_lcbt2_"^="" and "&_lcbt3_"^="") %then %str(subsec=&_lcbt3_,);
        %if "&prog"^="" %then %str(program="&prog",);
        %if "&tabfig"="Figure" %then %str(tabfig='Fig',);
        %else %str(tabfig='Tab',);
        %if &__max__=0 %then %str(tit1='<Not specified>',);
        %else %do i=1 %to &__max__;
          %str(tit&i="&&t&i",)
        %end;
        %if &_lcbpno_=Y %then %str(pageno=&__lcbp__,);
        %else %str(pageno=.N,);
        %if "&_lcbrfl_"^="&_lcbrfl_" and %length(%bquote(&_lcbrfl_))>0 %then %str(lcbrfl="&_lcbrfl_",);
        table=trim(left("&_index_"));
    quit;
  %end;

  %if "&tabfig"="Figure" %then %put Note: Fig: &_lcbt1_..&_lcbt2_..&_lcbt3_;
  %else %put Note Table: &_lcbt1_..&_lcbt2_..&_lcbt3_;

%end;
%else %if &type=0 %then %str(title1 j=L &h "&_txt_";);

%NOTITLES:

%*-- Set title/footnotes ----------------------------------------------------;
%if &type>0 %then %do;
options mprint;
  footnote&type j=L &h "&_txt_";
options nomprint;
%end;;


%EXIT:
  options &__opt1__;
%EXIT2:
  %put Note: Macro TIT finished execution.;

%mend;
options source;
