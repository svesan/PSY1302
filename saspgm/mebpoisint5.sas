* 16-nov-2011. Warn of there are data outside the entry exit limits;
* 16-nov-2011. Now run without bystmt as well;
* 16-nov-2011. Added processing time;
* 16-nov-2011. Now variable _no_of_events set to length=6;
* 16-nov-2011. Now warn if created dataset > 1GB;
* 16-nov-2011. Added parameter LOGRISK=Y;
* 11-sep-2008. Bug fix. Earlier event was assigned for all intervals. Not only the one effected;
* 26-oct-2009. Now variables EVENT is set to length=3 and _no_of_events;
* 27-oct-2009. Now variables INTERVAL dataset is created by the macro. Parameter removed;
* 27-oct-2009. Added parameter format. if Y then a format is created and attached to the interval varaible. if N the format is not created and instead a and b are kept in the dataset;

/****** Update the macro:
1. Update so that bystmt is not needed
2. ERROR: Entry later than exit. Macro aborts._N_=102356  stop after first 20
3. Check variables exist.
4. What checks are being done on number of events ?.

NB: THE MACRO ASSUME EXACTLY ONE ROW FOR EACH SUBJECT

*/

options nosource;
%macro mebpoisint(data=, out=, entry=, exit=, event=, bystmt=, id=, split_start=, split_end=, split_step=1, format=Y, droplimits=N, logrisk=Y);

%local bystmt2 bystmt3;

%let bystmt2= ;%let bystmt3= ;

data __start_tid__;time=time();run;

%if %bquote(&bystmt) ^= %then %do;
  data _null_;
    %*-- bystmt variable with comma for proc sql use  ;
    call symput('bystmt2',tranwrd(compbl("&bystmt"),' ',','));
  run;
  %let bystmt2=&bystmt2,;

  %*------------------------------------------;
  %* A third bystmt variable for proc sql     ;
  %*------------------------------------------;
  %let i=0;
  %do %until(&tmp= );
    %let i=%eval(&i+1);
    %let tmp=%scan(&bystmt, &i);
  %end;

  %let i=%eval(&i-1);
  %do j=1 %to &i;
    %if &j=1 %then %let bystmt3=a.%scan(&bystmt, &j) = b.%scan(&bystmt, &j);
    %else %let bystmt3=&bystmt3 AND a.%scan(&bystmt, &j) = b.%scan(&bystmt, &j);
  %end;
  %let bystmt3=&bystmt3 AND ;
%end;

%*-- Create dataset for the time splitting intervals ;
data _interval_;
  length interval a b 8;
  interval=0;
  do a=&split_start to &split_end by &split_step;
    interval=interval + &split_step;
    b = a + &split_step;
    output;
  end;
run;


%let slask=;
data _tmp1;
  drop __c1__ __c2__;
  rename &event=__xevent__;
  retain __c1__ __c2__ 0;
  set &data(keep=&entry &exit &event &id &bystmt);
  if &entry > &exit then do;
    put 'ERROR: Entry later than exit. Macro aborts.' _n_=;
    call symput('slask','ERROR');
  end;

  *-- 111116 add check that no events outside declared start and end;
  if __c1__=0 then do;
    if &entry < &split_start then do;
      put "WARNING: Observations before &split_start. These data will be lost. E.g. " _n_= &entry=; __c1__=1;
    end;
  end;
  if __c2__=0 then do;
    if &exit > &split_end then do;
      put "WARNING: Observations after &split_end. These data will be lost. E.g. " _n_= &exit=; __c2__=1;
    end;
  end;
run;

%if &slask=ERROR %then %goto exit;


* Note: if entry=a then excluded. Can affect analysis if cases occur at entry;
proc sql;
  create table _tmp2(drop=__xevent__) as
  select a.*, b.*,
        case when (b.&exit < a.a) then 0
             when (b.&entry <= a.a and b.&exit <= a.b) then b.&exit-a.a
             when (b.&entry >  a.a and b.&exit <= a.b) then b.&exit-b.&entry
             when (b.&entry > a.a and b.&entry <  a.b and b.&exit >  a.b) then a.b   -b.&entry
             when (b.&entry >  a.b                  ) then 0
             when (b.&entry <= a.a and b.&exit >  a.b) then a.b   -a.a
	     else -99999999999
        end as _risk,
        case when (a.b >= b.&exit and b.__xevent__>0) then 1 else 0 end as &event length=3
  from _interval_ as a
  join _tmp1 as b
  on not (b.&entry>=a.b OR b.&exit<=a.a);
  ;
quit;

%if %bquote(&bystmt)^= %then %str(proc sort data=_tmp2;by &bystmt;run;);


*-- Check if events in all interval cells;
proc sql;
  create table &out as
  select a.*, b._no_of_events label='Total # events. To check for empty cells' length=6
  %if %bquote(%upcase(&logrisk))=Y %then %str(, case _risk when 0 then .u else log(_risk) end as _logrisk);
  from _tmp2 as a
  join (select &bystmt2 interval, sum(&event) as _no_of_events length=4 from _tmp2 group by &bystmt2 interval) as b
  on &bystmt3  a.interval=b.interval
  order by &bystmt2 interval;
quit;

*-- Create and attach format ;
%if %bquote(&format)=Y %then %do;
  data _tmp8;
    retain fmtname '__IVL__' type 'num';
    set _interval_(rename=(interval=start));
    end=start;
    label=right(put(a,3.))||'-'||left(put(b,3.));
  run;

  proc format lib=work cntlin=_tmp8 ;run;

  %put Note: Now assigning format __ivl__ to the time-split variable INTERVAL;
  proc datasets lib=work mt=data nolist;
    modify &out; format interval __ivl__.;
  quit;
%end;

*-- Drop the time interval limits ;
%if %bquote(&droplimits)=Y %then %do;
  *-- Drop the time interval borders since these are in the formatted variable interval ;
  proc sql;
    alter table &out drop a,b;
  quit;
%end;


*-- Add check if events in all cells defined by interval and model covariates ?;
proc freq data=&out;
  table interval * &event / out=_tmp3 noprint sparse;
run;
proc freq data=&out;
  table interval * &event / out=_tmp4 noprint sparse;
run;

proc sql;
  create table _tmp5 as
  select min(count) as min1, max(count) as max1,
         min(percent) as pct1, max(percent) as pct2
  from _tmp3
  where &event=1;

  create table _tmp6 as
  select min(count) as min2, max(count) as max2,
         min(percent) as pct3, max(percent) as pct4
  from _tmp4
  where &event=1;
quit;


options mergenoby=nowarn;
data _null_;
  merge _tmp5 _tmp6;
  ptxt1=compress(put(min1,8.))||' ('||compress(put(pct1, 4.1)||'%)');
  ptxt2=compress(put(max2,8.))||' ('||compress(put(pct2, 4.1)||'%)');

  if "%bquote(&bystmt)"^="" then do;
    ptxt3=compress(put(min2,8.))||' ('||compress(put(pct3, 4.1)||'%)');
    ptxt4=compress(put(max2,8.))||' ('||compress(put(pct4, 4.1)||'%)');
    put "Note: Assuming events by variable EVENT=&event are coded as one (&event=1)";
    put 'Note: Overall there is between ' ptxt1 'and ' ptxt2 'events in the different intervals';
    put '      Between ' ptxt3 'and ' ptxt4 "in the intervals in the sub-groups defined by the BYSTMT variable";
  end;
  else do;
    put "Note: Assuming events by variable EVENT=&event are coded as one (&event=1)";
    put 'Note: Overall there is between ' ptxt1 'and ' ptxt2 'events in the different intervals';
  end;
run;
options mergenoby=warn;

*-- Warn if created dataset bigger than 1 GB;
%let slask=0;
proc sql noprint;
  select int(round(filesize/1000000000,0.1)-0.1) into : slask from dictionary.tables where libname='WORK' and upcase(memname)="%upcase(&out)";
quit;
%let slask=&slask;

%if &slask>1 %then  %put WARNING: Created dataset > &slask.GB. Consider dropping variables or assign proper LENGTH= statement to variables;


%exit:

data _null_;
  set __start_tid__;
  diff=time()-time;
  minut=minute(diff);
  second=second(diff);
  slask=compress(put(minut,8.)||'.'||put(second,8.));
  call symput('slask', compress(put(minut,8.)||'.'||put(second,8.)));
run;


options _last_=&out;
proc datasets lib=work mt=data nolist;
  delete _tmp1-_tmp8 _interval_ __start_tid__;
run;quit;


%put Note: Macro MEBPOISINT finished execution. Processing time &slask min.sec;


%mend;
options source;
/*******************
*----------------------------------------------------------;
* Run the calculations for the incidence data              ;
*----------------------------------------------------------;
data xpoana1;
  set hf_final_tr(keep=subject code entry exit event nexit nentry
                       xhiv xsyp xgenwart xage xsexdebut xhcg xsexdebcat
                       xeverpreg xagecat);

* where code in (1001,1002,1016,56,1999,1018);
  if subject=252 and code=16;
nexit=3.49;
run;



%mebpoisint(data=xpoana1, interval=interval, out=xpoana2, entry=nentry, exit=nexit, event=event,
            bystmt=code, id=code subject xage xsexdebut xsyp xhiv xgenwart xagecat xsexdebcat xhcg xeverpreg);

******************/
