options nosource;
%macro printto(file, logref=log, outref=result, mix=NO, title=)/des='MEB macro PRINTTO 2.0';

%****************************************************************************************;
%* 940509: PRIxxx changed to ANSI_PRIxxx / SSANDIN                                       ;
%*---------------------------------------------------------------------------------------;
%* 941102: Macro variable logtest was used instead of outtest at some places in the prog.;
%* ......: This led to in-correct log-message that fileref &logref was not allocated. Now;
%* ......: macro aborts when these errors occurs /SSANDIN                                ;
%*---------------------------------------------------------------------------------------;
%* 941102: Logical checks when file is blank /SSANDIN.                                   ;
%*---------------------------------------------------------------------------------------;
%* 941207: When log routed to file a time stamp is sent to the log immediately as the    ;
%* ......: macro starts, version set 1.3/SSANDIN                                         ;
%* ......: Changed to allow MIX parameter to take value Y instead of YES as well/SSANDIN ;
%*---------------------------------------------------------------------------------------;
%* 961129: LCB/SAS ISR procedures implemented                                            ;
%* ......: sca2util macro added                                                          ;
%* ......: HELP functionallity added                                                     ;
%* ......: Macro preserves _last_ dataset                                                ;
%* ......: Version set to 2.0  /SSANDIN                                                  ;
%* 970611: Title, appuser and appstudy added to _isrfil_ dataset. Version retained/ssanin;
%*---------------------------------------------------------------------------------------;
%* 030826: a) Parameter PRI removed                                                      ;
%*         b) lcb2util replaced with sca2util                                            ;
%*                                                                                       ;
%*                                                                                       ;
%****************************************************************************************;

%if %upcase(&file)=HELP %then %do;
  %put;
  %put %str( ---------------------------------------------------------------------------);
  %put %str( HELP: MEB macro PRINTTO                                                    );
  %put %str( ---------------------------------------------------------------------------);
  %put %str( A MEB utility macro: Send SAS output to ASCII file                         );
  %put %str(----------------------------------------------------------------------------);
  %put %str( FILE.....: File name                                                       );
  %put %str( LOGREF=..: SAS log destination                                             );
  %put %str( OUTREF=..: SAS output destination                                          );
  %put %str( MIX=N....: Y/N. Send LOG och OUTPUT to the same destination                );
  %put %str(----------------------------------------------------------------------------);
  %put;
  %goto exit2;
%end;
options nonotes;

%local _tpdsn1_ _tpopt1_ temp1 temp2 __logdir __outdir _tstamp1 _tstamp2;

%*-- Save options -----------------------------------------------------------------------;
proc sql noprint;
  select compress(setting) into : _tpdsn1_ from dictionary.options where (optname='_LAST_');
  select compress(setting) into : _tpopt1_ from dictionary.options where (optname='SERROR');
quit;

%sca2util(___mn___=printto,___mv___=2.0,___mt___=MEB,_upcase_=logref outref,_yesno_=mix);

%if &mix=Y %then %put Note: SAS log and output sent to same file;

%if "&file"="" %then %do;
  %put Error: Parameter FILE must be specified. Macro aborts.;
  %goto exit;
%end;
%else %if "&file" ne "" %then %do;
  %if "&sysscp"="WIN" %then %let file=\&file;
  %else %if "&sysscp"="LINUX" %then %let file=/&file;

  %*-------------------------------------------------------------------------------------;
  %* Check that fileref and logref have been set                                         ;
  %*-------------------------------------------------------------------------------------;
  proc sql noprint;
  %if &mix^=Y %then %do;
    select count(fileref) into : temp1
    from dictionary.extfiles where (fileref in ("&logref"));
    %if &temp1=1 %then %do;
      select xpath into : __logdir
      from dictionary.extfiles where (fileref in ("&logref"));
    %end;
    %else %let temp1=0;
  %end;
  %else %let temp1=0;
  select count(fileref) into : temp2
  from dictionary.extfiles where (fileref in ("&outref"));
  %if &temp2=1 %then %do;
    select xpath into : __outdir
    from dictionary.extfiles where (fileref in ("&outref"));
  %end;
  %else %let temp2=0;
  quit;

  %if &mix^=Y %then %if &temp1=0 %then %put Error: Specfied fileref &logref not allocated. Macro aborts.;
  %if &temp2=0 %then %put Error: Specfied fileref &outref not allocated. Macro aborts.;

  %if &mix^=Y %then %if &temp1=0 %then %goto exit;
  %else %if &temp2=0 %then %goto exit;

  %if &temp1=1 %then %let __logdir=%substr(%bquote(&__logdir),1,%eval(%length(%unquote(&__logdir))));
  %if &temp2=1 %then %let __outdir=%substr(%bquote(&__outdir),1,%eval(%length(%unquote(&__outdir))));

  %*-- Set macro variables sending header to output file -------------------------------;
  data _null_;
    call symput('_tstamp1',repeat('-',65));
    call symput('_tstamp2',"Note: MEB macro PRINTTO running, SAS&sysver"
                ||", OP:&sysscpl, "||put(datetime(),datetime13.));
    run;

  %*----------------------------------------------------------------------------------;
  %* MEB environment variables and metadatsets                                        ;
  %*----------------------------------------------------------------------------------;
  options noserror;
  %if "&_lcbmod_"="2" or "&_lcbmod_"="3" and "&_lcbtbl_"="Y" %then %do;
    %put Note: Using MEB/SAS mode=&_lcbmod_;
    %if &_lcbt1_= %then %let _lcbt1_=1;
    %else %let _lcbt1_=%eval(&_lcbt1_+1);
    %put Note Updating appendix no. Now Appendix=&_lcbt1_;

    %put Note: Resets section and sub-section index;
    %let _lcbt2_=0; %let _lcbt3_=0; %let _oldprg_=; %let _oldtit_=;

    %*--- Sets appendix filename for use by other macros -----------------;
    %let _lcbrfl_=&__outdir.&file..lst;

    %*--- Reset page number ----------------------------------------------;
    options pageno=1;

    %if &_lcbt1_ GE 1 %then %do;
      %put Note: Updating ISR tables meta dataset.;
      proc sql noprint;
        insert into _isrfil_(alter=gnu write=gnu)
        set appendix=&_lcbt1_, lcbrfl="&_lcbrfl_", empty='Y', graph='N'
        %if "&title" ne "" %then %str(,apptitle="&title");
        %if "&__scauser__" ne "" %then %str(,appuser="&__scauser__");
        %if "&_scastudy_" ne "" %then %str(,appstudy="&_scastudy_");
        ;
      run;quit;
    %end;
  %end;

  %*----------------------------------------------------------------------------------;
  %* Independent on MEB environment variables: Start proc printto                     ;
  %*----------------------------------------------------------------------------------;
  %if &mix=Y %then %do;
    %put Note: Routing SAS log and output to the same file &__outdir.&file..lst;
    %put Note: Call LCB macro CLEANUP to re-route output and log;
    proc printto print="&__outdir.&file..lst"
                 log="&__outdir.&file..lst" new;
      run;
    %put &_tstamp1;%put &_tstamp2;%put &_tstamp1;
  %end;
  %else %do;
    %put Note: Routing SAS log to file &__logdir.&file..log;
    %put Note: Routing SAS output to file &__outdir.&file..lst;
    %put Note: Call LCB macro CLEANUP to re-route output and log;
    proc printto print="&__outdir.&file..lst"
                 log="&__logdir.&file..log" new;
      run;
    %put &_tstamp1;%put &_tstamp2;%put &_tstamp1;
  %end;
%end;


%EXIT:
  options notes _last_=&_tpdsn1_ &_tpopt1_;
%EXIT2:
  %*put Note: MEB macro PRINTTO finished execution.;

%mend;
options source;
