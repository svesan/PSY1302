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
         grvbs as preg_len length=4 label='Pregnancy length (weeks)'
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
data dephist dephist1yr(rename=(dephist_dat=dep1yr_dat));
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
  left join diag2 as b
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






data t1;
  attrib mbyear length=4 label='Mother Birth Year'
         cbyear length=4 label='Child Birth Year'
  ;
  set ana1;
  mbyear=year(mother_bdat);
  cbyear=year(child_bdat);

  entry = 0;
  one_yr_bef=entry-12;

  if exit_mo ne 1 then exit_mo=exit_mo+0.0000001;
*if _n_  or mother_id=67427 ;
  if mbyear <1960 then delete;
run;

*-- Collapse the data;
*proc sql;
  create table t1b as
  select mbyear
;




options stimer;
*-- To run it most efficient start split time then add all baseline characteristics;
%mebpoisint(data=t1, out=t2, entry=one_yr_bef, exit=exit_mo, event=event,
            split_start=-12, split_end=12, split_step=1, droplimits=Y, logrisk=N,
            id=mother_id);

*-- Join in covariates;
proc sql;
  create table t3 as
  select a.mother_id, a.interval, a._risk, a._no_of_events, a.event,
         b.mage, b.cs, b.dephist, b.psycho,
         b.mbyear
  from t2 as a
  left join t1 as b
  on a.mother_id=b.mother_id
  ;
quit;

proc means data=t3 n sum mean;
var event;
class interval;
run;

*-----------------------------------------------------;
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=t3 nway;
  where interval > 12 ;
  var event _risk;
  class mbyear interval;
  output out=t4(drop=_type_ _freq_) sum=;
run;

proc format;
  value mbcfmt 1960='1960-69' 1970='1970-79' 1980='1980-89';
run;

data t5;
  attrib mbyear_cat length=3 label='Mother Birhth Year' format=mbcfmt. interval label='Month since birth';
  set t4 end=eof;
  rate = 10000*event/(_risk);
  logoffset=log(_risk);

  if mbyear le 1989 and interval < 25 then do;
    mbyear_cat=round(mbyear-5, 10);
  end;
  else delete;
run;

*-- Add values to predict;
data t6;
  set t5 end=eof;
  output;

  if eof then do mbyear_cat=1960 to 1980 by 10;
    _risk=.;
    do interval=13 to 24 by 1;
      event=.; logoffset=log(10000);
      output;
    end;
  end;
run;



ods output lsmeans=lsm1;
proc glimmix data=t6;
*  effect spl=spline(interval / naturalcubic);
  class interval mbyear_cat;
  model event = mbyear_cat interval mbyear_cat*interval
  / dist=poisson offset=logoffset link=log;
  lsmeans interval / ilink plots;
  output out=pred1 pred=p lcl ucl stderr;
run;


proc sql;
  create table pred2 as
  select distinct mbyear_cat, interval, p label='Cases per 10,000', lcl, ucl
  from pred1
  where event=.
  order by mbyear_cat, interval;
quit;

title;
ods listing  gpath='/home/svesan';
ods graphics / reset=index imagefmt=png imagename="mbyear";

proc sgpanel data=pred2;
  panelby mbyear_cat / rows=2 columns=2 novarname;
  series x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5;
run;

proc sgplot data=pred2;
  series x=interval y=p / group=mbyear_cat;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=mbyear_cat;
  xaxis values=(13 to 24 by 1);

*  yaxis logbase=2 type=log logstyle=logexpand;
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


proc freq data=t3;
table mbyear;
run;
