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
         famsit label='Family Situation (1=Living with partner)'
  from connection to oracle (
  select lopnrmor, malder, x_mfoddat, x_bfoddat, paritet_f, secmark, grvbs
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

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete br0 br1 psychotic dephist dephist1yr postpart diag1 diag2;
quit;

*-- End of File --------------------------------------------------------------;

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
         a.postp_dat,
  from ana1 as a
  left join (select mother_id, min(psych_dat) as psych_dat from diag2
                    where psych_dat >= intnx('year',child_bdat,-1,'same')+1 and
                          psych_dat <= intnx('year',child_bdat, 1,'same')-1
                    group by mother_id) as b
  on a.mother_id = b.mother_id
  ;
quit;

proc format;
  value mage 1='15-19' 2='20-24' 3='25-29' 4='30-34' 5='35-39' 6='40-44' 7='45-49';
  value cyr  1='1997-2002' 2='2003-2008';
run;

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
  mage=intck('year', mother_bdat, child_bdat, 'c');

  mbyear=year(mother_bdat);
  cbyear=year(child_bdat);

  entry = -12; event=0;

  if first_dep_one_year_bef>.z then do;
    exit=dep_mon; event=1;
  end;
  else exit=12;

  cens=1-event;

*  if exit_mo ne 1 then exit_mo=exit_mo+0.0000001;
*if _n_  or mother_id=67427 ;
*  if mbyear <1960 or mbyear>1989 then delete;

  mbyear_cat=round(mbyear-5, 10);
  mage_cat  =round(mage, 5);

  if cbyear GE 1997 and cbyear LE 2002 then cbyear_cat=1;
  else if cbyear GE 2003 and cbyear LE 2008 then cbyear_cat=2;
  else abort;

  if mage<15 then delete;
  if mage>49 then delete;

  if mage LE 19 then mage_cat=1;
  else if mage LE 24 then mage_cat=2;
  else if mage LE 29 then mage_cat=3;
  else if mage LE 34 then mage_cat=4;
  else if mage LE 39 then mage_cat=5;
  else if mage LE 44 then mage_cat=6;
  else if mage LE 49 then mage_cat=7;

run;

proc means data=t1 n sum;
  var event;
  class mbyear;
run;


proc freq data=t1;
  table mage_cat cbyear_cat;
  table mage_cat*cbyear_cat / nopercent norow;
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

proc means data=t4 n sum mean;
var event;
class interval;
run;

*-----------------------------------------------------;
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=t4 nway;
*  where interval > 12 ;
  var event _risk count_births;
  class cbyear_cat cbyear dephist mage_cat dephist interval;
  output out=t5(drop=_type_ _freq_) sum=;
run;

proc format;
  value mbcfmt 1960='1960-69' 1970='1970-79' 1980='1980-89';
run;

data t6;
  attrib interval label='Month since birth';
  set t5 end=eof;
  rate = 10000*event/(_risk);
  logoffset=log(_risk);
run;

*-- Add values to predict;
data t7;
  set t6 end=eof;
  output;

  if eof then do cbyear_cat=1, 2;
    _risk=.; *mage=25; mage_cat=3; dephist=0;
    do interval=1 to 24 by 1;
      event=.; logoffset=log(10000);
      output;
    end;
  end;
run;


ods output lsmeans=lsm1;
proc glimmix data=t7 order=internal;
*  effect spl=spline(interval / naturalcubic);
  class interval cbyear_cat mage_cat dephist;
  model event = dephist mage_cat cbyear_cat interval cbyear_cat*interval
  / dist=poisson offset=logoffset link=log s;
  lsmeans interval / ilink plots;
  output out=pred1 pred(ilink)=p lcl(ilink)=lcl ucl(ilink)=ucl stderr;
run;


proc sql;
  create table pred2 as
  select distinct cbyear_cat, interval, p label='Cases per 10,000', lcl, ucl
  from pred1
  where event=.
  order by cbyear_cat, interval;
quit;

title;
ods listing  gpath='/home/svesan';
ods graphics / reset=index imagefmt=png imagename="cbyear_adjj";

proc sgpanel data=pred2;
  panelby cbyear_cat / rows=2 columns=2 novarname;
  series x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5;
  colaxis values=(1 to 24 by 1);
  rowaxis logbase=2 logstyle=logexpand;
  refline 13 / axis=x;
*  format interval 8.;
run;

proc sgplot data=pred2;
  series x=interval y=p / group=cbyear_cat;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=cbyear_cat;
  xaxis values=(1 to 24 by 1);
  yaxis logbase=2 type=log logstyle=logexpand;
run;




/*
proc sgpanel data=splest2;
5118      +  where model='Adjusted';
5119      +  panelby sglegend2 / rows=2 novarname;
5120      +  band x=ipage lower=explower upper=expupper / group=mat_sub transparency=0.5;
5121      +  series x=ipage y=expestimate / group=mat_sub;
5122      +  rowaxis type=log logbase=2 min=0.5 max=3;
5123      +  refline 1 / axis=y;
5124      +run;
*/


proc freq data=t4;
table mbyear;
run;


proc freq data=t3;
table interval*event / nocol nopercent;
run;




data _null_;
same=intnx('year', '21feb2000'd, 1, 'same');
beg=intnx('year', '21feb2000'd, 1, 'beginning');
put same= date9. beg= date9.;
run;



data check;
set ana1(keep=mage child_bdat mother_bdat);
run;
