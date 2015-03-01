*-- Need to define variables;
* a) depression history before -1 year
* b) psycho history before -1 year;

*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_dm1.sas                                                     ;
* Date........: 2013-11-07                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Data management creating analysis dataset for postpart depr   ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...: crime2 tables v_mfr_base v_patient_diag                       ;
* Data created: ana1                                                          ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.03.01M2P081512                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
%inc saspgm(mebpoisint5) / nosource; *-- Macro to split time ;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;
proc format;
  value yesno 1='Yes' 0='No';
  value mage 1='15-19' 2='20-24' 3='25-29' 4='30-34' 5='35-39' 6='40-44' 7='45-49';
  value cyr  1='1997-2002' 2='2003-2008';
  value mbcfmt 1960='1960-69' 1970='1970-79' 1980='1980-89';
run;

*-- Main program -------------------------------------------------------------;
/* THIS ALLOWS ME TO ACCESS THE KI SERVER*/
options stimer;

libname crime2 oracle dbprompt=no user=micsil pw="cd92An_yt7"  path=UNIVERSE schema=mgrcrime2 connection=GLOBALREAD readbuff=4000 updatebuff=40;

*libname loc server=skjold slibref=crime2;
endrsubmit;
libname sw  server=skjold slibref=work;

rsubmit;


*-- Select all children born between 1997 and 2008;

*-- Select the mothers and then the depression diagnoses ;
proc sql;
  connect to oracle (user=svesan pw="{SAS002}1EA5152055A835B6561F91FA343842795497A910" path=UNIVERSE);
  execute (alter session set current_schema=mgrcrime2 ) by oracle;

  create table br0 as
  select lopnrmor as mother_id, malder as mage length=4 label='Maternal age',
         input(trim(x_mfoddat)||'01', yymmdd8.) as mother_bdat length=4 format=yymmdd10. label='Mother date of birth',
         input(x_bfoddat, yymmdd8.) as child_bdat length=4 format=yymmdd10. label='Date of birth',
         paritet_f as parity length=3 label='Parity',
         input(secmark,8.) as cs length=3 format=yesno. label='Ceasarean Section',
         grvbs as preg_len length=4 label='Pregnancy length (weeks)',
         missb as missbs label='Malformation',
         famsit label='Family Situation (1=Living with partner)'
  from connection to oracle (
  select lopnrmor, malder, x_mfoddat, x_bfoddat, paritet_f, secmark, grvbs,
         famsit, rok1, missb
  from v_mfr_base
  )
  having child_bdat >= '01JAN1997'd and child_bdat < '01JAN2009'd
  ;
* disconnect from oracle;


  create table diag1 as
  select LOPNR as mother_id, input(x_date, yymmdd8.) as psych_dat length=4 format=date9. label='Date depression',
         in_nr, diag_nr, icd_nr length=3 label='ICD', source,
         diagnos as diagnos label='Diagnosis'

  from connection to oracle (
    select LOPNR, IN_NR, DIAG_NR, ICD_NR, diagnos, SOURCE, x_date

    from v_patient_diag
    where substr(diagnos,1,3) in ('F32','F33','F34','F38','F53','296','301','F309','311','642','648')
    order by lopnr
  );
  disconnect from oracle;

run;quit;


*-- WARNING: From now on only considering the 1st child born in the chosen birth interval ;
proc sort data=br0;by mother_id child_bdat;
data br1;
  set br0;by mother_id child_bdat;
  if first.mother_id;
run;


*-- Sort datasets since datasets later will require this;
proc sort data=diag1;by mother_id psych_dat;run;


*-- Only consider diagnosis in mothers selected;
proc sql;
  create table diag2 as
  select b.*, a.child_bdat
  from br1 as a
  join diag1 as b
  on a.mother_id=b.mother_id
  ;
quit;


*-- Creating depression psych history variable;
data dephist
     dephist1yr(rename=(dephist_dat=dep1yr_dat) label='Depr hist within one yr bef birth')
     dephistold(rename=(dephist_dat=depold_dat) label='Depr hist before one yr bef birth')
  ;
  attrib dephist_dat length=4 format=yymmdd10. label='Date of 1st depression'
         dephist     length=3 format=yesno.    label='Psychiatric History (Y/N)'
  ;
  keep mother_id dephist_dat dephist;
  set diag2; by mother_id psych_dat;
  dephist=1;

  if first.mother_id and psych_dat < child_bdat then do;
    dephist_dat=psych_dat;
    output dephist;

    if psych_dat>intnx('year', child_bdat, -1, 'same') then output dephist1yr;
    else if psych_dat<intnx('year', child_bdat, -1, 'same')+1 then output dephistold;
  end;
  else delete;
run;


*-- Creating postpartum depression variable;
data postpart1;
  keep mother_id postp_dat postpartum;
  attrib postp_dat    length=4 format=yymmdd10. label='Date of postpartum event'
         postpartum   length=3 format=yesno.    label='Post Partum (Y/N)'
  ;
  set diag2(in=diag1 keep=mother_id psych_dat child_bdat);

  by mother_id;
  if psych_dat - child_bdat > 365 then delete;
  else if psych_dat < child_bdat then delete;

  else do;
    postp_dat=psych_dat;
    postpartum=1;
    output;
  end;
run;


*-- Currently, there may be several rows of postpartum for a single woman. Keep the 1st one only;
proc sort data=postpart1;by mother_id postp_dat;run;
data postpart;
  set postpart1;by mother_id postp_dat;
  if first.mother_id;
run;


*-- Create a dataset that is inclusive of psychosis;
data psychotic;
  attrib psycho      length=3 format=yesno.    label='Psychosis History (Y/N)'
         psycho_dat  length=4 format=yymmdd10. label='Date of psychosis';

  keep mother_id psycho psycho_dat;
  set diag2;

  if substr(left(diagnos),1,4) in ('F322') and psych_dat<child_bdat then do;
    psycho=1;
    psycho_dat=psych_dat;
  end;
  else delete;
run;

*-- ... from this create psychotic history ;
proc sort data=psychotic;by mother_id psycho_dat;run;
proc sort data=psychotic nodupkey;by mother_id;run;


*-- Create analysis dataset by combining the variables defined above;
data br2;
  merge br1 (in=br1)
        dephist(in=in_dephist)
        dephist1yr(in=in_dephist)
        postpart(in=postpart)
        psychotic(in=psychotic)
        ;
  by mother_id;

  if br1 then do;
    *-- Depression history;
    if not in_dephist then dephist=0;

    *-- Postpartum ;
    if not postpart then postpartum=0;

    *-- Psychotic history;
    if not psychotic then psycho=0;
  end;
run;


*-- Analysis dataset;
data ana1;
  attrib cens  length=3 label='Censored (Y/N)'
         event length=3 label='Postpartum event (Y/N)'
         exit  length=4 label='Age at cohort exit'
         mother_id label='Mother ID'

         mbyear     length=4 label='Mother Birth Year'
         cbyear     length=4 label='Child Birth Year'
         mbyear_cat length=3 label='Mother Birth Year' format=mbcfmt.
         cbyear_cat length=3 label='Child Birth Year'  format=cyr.
         mage_cat   length=3 label='Child Birth Year'  format=mage.
         mage       length=4 label='Mother age'
         exit_mo             label='Month of cohort exit';
  ;
  set br2;

  if postp_dat>.z then do;
    exit   =(postp_dat - child_bdat)/365.25;
    exit_mo=exit*12;
    cens=0; event=1;
  end;
  else do;
    exit=1; cens=1; event=0; exit_mo=12;
  end;

  *-- Variables on mother and child birth date ;
  mage=intck('year', mother_bdat, child_bdat, 'c');

  mbyear=year(mother_bdat);
  cbyear=year(child_bdat);

  mbyear_cat=round(mbyear-5, 10);
  mage_cat  =round(mage, 5);

  if cbyear GE 1997 and cbyear LE 2002 then cbyear_cat=1;
  else if cbyear GE 2003 and cbyear LE 2008 then cbyear_cat=2;
  else abort;

  if mage LE 19 then mage_cat=1;
  else if mage LE 24 then mage_cat=2;
  else if mage LE 29 then mage_cat=3;
  else if mage LE 34 then mage_cat=4;
  else if mage LE 39 then mage_cat=5;
  else if mage LE 44 then mage_cat=6;
  else if mage LE 49 then mage_cat=7;
run;


*-- Dataset with psych episodes within one year bef or after birth;
proc sql;
  create table dep_events(label='Depression within one year surrounding birth') as
  select a.mother_id, b.psych_dat,
         round(12*(b.psych_dat - a.child_bdat)/365.25,0.001) as dep_mon length=6 label='Month for depression',
         round((b.psych_dat - a.mother_bdat)/365.25,0.001) as dep_age length=6 label='Age at depression'
  from ana1 as a
  left join (select mother_id, min(psych_dat) as psych_dat from diag2
                    where psych_dat >= intnx('year',child_bdat,-1,'same') group by mother_id) as b
  on a.mother_id = b.mother_id
  ;
quit;

proc download data=ana1       out=sasperm.ana1;run;
proc download data=dep_events out=sasperm.dep_events;run;
proc download data=diag2      out=sasperm.diag2;run;
proc download data=dephistold out=sasperm.dephistold;run;

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
* delete br0 br1 psychotic dephist dephist1yr postpart diag1 diag2;
quit;

*-- End of File --------------------------------------------------------------;
endrsubmit;
proc copy in=sasperm out=work;run;


*------------------------------------------------------------------------------------;
* Create time-splitted dataset starting follow-up one year before birth of the child ;
* psych_dat as first_dep_one_year_bef = postp_dat if happens after birth of child    ;
*------------------------------------------------------------------------------------;
proc sql;
  create table t0 as
  select a.mother_id, a.mother_bdat, a.child_bdat, b.psych_dat as first_dep_one_year_bef length=4 format=yymmdd10.,
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
         mbyear_cat length=3 label='Mother Birth Year' format=mbcfmt.
         cbyear_cat length=3 label='Child Birth Year'  format=cyr.
         mage_cat   length=3 label='Child Birth Year'  format=mage.
         mage       length=4 label='Mother age'
  ;
  set t0;

  entry = -12; event=0;

  if first_dep_one_year_bef>.z then do;
    exit=dep_mon; event=1;
  end;
  else exit=12;

  cens=1-event;

  *-- Variables on mother and child birth date ;
  mage=intck('year', mother_bdat, child_bdat, 'c');

  mbyear=year(mother_bdat);
  cbyear=year(child_bdat);

  mbyear_cat=round(mbyear-5, 10);
  mage_cat  =round(mage, 5);

  if cbyear GE 1997 and cbyear LE 2002 then cbyear_cat=1;
  else if cbyear GE 2003 and cbyear LE 2008 then cbyear_cat=2;
  else abort;

  if mage LE 19 then mage_cat=1;
  else if mage LE 24 then mage_cat=2;
  else if mage LE 29 then mage_cat=3;
  else if mage LE 34 then mage_cat=4;
  else if mage LE 39 then mage_cat=5;
  else if mage LE 44 then mage_cat=6;
  else if mage LE 49 then mage_cat=7;

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
ods output lsmeans=lsm1;
ods select lsmeans;
proc glimmix data=t7 order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = dephist mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval / ilink plots alpha=0.05;
run;

*-- Rate development by depressive history at -12 month (adj for calendar time, maternal);
ods output lsmeans=lsm2;
ods select lsmeans;
proc glimmix data=t7 order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = dephist mage_cat cbyear_cat interval interval*dephist
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval*dephist / ilink plots alpha=0.05;
run;

*-- Rate development by maternal age and depressive history at -12 month (adj for calendar time, maternal);
proc sort data=t7 out=temp;by dephist interval;run;
ods output lsmeans=lsm3;
ods select lsmeans;
ods graphics;
proc glimmix data=temp order=internal;
  class interval cbyear_cat mage_cat dephist;
  model event = mage_cat dephist cbyear_cat interval interval*mage_cat
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval*mage_cat / ilink plots alpha=0.05;
run;

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



title;
ods listing  gpath='/home/svesan';
ods graphics / reset=index imagefmt=png imagename="dephist";

proc sgpanel data=lsmx2;
  panelby dephist / rows=1 columns=2 novarname;
  series x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5;
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
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=mage_cat;
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
ods output estimates=est1;
proc glimmix data=t7 order=internal;
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
title1 'Restricted to mothers with depr. history at -12 month';
ods output estimates=est2;
proc glimmix data=t7 order=internal;
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
title1 'Restricted to mothers with NO depr. history at -12 month';
ods output estimates=est3;
proc glimmix data=t7 order=internal;
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


%macro prtest(data=);
  data temp;
    attrib contrast length=$20 label='Contrast';
    set &data;
    ci=put(expestimate,5.2)||' ('||put(explower,5.2)||'-'||put(expupper,5.2)||')';
    if substr(label,1,5)='M.Age' then contrast='Maternal Age';
    else if scan(reverse(label),1)='feb' then contrast='Monthly';
    else if scan(reverse(label),1)='retfa' then contrast='Monthly';
    else contrast='Year bef and after';
  run;

  proc print data=temp label noobs uniform;
    var label probt ci;
    by contrast notsorted;id contrast;
  run;
%mend;

title1 'RR of depression';
title2 'Following mothers from 1 year bef birth to 1 year after';
title3 'All mothers. Adjust for month from birth, calendar time, maternal age and depr. history';
%prtest(data=est1);

title1 'RR of depression - Restricted to mothers with depr. history at -12 month';
title2 'Following mothers from 1 year bef birth to 1 year after';
title3 'All mothers. Adjust for month from birth, calendar time, maternal age and depr. history';
%prtest(data=est2);

title1 'RR of depression - Restricted to mothers with NO depr. history at -12 month';
title2 'Following mothers from 1 year bef birth to 1 year after';
title3 'All mothers. Adjust for month from birth, calendar time, maternal age and depr. history';
%prtest(data=est3);

**************************************************************;
* Start follow-up at birth                                    ;
**************************************************************;
proc sql;
  create table s1 as
  select mother_id, 0 as entry, exit_mo, event, cs, preg_len, missbs, famsit, dephist
  from ana1;
quit;

*-- To run it most efficient start split time then add all baseline characteristics;
%mebpoisint(data=s1, out=s2, entry=entry, exit=exit_mo, event=event,
            split_start=0, split_end=12, split_step=1, droplimits=Y, logrisk=N,
            id=mother_id);


*-- Join in covariates;
*-- Variable count_births needed to count children born;
proc sql;
  create table s3 as
  select a.mother_id, a.interval, a._risk, a._no_of_events, a.event,
         b.mbyear, b.cbyear, b.mage, b.mage_cat, b.mbyear_cat, b.cbyear_cat,
         b.cs, b.preg_len, b.missbs, b.famsit,
         case c.dephist when 1 then 1 else 0 end as dephist length=3 label='Depr hist before birth bef birth' format=yesno.
  from s2 as a
  left join s1 as b
    on a.mother_id=b.mother_id
  left join dephistold as c
    on a.mother_id=c.mother_id
  order by a.mother_id, a.interval
  ;
quit;
