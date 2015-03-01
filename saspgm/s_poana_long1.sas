*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_poana_long1.sas                                             ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Poisson regression following mothers from -12 month to +12    ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...: ana1 diag2                                                    ;
* Data created: est1-est3                                                     ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M0P061913                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
*%inc saspgm(mebpoisint5) / source;  *-- Macro for splitting time for poisson regression;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;

*------------------------------------------------------------------------------------;
* Create time-splitted dataset starting follow-up one year before birth of the child ;
* psych_dat as first_dep_one_year_bef = postp_dat if happens after birth of child    ;
*------------------------------------------------------------------------------------;
proc sql;
  create table t0 as
  select a.mother_id, a.mother_bdat, a.child_bdat, b.psych_dat as first_dep_one_year_bef length=4 format=yymmdd10.,
         a.mage, a.mbyear, a.cbyear, a.mbyear_cat, a.mage_cat, a.cbyear_cat,
         round(12*(b.psych_dat - a.child_bdat)/365.25,0.001) as dep_mon length=6 label='Month for depression',
         round((b.psych_dat - a.mother_bdat)/365.25,0.001) as dep_age length=6 label='Age at depression',
         a.postp_dat
  from ana1 as a
  left join (select mother_id, min(psych_dat) as psych_dat from diag2
                    where psych_dat >= intnx('year',child_bdat,-1,'same')+1 and
                          psych_dat <= intnx('year',child_bdat, 1,'same')-1
                    group by mother_id) as b
  on a.mother_id = b.mother_id
  ;
quit;

data t1;
  attrib mbyear     length=4 label='Mother Birth Year'
         cbyear     length=4 label='Child Birth Year'
         exit       length=8 label='Exit month, from -1 yr'
         cens       length=3 label='Censored (Y/N)'
         event      length=3 label='Depr within one yr (Y/N)'
  ;
  set t0;

  entry = -12; event=0;

  if first_dep_one_year_bef>.z then do;
    exit=dep_mon; event=1;
  end;
  else exit=12;

  cens=1-event;

  *-- Data exclusions ;
  if mage<15 then delete;
  if mage>49 then delete;
run;


options stimer;
*-- To run it most efficient start split time then add all baseline characteristics;
%mebpoisint(data=t1, out=t3, entry=entry, exit=exit, event=event,
            split_start=-12, split_end=12, split_step=1, droplimits=Y, logrisk=N,
            id=mother_id);


*-- Create additional format, -12 instead of -12--11 and 0 instead of 0-1;
proc format cntlout=slask1;select __ivl__;run;
data slask2;
*  drop label0;
  length label $12;
  set slask1(keep=start end type label rename=(label=label0));
  fmtname='__ivl2__';
  i=input(compress(start),8.);

  label=put(i-13,4.);
run;
ods listing close;
proc format cntlin=slask2 noprint;select __ivl2__;run;
ods listing;


*-- Join in covariates;
*-- Variable count_births needed to count children born;
proc sql;
  create table t4 as
  select a.mother_id, a.interval format=__ivl2__., a._risk, a._no_of_events, a.event,
         b.mbyear, b.cbyear, b.mage, b.mage_cat, b.mbyear_cat, b.cbyear_cat,
         case c.dephist when 1 then 1 else 0 end as dephist length=3 label='Depr hist before 1 year bef birth' format=yesno.,
         case a.interval  when 1 then 1 else 0 end as count_births length=3 label='Birth (Y/N)'
  from t3 as a
  left join t1 as b
    on a.mother_id=b.mother_id
  left join dephistold as c
    on a.mother_id=c.mother_id
  order by a.mother_id, a.interval
  ;
quit;

*-----------------------------------------------------;
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=t4 nway;
  var event _risk count_births;
  class cbyear_cat cbyear dephist mage_cat dephist interval;
  output out=t5(drop=_type_ _freq_) sum=;
run;


data t6;
  attrib interval label='Month since birth' big_int length=3 label='Year bef or after birth';
  set t5 end=eof;
  rate = 10000*event/(_risk);
  logoffset=log(_risk);

  *-- The year before or following birth;
  if interval LT 13 then big_int=1;
  else if interval GE 13 then big_int=2;
run;

*=======================================================;
* Rate developments -12 to +12 month                    ;
*=======================================================;

*-- General rate development (adj for calendar time, maternal);
title1 'Depr rates -12 to +12 month';
title2 'Adjusted for dephist mage_cat cbyear_cat';
%tit(prog=s_poana_long1);

ods output lsmeans=lsm1;
ods select lsmeans;
proc glimmix data=t6 order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = dephist mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval / ilink plots alpha=0.05;
run;


*-- Rate development by depressive history at -12 month (adj for calendar time, maternal);
title1 'Depr rates -12 to +12 month by depression history';
title2 'Adjusted for dephist mage_cat cbyear_cat';
%tit(prog=s_poana_long1);

ods output lsmeans=lsm2;
ods select lsmeans;
proc glimmix data=t6 order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = dephist mage_cat cbyear_cat interval interval*dephist
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval*dephist / ilink plots alpha=0.05;
run;

*-- Rate development by maternal age and depressive history at -12 month (adj for calendar time, maternal);
title1 'Depr rates -12 to +12 month by maternal age';
title2 'Adjusted for dephist mage_cat cbyear_cat';
%tit(prog=s_poana_long1);

proc sort data=t6 out=temp;by dephist interval;run;
ods output lsmeans=lsm3;
ods select lsmeans;
proc glimmix data=temp order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = mage_cat dephist cbyear_cat interval interval*mage_cat
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval*mage_cat / ilink plots alpha=0.05;
run;

*-- For plotting purposes only. Rates by dep history;
ods listing close;
ods output lsmeans=lsm4;
proc sort data=temp;by dephist;run;
proc glimmix data=temp order=internal;
  class interval cbyear_cat mage_cat;
  model event = mage_cat  cbyear_cat interval interval*mage_cat
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval*mage_cat / ilink plots alpha=0.05;
  by dephist;
run;
ods listing;

*-- Rescale the rates to cases per 10,000;
data lsmx1;
  label mu='Rate per 10,000';
  rename mu=p lowermu=lcl uppermu=ucl;
  set lsm1(keep=interval mu lowermu uppermu);
  mu     =exp(log(mu*10000)) ;
  lowermu=exp(log(lowermu*10000)) ;
  uppermu=exp(log(uppermu*10000)) ;
run;

data lsmx2;
  label mu='Rate per 10,000';
  rename mu=p lowermu=lcl uppermu=ucl;
  set lsm2(keep=interval mu lowermu uppermu dephist);
  mu     =exp(log(mu*10000)) ;
  lowermu=exp(log(lowermu*10000)) ;
  uppermu=exp(log(uppermu*10000)) ;
run;

data lsmx3;
  label mu='Rate per 10,000';
  rename mu=p lowermu=lcl uppermu=ucl;
  set lsm3(keep=interval mu lowermu uppermu mage_cat);
  if mu>0.000001 then mu     =exp(log(mu*10000)) ;
  if lowermu>0.000001 then lowermu=exp(log(lowermu*10000)) ;
  if uppermu>0.000001 then uppermu=exp(log(uppermu*10000)) ;
run;

data lsmx4;
  label mu='Rate per 10,000';
  rename mu=p lowermu=lcl uppermu=ucl;
  set lsm4(keep=interval mu lowermu uppermu dephist mage_cat);
  if mu>0.000001 then mu     =exp(log(mu*10000)) ;
  if lowermu>0.000001 then lowermu=exp(log(lowermu*10000)) ;
  if uppermu>0.000001 then uppermu=exp(log(uppermu*10000)) ;
run;


*-- Define output directory for the figures ;
data _null_;
  call symput('slask',trim(pathname('result')));
run;


title;
ods listing  gpath="&slask";
ods graphics / reset=index imagefmt=png imagename="dephist";
title1 'Depression rate by depression history';
proc sgpanel data=lsmx2;
  panelby dephist / rows=1 columns=2 novarname;
  series x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5  legendlabel='95% CI';
  colaxis values=(1 to 24 by 1);
  rowaxis logbase=2 logstyle=logexpand;
  refline 13 / axis=x;
*  format interval 8.;
run;

proc sgplot data=lsmx2;
  series x=interval y=p / group=dephist;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=dephist legendlabel='95% CI';
  xaxis values=(1 to 24 by 1);
  yaxis logbase=2 type=log logstyle=logexpand;
run;



ods graphics / reset=index imagefmt=png imagename="mage";
title1 'Depression rate by maternal age';
proc sgpanel data=lsmx3;
  where mage_cat ne 7;
  panelby mage_cat / rows=2 columns=3 novarname;
  series x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 legendlabel='95% CI';
  colaxis values=(1 to 24 by 1);
  rowaxis logbase=2 logstyle=logexpand;
  refline 13 / axis=x;
*  format interval 8.;
run;

data lsmy3;
  set lsmx3;
  if mage_cat not in (3) then do;lcl=p;ucl=p;end;
run;
proc sgplot data=lsmy3;
  where mage_cat ne 7;
  series x=interval y=p / group=mage_cat;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=mage_cat legendlabel='95% CI';
  xaxis values=(1 to 24 by 1);
  yaxis logbase=2 type=log logstyle=logexpand;
run;


title1 'Depression rate by maternal age - Mothers with NO history of depression';
proc sgpanel data=lsmx4;
  where mage_cat ne 7 and dephist=0;
  panelby mage_cat / rows=2 columns=3 novarname;
  series x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 legendlabel='95% CI';
  colaxis values=(1 to 24 by 1);
  rowaxis logbase=2 logstyle=logexpand;
  refline 13 / axis=x;
*  format interval 8.;
run;

data lsmy4;
  set lsmx4;
  if mage_cat not in (3) then do;lcl=p;ucl=p;end;
run;
proc sgplot data=lsmy4;
  where mage_cat ne 7 and dephist=0;
  series x=interval y=p / group=mage_cat;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=mage_cat legendlabel='95% CI';
  xaxis values=(1 to 24 by 1);
  yaxis logbase=2 type=log logstyle=logexpand;
run;

ods listing close;
ods graphics off;



*---------------------------------------;
* Calculate RR contrasts                ;
*---------------------------------------;
options ls=160;

ods select  estimates;
title1 'Risk of depression from -1 year to +1 year';
title2 'Adjusted by dephist mage_cat cbyear_cat';
%tit(prog=s_poana_long1);
ods output estimates=est1;
proc glimmix data=t6 order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = dephist mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate 'Year after vs year before' interval -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
                                              1 1 1 1 1 1 1 1 1 1 1 1 / exp alpha=0.05 divisor=24;

  estimate '11 month after vs 11 months before' interval -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1  0
                                              0 1 1 1 1 1 1 1 1 1 1 1 / exp alpha=0.05 divisor=22;

  estimate '12 month bef ' interval 1 0 0 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate '11 month bef ' interval 0 1 0 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate '10 month bef ' interval 0 0 1 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 9 month bef ' interval 0 0 0 1 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 8 month bef ' interval 0 0 0 0 1 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 7 month bef ' interval 0 0 0 0 0 1 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 6 month bef ' interval 0 0 0 0 0 0 1 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 5 month bef ' interval 0 0 0 0 0 0 0 1 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 4 month bef ' interval 0 0 0 0 0 0 0 0 1 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 3 month bef ' interval 0 0 0 0 0 0 0 0 0 1 0 0 -1 / exp alpha=0.05 ;
  estimate ' 2 month bef ' interval 0 0 0 0 0 0 0 0 0 0 1 0 -1 / exp alpha=0.05 ;
  estimate ' 1 month bef ' interval 0 0 0 0 0 0 0 0 0 0 0 1 -1 / exp alpha=0.05 ;
  estimate ' 1 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
run;


*-----------------------------------------------------------------;
* Restrict to women with history of depressions before -12 month  ;
*-----------------------------------------------------------------;
title1 'Risk of depression from -1 year to +1 year. Restricted to mothers with depr. history at -12 month';
title2 'Adjusted by dephist mage_cat cbyear_cat';
%tit(prog=s_poana_long1);

ods output estimates=est2;
proc glimmix data=t6 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_cat;
  model event = mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s;

  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate 'Year after vs year before' interval -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
                                              1 1 1 1 1 1 1 1 1 1 1 1 / exp alpha=0.05 divisor=24;

  estimate '11 month after vs 11 months before' interval -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1  0
                                              0 1 1 1 1 1 1 1 1 1 1 1 / exp alpha=0.05 divisor=22;

  estimate '12 month bef ' interval 1 0 0 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate '11 month bef ' interval 0 1 0 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate '10 month bef ' interval 0 0 1 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 9 month bef ' interval 0 0 0 1 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 8 month bef ' interval 0 0 0 0 1 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 7 month bef ' interval 0 0 0 0 0 1 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 6 month bef ' interval 0 0 0 0 0 0 1 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 5 month bef ' interval 0 0 0 0 0 0 0 1 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 4 month bef ' interval 0 0 0 0 0 0 0 0 1 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 3 month bef ' interval 0 0 0 0 0 0 0 0 0 1 0 0 -1 / exp alpha=0.05 ;
  estimate ' 2 month bef ' interval 0 0 0 0 0 0 0 0 0 0 1 0 -1 / exp alpha=0.05 ;
  estimate ' 1 month bef ' interval 0 0 0 0 0 0 0 0 0 0 0 1 -1 / exp alpha=0.05 ;
  estimate ' 1 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
run;


*--------------------------------------------------------------------;
* Restrict to women with NO history of depressions before -12 month  ;
*--------------------------------------------------------------------;
title1 'Risk of depression from -1 year to +1 year. Restricted to mothers with NO depr. history at -12 month';
title2 'Adjusted by dephist mage_cat cbyear_cat';
%tit(prog=s_poana_long1);

ods output estimates=est3;
proc glimmix data=t6 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_cat;
  model event = mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s;

  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate 'Year after vs year before' interval -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
                                              1 1 1 1 1 1 1 1 1 1 1 1 / exp alpha=0.05 divisor=24;

  estimate '11 month after vs 11 months before' interval -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1  0
                                              0 1 1 1 1 1 1 1 1 1 1 1 / exp alpha=0.05 divisor=22;

  estimate '12 month bef ' interval 1 0 0 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate '11 month bef ' interval 0 1 0 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate '10 month bef ' interval 0 0 1 0 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 9 month bef ' interval 0 0 0 1 0 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 8 month bef ' interval 0 0 0 0 1 0 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 7 month bef ' interval 0 0 0 0 0 1 0 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 6 month bef ' interval 0 0 0 0 0 0 1 0 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 5 month bef ' interval 0 0 0 0 0 0 0 1 0 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 4 month bef ' interval 0 0 0 0 0 0 0 0 1 0 0 0 -1 / exp alpha=0.05 ;
  estimate ' 3 month bef ' interval 0 0 0 0 0 0 0 0 0 1 0 0 -1 / exp alpha=0.05 ;
  estimate ' 2 month bef ' interval 0 0 0 0 0 0 0 0 0 0 1 0 -1 / exp alpha=0.05 ;
  estimate ' 1 month bef ' interval 0 0 0 0 0 0 0 0 0 0 0 1 -1 / exp alpha=0.05 ;
  estimate ' 1 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval 0 0 0 0 0 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
run;


*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete t0 t3-t6 slask1-slask2 lsm1-lsm4 lsmx1-lsmx4 lsmy3 lsmy4;
quit;

*-- End of File --------------------------------------------------------------;
