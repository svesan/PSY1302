*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_poana_ppd2.sas                                              ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Poisson regression of PPD starting follow-up from birth       ;
* Note........: Bug fix. In _ppd1 dephist was defined as dephist at -12 month ;
*-----------------------------------------------------------------------------;
* Data used...: ana1                                                          ;
* Data created: ppdest1-ppdest3                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M0P061913                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
*%inc saspgm(mebpoisint5) / source;  *-- Macro for splitting time for poisson regression;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;
proc sql;
  create table s1 as
  select mother_id, 0 as entry, exit_mo, event, cs, preg_len, deform, withfather, dephist,
         mage, mbyear_cat, cbyear_cat, mage_cat, psycho, event
  from ana1
  where mage GE 15 and mage LE 49
  ;
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
         b.mage, b.mage_cat, b.mbyear_cat, b.cbyear_cat,
         b.cs, b.preg_len, b.deform, b.withfather, b.psycho, b.dephist,
         case when c.dephist eq 1 then 1 else 0 end as dephistold length=3 label='Depr hist before -12 month' format=yesno.
  from s2 as a
  left join s1 as b
    on a.mother_id=b.mother_id
  left join dephistold as c
    on a.mother_id=c.mother_id
  order by a.mother_id, a.interval
  ;
quit;

*-----------------------------------------------------;
* Summary statistics                                  ;
*-----------------------------------------------------;
title1 'Summary statistics: PPD analysis';
%tit(prog=s_poana_ppd2);
proc means data=s1 n nmiss mean stderr q1 q3 min max sum maxdec=1;
  var event mage preg_len deform cs withfather dephist psycho;
run;

title1 'PPD frequencis by exposure';
%tit(prog=s_poana_ppd2);
proc freq data=s1;
  table (cbyear_cat dephist mage_cat dephist cs deform withfather psycho)*event / missing nocol nopercent;
run;


title1 'PPD frequencis by time internal';
%tit(prog=s_poana_ppd2);
proc freq data=s3;
  table (interval)*event / missing nocol nopercent;
run;


title1 'Cumulative PPD count by time';
%tit(prog=s_poana_ppd1);
proc freq data=s1;
  where event=1;
  table exit_mo / outcum out=s6 noprint;
run;

data s7;
  label cum_freq='Cum Freq' exit_mo='Month';
  set s6;
  exit_mo=round(exit_mo, 0.01);
run;

*%scarep(data=s7,var=exit_mo cum_freq,panels=10,syntax=y);

PROC REPORT DATA=s7 LS=130 PS=43  SPLIT=" " PANELS=10  PSPACE=4   HEADLINE NOCENTER MISSING nowindows;
  COLUMN  ( ("--"  EXIT_MO CUM_FREQ ) );

  DEFINE  EXIT_MO / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Month" ;
  DEFINE  CUM_FREQ / DISPLAY FORMAT= 4. WIDTH=4     SPACING=1   RIGHT ORDER=INTERNAL "Cum Freq" ;
RUN;QUIT;


*-----------------------------------------------------;
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=s3 nway missing;
  var event _risk;
  class cbyear_cat dephist mage_cat dephist cs preg_len deform withfather psycho interval;
  output out=s4(drop=_type_ _freq_) sum=event _risk;
run;

data s5;
  attrib interval label='Month since birth';
  set s4 end=eof;
  rate = 10000*event/(_risk);
  logoffset=log(_risk);
run;


*---------------------------------------;
* Calculate RR contrasts                ;
*---------------------------------------;
options ls=160;

*ods select estimates;
title1 'Risk of PPD. All women';
title2 'Adjusting for interval cbyear_cat mage_cat dephist';
%tit(prog=s_poana_ppd2);
ods output estimates=ppdest1;
proc glimmix data=s5 order=internal;
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

  estimate ' 1 month after' interval  -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval  -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval  -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval  -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval  -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval  -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval  -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval  -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval  -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval  -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval  -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
run;


title1 'Risk of PPD. Restricted to mothers with depr. history bef birth';
title2 'Adjusting for interval cbyear_cat mage_cat';
%tit(prog=s_poana_ppd2);
ods output estimates=ppdest2;
proc glimmix data=s5 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_cat;
  model event = mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate ' 1 month after' interval  -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval  -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval  -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval  -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval  -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval  -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval  -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval  -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval  -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval  -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval  -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
run;


title1 'Risk of PPD. Restricted to mothers with NO depr. history bef birth';
title2 'Adjusting for interval cbyear_cat mage_cat';
%tit(prog=s_poana_ppd2);
ods output estimates=ppdest3;
proc glimmix data=s5 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_cat;
  model event = mage_cat cbyear_cat interval
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate ' 1 month after' interval  -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval  -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval  -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval  -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval  -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval  -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval  -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval  -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval  -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval  -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval  -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
run;



*-------------------------------------------------------------------------;
* Include CS, Living with father of child, pregnancy length, deformations ;
*-------------------------------------------------------------------------;
options ls=160;

*ods select estimates;
title1 'Risk of PPD. All women';
title2 'Adjusting for interval cbyear_cat mage_cat dephist  deform withfather psycho';
%tit(prog=s_poana_ppd2);
ods output estimates=ppdest1;
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_cat dephist cs deform withfather psycho;
  model event = dephist mage_cat cbyear_cat interval cs preg_len deform withfather psycho
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate ' 1 month after' interval  -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval  -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval  -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval  -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval  -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval  -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval  -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval  -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval  -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval  -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval  -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;

  estimate 'Mo. living with childs father' withfather -1 1 / exp alpha=0.05;
  estimate 'CS'                            cs         -1 1 / exp alpha=0.05;
  estimate 'Deformation'                   deform     -1 1 / exp alpha=0.05;
  estimate 'Pregnancy length, +1 week'     preg_len 1 / exp alpha=0.05;
  estimate 'History of psychosis'          psycho -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. Women with history of depression';
title2 'Adjusting for interval cbyear_cat mage_cat deform withfather psycho';
%tit(prog=s_poana_ppd2);
ods output estimates=ppdest2;
proc glimmix data=s5 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_cat  cs deform withfather psycho;
  model event =  mage_cat cbyear_cat interval cs preg_len deform withfather psycho
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate ' 1 month after' interval  -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval  -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval  -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval  -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval  -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval  -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval  -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval  -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval  -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval  -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval  -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;

  estimate 'Mo. living with childs father' withfather -1 1 / exp alpha=0.05;
  estimate 'CS'                            cs         -1 1 / exp alpha=0.05;
  estimate 'Deformation'                   deform     -1 1 / exp alpha=0.05;
  estimate 'Pregnancy length, +1 week'     preg_len 1 / exp alpha=0.05;
  estimate 'History of psychosis'          psycho -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. Women with NO history of depression';
title2 'Adjusting for interval cbyear_cat mage_cat deform withfather psycho';
%tit(prog=s_poana_ppd2);
ods output estimates=ppdest3;
proc glimmix data=s5 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_cat  cs deform withfather;
  model event =  mage_cat cbyear_cat interval cs preg_len deform withfather
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'M.Age 15-19 vs 25-29' mage_cat 1 0 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_cat 0 1 -1 0 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_cat 0 0 -1 1 0 0 0 / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_cat 0 0 -1 0 1 0 0 / exp alpha=0.05;
  estimate 'M.Age 40-44 vs 25-29' mage_cat 0 0 -1 0 0 1 0 / exp alpha=0.05;
  estimate 'M.Age 45-49 vs 25-29' mage_cat 0 0 -1 0 0 0 1 / exp alpha=0.05;

  estimate ' 1 month after' interval  -1 1 / exp alpha=0.05 ;
  estimate ' 2 month after' interval  -1 0 1 / exp alpha=0.05 ;
  estimate ' 3 month after' interval  -1 0 0 1 / exp alpha=0.05 ;
  estimate ' 4 month after' interval  -1 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 5 month after' interval  -1 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 6 month after' interval  -1 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 7 month after' interval  -1 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 8 month after' interval  -1 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate ' 9 month after' interval  -1 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '10 month after' interval  -1 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;
  estimate '11 month after' interval  -1 0 0 0 0 0 0 0 0 0 0 1 / exp alpha=0.05 ;

  estimate 'Mo. living with childs father' withfather -1 1 / exp alpha=0.05;
  estimate 'CS'                            cs         -1 1 / exp alpha=0.05;
  estimate 'Deformation'                   deform     -1 1 / exp alpha=0.05;
  estimate 'Pregnancy length, +1 week'     preg_len 1 / exp alpha=0.05;
* estimate 'History of psychosis'          psycho -1 1 / exp alpha=0.05;
run;


*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete s1-s7;
quit;

*-- End of File --------------------------------------------------------------;
