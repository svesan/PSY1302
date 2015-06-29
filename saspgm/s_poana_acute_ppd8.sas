*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_poana_acute_ppd8.sas                                        ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose..... : Poisson regression of PPD starting follow-up from birth      ;
* Note........: Bug fix. In _ppd1 dephist was defined as dephist at -12 month ;
* Note........: 140424 (a) added crude models, (b) added birth yr comparisons ;
* ............: to the earlier models, added printout of cases, pyear         ;
* Note........: 140625 added several covariates after talking to S Cnattingius;
* ............:                                                               ;
* Note........: 140715 (a) added plen_cat crude and as adjusted, (b) removed  ;
* ............: dephist covariates in adjusted subgroup analyses, (c) replaced;
* ............: preg_len with plen_cat when adjusting                         ;
* ............:                                                               ;
* Note........: 141205 (a) updated title rows to make printouts clearer       ;
* ............: (b) added a model with BMI but only as extra analysis since   ;
* ............: too many missing values on BMI                                ;
* ............:                                                               ;
* Note........: 150108 Following bug fix where PPD on day of birth were not   ;
* ............: counted sum stat was updated with data by history of depr.    ;
* ............:                                                               ;
* ............:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...: ana1                                                          ;
* Data created: acute_ppdest1a-acute_ppdest3a, acute_basic                    ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M0P061913                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
%inc saspgm(mebpoisint5) / source;  *-- Macro for splitting time for poisson regression;

*-- SAS macros ---------------------------------------------------------------;
/*
data ana1;
  retain seed 2387;
  attrib diab length=3 label='Diabetes' format=diab. bp format=bpfmt.;
  set sasperm.ana1;

  if uniform(seed) <0.30 then diab=1;
  else if uniform(seed) <0.70 then diab=6;
  else diab=0;
run;
data dephistold;set sasperm.dephistold;run;

*/
*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;
proc sql;
  create table s1 as
  select mother_id, 0 as entry, exit_acute_mo, event_acute, cs, preg_len, deform, withfather, dephist,
         mage, mbyear_cat, cbyear_cat, mage_catb, psycho, (exit_acute_mo-0)/12 as pyear,
         sfinkt, forltyp, prodeliv, bp, wperc, diab, plen_cat, cbmi
  from ana1
  where mage GE 15 and mage LE 49
  ;
quit;


*-- To run it most efficient start split time then add all baseline characteristics;
%mebpoisint(data=s1, out=s2, entry=entry, exit=exit_acute_mo, event=event_acute,
            split_start=0, split_end=12, split_step=1, droplimits=Y, logrisk=N,
            id=mother_id);


*-- Join in covariates;
*-- Variable count_births needed to count children born;
proc sql;
  create table s3 as
  select a.mother_id, a.interval, a._risk, a._no_of_events, a.event_acute,
         b.mage, b.mage_catb, b.mbyear_cat, b.cbyear_cat,
         b.cs, b.preg_len, b.deform, b.withfather, b.psycho, b.dephist,
         b.sfinkt, b.forltyp, b.prodeliv, b.bp, b.wperc, b.diab, b.plen_cat,
         case when c.dephist eq 1 then 1 else 0 end as dephistold length=3 label='Depr hist before -12 month' format=yesno.,
         b.cbmi
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
proc sort data=s1;by dephist;run;
proc sort data=s3;by dephist;run;

title1 'Summary statistics: PPD analysis';
%tit(prog=s_poana_acute_ppd8);
proc means data=s1 n nmiss mean stderr q1 q3 min max sum maxdec=1;
  var event_acute mage preg_len deform cs withfather dephist psycho sfinkt prodeliv bp cbmi;
run;

title1 'Summary statistics: PPD analysis - by history of depression';
%tit(prog=s_poana_acute_ppd8);
proc means data=s1 n nmiss mean stderr q1 q3 min max sum maxdec=1;
  var event_acute mage preg_len deform cs withfather psycho sfinkt prodeliv bp cbmi;
  class dephist;
run;


title1 'PPD frequencis by exposure';
%tit(prog=s_poana_acute_ppd8);
proc freq data=s1;
  table (cbyear_cat dephist mage_catb dephist cs deform withfather psycho
         sfinkt wperc forltyp prodeliv bp diab plen_cat cbmi)*event_acute / missing nocol nopercent;
run;

title1 'PPD frequencis by exposure - by history of depression';
%tit(prog=s_poana_acute_ppd8);
proc freq data=s1;
  table (cbyear_cat dephist mage_catb dephist cs deform withfather psycho
         sfinkt wperc forltyp prodeliv bp diab plen_cat cbmi)*event_acute / missing nocol nopercent;
run;


title1 'PPD frequency and number of birth';
%tit(prog=s_poana_acute_ppd8);
proc freq data=s1;
  table event_acute / missing nocol nopercent;
run;


title1 'PPD frequencis by time internal';
%tit(prog=s_poana_acute_ppd8);
proc freq data=s3;
  table (interval)*event_acute / missing nocol nopercent;
run;

title1 'PPD frequencis by time internal - by history of depression';
%tit(prog=s_poana_acute_ppd8);
proc freq data=s3;
  table (interval)*event_acute / missing nocol nopercent;
  by dephist;
run;



title1 'Cumulative PPD count by time';
%tit(prog=s_poana_acute_ppd8);
proc freq data=s1;
  where event_acute=1;
  table exit_acute_mo / outcum out=s6 noprint;
run;

data s7;
  label cum_freq='Cum Freq' exit_acute_mo='Month';
  set s6;
  exit_acute_mo=round(exit_acute_mo, 0.01);
run;

*%scarep(data=s7,var=exit_mo cum_freq,panels=10,syntax=y);

PROC REPORT DATA=s7 LS=130 PS=43  SPLIT=" " PANELS=10  PSPACE=4   HEADLINE NOCENTER MISSING nowindows;
  COLUMN  ( ("--"  EXIT_acute_MO CUM_FREQ CUM_PCT) );

  DEFINE  EXIT_acute_MO / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Month" ;
  DEFINE  CUM_FREQ / DISPLAY FORMAT= 4. WIDTH=4     SPACING=1   RIGHT ORDER=INTERNAL "Cum Freq" ;
  DEFINE  CUM_PCT / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Cum Pct" ;
RUN;QUIT;



*title1 'Cumulative PPD count by time - by history of depression';
*%tit(prog=s_poana_acute_ppd8);
proc freq data=s1;
  where event_acute=1;
  table exit_acute_mo / outcum out=t6 noprint;
  by dephist;
run;

data t7;
  label cum_freq='Cum Freq' exit_acute_mo='Month';
  set t6;
  exit_acute_mo=round(exit_acute_mo, 0.01);
run;

*%scarep(data=s7,var=exit_mo cum_freq,panels=10,syntax=y);
title1 'Cumulative PPD count by time - Among women WITHOUT a history of depression';
%tit(prog=s_poana_acute_ppd8);
PROC REPORT DATA=t7 LS=130 PS=43  SPLIT=" " PANELS=10  PSPACE=4   HEADLINE NOCENTER MISSING nowindows;
  where dephist=0;
  COLUMN  ( ("--"  EXIT_acute_MO CUM_FREQ CUM_PCT) );

* DEFINE  DEPHIST  / DISPLAY FORMAT=yesno. WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Depr History" ;
  DEFINE  EXIT_acute_MO  / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Month" ;
  DEFINE  CUM_FREQ / DISPLAY FORMAT= 4. WIDTH=4     SPACING=1   RIGHT ORDER=INTERNAL "Cum Freq" ;
  DEFINE  CUM_PCT  / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Cum Pct" ;
RUN;QUIT;


title1 'Cumulative PPD count by time - Among women WITH a history of depression';
%tit(prog=s_poana_acute_ppd8);
PROC REPORT DATA=t7 LS=130 PS=43  SPLIT=" " PANELS=10  PSPACE=4   HEADLINE NOCENTER MISSING nowindows;
  where dephist=1;
  COLUMN  ( ("--"  EXIT_acute_MO CUM_FREQ CUM_PCT) );

* DEFINE  DEPHIST  / DISPLAY FORMAT=yesno. WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Depr History" ;
  DEFINE  EXIT_acute_MO  / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Month" ;
  DEFINE  CUM_FREQ / DISPLAY FORMAT= 4. WIDTH=4     SPACING=1   RIGHT ORDER=INTERNAL "Cum Freq" ;
  DEFINE  CUM_PCT  / DISPLAY FORMAT= 5.2 WIDTH=5     SPACING=1   RIGHT ORDER=INTERNAL "Cum Pct" ;
RUN;QUIT;


*-----------------------------------------------------;
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=s3 nway missing;
  var event_acute _risk;
  class cbyear_cat dephist mage_catb dephist cs plen_cat preg_len
        deform withfather psycho sfinkt wperc forltyp prodeliv bp diab interval cbmi;
  output out=s4(drop=_type_ _freq_) sum=event_acute _risk;
run;

data s5;
  attrib interval label='Month since birth';
  set s4 end=eof;
  rate = 10000*event_acute/(_risk);
  logoffset=log(_risk);
run;


*---------------------------------------;
* Calculate RR contrasts                ;
*---------------------------------------;
options ls=160;

title1 'Risk of PPD. All women';
title2 'Adjusting for interval cbyear_cat mage_catb dephist';
%tit(prog=s_poana_acute_ppd8);
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist;
  model event_acute = dephist mage_catb cbyear_cat interval
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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
title2 'Adjusting for interval cbyear_cat mage_catb';
%tit(prog=s_poana_acute_ppd8);
*ods output estimates=acute_ppdest2;
proc glimmix data=s5 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_catb;
  model event_acute = mage_catb cbyear_cat interval
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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
title2 'Adjusting for interval cbyear_cat mage_catb';
%tit(prog=s_poana_acute_ppd8);
*ods output estimates=acute_ppdest3;
proc glimmix data=s5 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_catb;
  model event_acute = mage_catb cbyear_cat interval
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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
* 140625 added  sfinkt  forltyp prodeliv bp ;
*-------------------------------------------------------------------------;
options ls=160;

*ods select estimates;
title1 'Risk of PPD. All women';
title2 'Adjusting for interval dephist mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=acute_ppdest1;
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist cs deform withfather sfinkt forltyp prodeliv bp wperc diab plen_cat ;

  model event_acute = interval dephist mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab

  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;

  estimate 'SfinktR'                       sfinkt     -1 1 / exp alpha=0.05;
  estimate 'Prol. Deliv'                   prodeliv   -1 1 / exp alpha=0.05;

*-- 2014-12-05 bug fix by svesan;
*  estimate 'BP: Hypertonia'                bp          0 1 -1 / exp alpha=0.05;
*  estimate 'BP: Preeclampsia'              bp          1 0 -1 / exp alpha=0.05;
  estimate 'BP: Hypertonia'                bp         -1 0 1 / exp alpha=0.05;
  estimate 'BP: Hypertensive Disorder'     bp         -1 1 0 / exp alpha=0.05;

  estimate 'Diabetes'                      diab       -1 0.5 0.5 / exp alpha=0.05;
  estimate 'Diabetes, Pre-pregn'           diab       -1 0   1   / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'           diab       -1 1   0   / exp alpha=0.05;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;

  estimate 'Pregnancy length: <32 vs 37-41'     plen_cat  1  0 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: 32-36 vs 37-41'   plen_cat  0  1 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: >=42 vs 37-41'    plen_cat  0  0 -1  1 / exp alpha=0.05;

*  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
*  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
*  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


title1 'Risk of PPD. Women with history of depression';
title2 'Adjusting for interval mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab ';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=acute_ppdest2;
proc glimmix data=s5 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_catb cs deform withfather sfinkt forltyp prodeliv bp wperc diab plen_cat ;

  model event_acute = interval mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab

  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;

  estimate 'SfinktR'                       sfinkt     -1 1 / exp alpha=0.05;
  estimate 'Prol. Deliv'                   prodeliv   -1 1 / exp alpha=0.05;

*-- 2014-12-05 bug fix by svesan;
*  estimate 'BP: Hypertonia'                bp          0 1 -1 / exp alpha=0.05;
*  estimate 'BP: Preeclampsia'              bp          1 0 -1 / exp alpha=0.05;
  estimate 'BP: Hypertonia'                bp         -1 0 1 / exp alpha=0.05;
  estimate 'BP: Hypertensive Disorder'     bp         -1 1 0 / exp alpha=0.05;

  estimate 'Diabetes'                      diab       -1 0.5 0.5 / exp alpha=0.05;
  estimate 'Diabetes, Pre-pregn'           diab       -1 0   1   / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'           diab       -1 1   0   / exp alpha=0.05;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;

  estimate 'Pregnancy length: <32 vs 37-41'     plen_cat  1  0 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: 32-36 vs 37-41'   plen_cat  0  1 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: >=42 vs 37-41'    plen_cat  0  0 -1  1 / exp alpha=0.05;

*  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
*  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
*  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


title1 'Risk of PPD. Women with NO history of depression';
title2 'Adjusting for interval mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab ';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=acute_ppdest3;
proc glimmix data=s5 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_catb cs deform withfather sfinkt forltyp prodeliv bp wperc diab plen_cat ;

  model event_acute = interval mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab

  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;

  estimate 'SfinktR'                       sfinkt     -1 1 / exp alpha=0.05;
  estimate 'Prol. Deliv'                   prodeliv   -1 1 / exp alpha=0.05;

*-- 2014-12-05 bug fix by svesan;
*  estimate 'BP: Hypertonia'                bp          0 1 -1 / exp alpha=0.05;
*  estimate 'BP: Preeclampsia'              bp          1 0 -1 / exp alpha=0.05;
  estimate 'BP: Hypertonia'                bp         -1 0 1 / exp alpha=0.05;
  estimate 'BP: Hypertensive Disorder'     bp         -1 1 0 / exp alpha=0.05;

  estimate 'Diabetes'                      diab       -1 0.5 0.5 / exp alpha=0.05;
  estimate 'Diabetes, Pre-pregn'           diab       -1 0   1   / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'           diab       -1 1   0   / exp alpha=0.05;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;

  estimate 'Pregnancy length: <32 vs 37-41'     plen_cat  1  0 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: 32-36 vs 37-41'   plen_cat  0  1 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: >=42 vs 37-41'    plen_cat  0  0 -1  1 / exp alpha=0.05;

*  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
*  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
*  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


*=============================================================;
* The same models as above but replace preg_len with plen_cat ;
*=============================================================;

title1 'Risk of PPD. All women. Pregnancy length categorically instead of continuous and with psychosis.';
title2 'Adjusting for interval dephist mage_catb cbyear_cat cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab preg_len ';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=acute_ppdest4;
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab ;

  model event_acute = interval dephist mage_catb cbyear_cat cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab preg_len
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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
  estimate 'Pregnancy length, +1 week'     preg_len      1 / exp alpha=0.05;
  estimate 'History of psychosis'          psycho     -1 1 / exp alpha=0.05;

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;

  estimate 'SfinktR'                       sfinkt     -1 1 / exp alpha=0.05;
  estimate 'Prol. Deliv'                   prodeliv   -1 1 / exp alpha=0.05;

*-- 2014-12-05 bug fix by svesan;
*  estimate 'BP: Hypertonia'                bp          0 1 -1 / exp alpha=0.05;
*  estimate 'BP: Preeclampsia'              bp          1 0 -1 / exp alpha=0.05;
  estimate 'BP: Hypertonia'                bp         -1 0 1 / exp alpha=0.05;
  estimate 'BP: Hypertensive Disorder'     bp         -1 1 0 / exp alpha=0.05;

  estimate 'Diabetes'                      diab       -1 0.5 0.5 / exp alpha=0.05;
  estimate 'Diabetes, Pre-pregn'           diab       -1 0   1   / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'           diab       -1 1   0   / exp alpha=0.05;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;

*  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
*  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
*  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


title1 'Risk of PPD. Women WITH history of depression. Pregnancy length categorically instead of continuous and with psychosis.';
title2 'Adjusting for interval mage_catb cbyear_cat cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab preg_len ';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=acute_ppdest5;
proc glimmix data=s5 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_catb cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab ;

  model event_acute = interval mage_catb cbyear_cat cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab preg_len
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;


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

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;

  estimate 'SfinktR'                       sfinkt     -1 1 / exp alpha=0.05;
  estimate 'Prol. Deliv'                   prodeliv   -1 1 / exp alpha=0.05;

*-- 2014-12-05 bug fix by svesan;
*  estimate 'BP: Hypertonia'                bp          0 1 -1 / exp alpha=0.05;
*  estimate 'BP: Preeclampsia'              bp          1 0 -1 / exp alpha=0.05;
  estimate 'BP: Hypertonia'                bp         -1 0 1 / exp alpha=0.05;
  estimate 'BP: Hypertensive Disorder'     bp         -1 1 0 / exp alpha=0.05;

  estimate 'Diabetes'                      diab       -1 0.5 0.5 / exp alpha=0.05;
  estimate 'Diabetes, Pre-pregn'           diab       -1 0   1   / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'           diab       -1 1   0   / exp alpha=0.05;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;

*  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
*  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
*  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


title1 'Risk of PPD. Women with NO history of depression. Pregnancy length categorically instead of continuous.';
title2 'Adjusting for interval mage_catb cbyear_cat cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab preg_len ';
title3 'Note: Adjust for psycho not done since no data here';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=acute_ppdest6;
proc glimmix data=s5 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_catb cs deform withfather sfinkt forltyp prodeliv bp wperc diab ;

  model event_acute = interval mage_catb cbyear_cat cs deform withfather psycho sfinkt forltyp prodeliv bp wperc diab preg_len

  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;

  estimate 'SfinktR'                       sfinkt     -1 1 / exp alpha=0.05;
  estimate 'Prol. Deliv'                   prodeliv   -1 1 / exp alpha=0.05;

*-- 2014-12-05 bug fix by svesan;
*  estimate 'BP: Hypertonia'                bp          0 1 -1 / exp alpha=0.05;
*  estimate 'BP: Preeclampsia'              bp          1 0 -1 / exp alpha=0.05;
  estimate 'BP: Hypertonia'                bp         -1 0 1 / exp alpha=0.05;
  estimate 'BP: Hypertensive Disorder'     bp         -1 1 0 / exp alpha=0.05;

  estimate 'Diabetes'                      diab       -1 0.5 0.5 / exp alpha=0.05;
  estimate 'Diabetes, Pre-pregn'           diab       -1 0   1   / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'           diab       -1 1   0   / exp alpha=0.05;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;

*  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
*  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
*  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


*-- Join in pregnancy length RR continuously;
data acute_ppdest1a;
  set acute_ppdest1(in=acute_ppdest1)
      acute_ppdest4(in=acute_ppdest4)
  ;
  if acute_ppdest1 or (acute_ppdest4 and index(label,'Pregnancy length, +1 week')>0);
run;

data acute_ppdest2a;
  set acute_ppdest2(in=acute_ppdest2)
      acute_ppdest5(in=acute_ppdest5)
  ;
  if acute_ppdest2 or (acute_ppdest5 and index(label,'Pregnancy length, +1 week')>0);
run;

data acute_ppdest3a;
  set acute_ppdest3(in=acute_ppdest3)
      acute_ppdest6(in=acute_ppdest6)
  ;
  if acute_ppdest3 or (acute_ppdest6 and index(label,'Pregnancy length, +1 week')>0);
run;


*=====================================================;
* Crude models                                        ;
*=====================================================;

title1 'Risk of PPD. All women. Depr Hist - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest1;
proc glimmix data=s5 order=internal;
  class interval dephist;
  model event_acute= interval dephist
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Birth Years - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest2;
proc glimmix data=s5 order=internal;
  class interval cbyear_cat;
  model event_acute= interval cbyear_cat
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Maternal Age - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest3;
proc glimmix data=s5 order=internal;
  class interval mage_catb;
  model event_acute= interval mage_catb
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39 vs 25-29'   mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Living with father - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest4;
proc glimmix data=s5 order=internal;
  class interval withfather;
  model event_acute= interval withfather
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Mo. living with childs father' withfather -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. CS - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest5;
proc glimmix data=s5 order=internal;
  class interval cs;
  model event_acute= interval cs
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'CS'                            cs         -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Deformation - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest6;
proc glimmix data=s5 order=internal;
  class interval deform;
  model event_acute= interval deform
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Deformation'                   deform     -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Pregnancy length - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest7;
proc glimmix data=s5 order=internal;
  class interval ;
  model event_acute= interval preg_len
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Pregnancy length, +1 week'     preg_len 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Psychosis - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest8;
proc glimmix data=s5 order=internal;
  class interval psycho;
  model event_acute= interval psycho
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'History of psychosis'          psycho -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Sfinkter - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest9;
proc glimmix data=s5 order=internal;
  class interval sfinkt;
  model event_acute= interval sfinkt
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Sfinkter'          sfinkt -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Mode of delivery - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest10;
proc glimmix data=s5 order=internal;
  class interval forltyp;
  model event_acute= interval forltyp
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'Instr vs non-instr delivery'   forltyp   0 0 1 -1 / exp alpha=0.05;
  estimate 'Planned vs acute CS'           forltyp  -1 1 0  0 / exp alpha=0.05;
  estimate 'Acute vs non-acute delivery'   forltyp  -0.5 0.5 0.5 -0.5 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Prolonged delivery - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest11;
proc glimmix data=s5 order=internal;
  class interval prodeliv;
  model event_acute= interval prodeliv
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Prolonged delivery'          prodeliv -1 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. BP disease. Hypotonia - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest12;
proc glimmix data=s5 order=internal;
  class interval bp;
  model event_acute= interval bp
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Hypotonia'          bp -1 0 1 / exp alpha=0.05;
  estimate 'Pre-eclampsia'          bp -1 1 0 / exp alpha=0.05;
  estimate 'Blood pressure (Hypotonia or Preeclampsia)'  bp -1 0.5 0.5 / exp alpha=0.05;
run;



title1 'Risk of PPD. All women. SGA - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest13;
proc glimmix data=s5 order=internal;
  class interval wperc;
  model event_acute= interval wperc
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'SGA: small'                    wperc       1 -1 0 0 0 / exp alpha=0.05;
  estimate 'SGA: Moderately small'         wperc       0 -1 1 0 0 / exp alpha=0.05;
  estimate 'SGA: large'                    wperc       0 -1 0 1 0 / exp alpha=0.05;
  estimate 'SGA: very large'               wperc       0 -1 0 0 1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Diabetes pre-pregnancy - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest14;
proc glimmix data=s5 order=internal;
  class interval diab;
  model event_acute= interval diab
  / dist=poisson offset=logoffset link=log s htype=2;
  estimate 'Diabetes, Pre-pregnancy'    diab -1 0 1 / exp alpha=0.05;
  estimate 'Diabetes, Pregnancy'        diab -1 1 0 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. Pregnancy length categorically - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest15;
proc glimmix data=s5 order=internal;
  class interval plen_cat;
  model event_acute= interval plen_cat
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'Pregnancy length: <32 vs 37-41'     plen_cat  1  0 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: 32-36 vs 37-41'   plen_cat  0  1 -1  0 / exp alpha=0.05;
  estimate 'Pregnancy length: >=42 vs 37-41'    plen_cat  0  0 -1  1 / exp alpha=0.05;
run;


title1 'Risk of PPD. All women. BMI categorically - Crude.';
title2 'Adjusting for interval only';
%tit(prog=s_poana_acute_ppd8);
ods output estimates=cr_acute_ppdest16;
proc glimmix data=s5 order=internal;
  class interval cbmi;
  model event_acute= interval cbmi
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


*--------------------------------------------------------;
* Combine the crude estimates to one dataset             ;
*--------------------------------------------------------;
data crude_estimates;
  attrib label length=$60 label='Comparison';
  label expestimate='RR' explower='Lower CI' expupper='Upper CI';
  set cr_acute_ppdest1-cr_acute_ppdest16;
run;




*--------------------------------------------------------;
* Then calculate basic statistics by exposure category   ;
*--------------------------------------------------------;

%macro tmp(cat, ut, data=s1, bystmt=);
  %let tmp=&cat;
  %let xtmp="&cat" as covar length=12;

  %if %bquote(&bystmt)^= %then %do;
    %let tmp=&bystmt, &cat;
    %let xtmp="&cat" as covar length=12, "&bystmt" as byvar length=12;
  %end;

  proc sql;
    create table _v_ as
    select &xtmp, &tmp,
           sum(event_acute) as events, sum(pyear) as pyear,
           count(*) as subjects
    from &data
    group by &tmp;
  quit;

  data v&ut;
    drop &cat;
    attrib category length=$12 label='Category' lbl length=$40 label='Variable';
    set _v_;
    category = vvalue(&cat);
    lbl = label(&cat);
  run;

  proc datasets lib=work mt=data nolist;delete _v_;run;quit;

%mend;

*-- Calculate basic data overall;
proc summary data=s1 nway;
  var event_acute pyear;
  output out=v0 sum=events pyear n=subjects;
run;

%tmp(dephist, 1);
%tmp(cbyear_cat, 2);
%tmp(mage_catb, 3);
%tmp(withfather, 4);
%tmp(cs, 5);
%tmp(deform, 6);
%tmp(psycho, 7);

%tmp(sfinkt, 8);
%tmp(forltyp, 9);
%tmp(prodeliv, 10);
*%tmp(hyp, 11);
%tmp(bp, 11);
%tmp(wperc, 12);
%tmp(diab, 13);
%tmp(plen_cat, 14);
%tmp(cbmi, 15);


*--- Combine all RR;
data xtmp1;
  length variable $40;
  set v0(in=v0) v1-v15;
  if v0 then do; category='All women'; variable='<None>'; end;
run;


*--------------------------------------------------;
* Repeat for women with a history of depression    ;
*--------------------------------------------------;
proc datasets lib=work mt=data nolist;
  delete _v_ v0 v1-v15;
run;quit;


data xtmp2;
  set s1(where=(dephist=1));
run;

proc summary data=xtmp2 nway;
  where dephist=1;
  var event_acute pyear;
  output out=v0 sum=events pyear n=subjects;
run;



%tmp(dephist, 1 ,data=xtmp2);
%tmp(cbyear_cat, 2 ,data=xtmp2);
%tmp(mage_catb, 3 ,data=xtmp2);
%tmp(withfather, 4 ,data=xtmp2);
%tmp(cs, 5 ,data=xtmp2);
%tmp(deform, 6 ,data=xtmp2);
%tmp(psycho, 7 ,data=xtmp2);

%tmp(sfinkt, 8 ,data=xtmp2);
%tmp(forltyp, 9 ,data=xtmp2);
%tmp(prodeliv, 10 ,data=xtmp2);
*%tmp(hyp, 11 ,data=xtmp2);
%tmp(bp, 11 ,data=xtmp2);
%tmp(wperc, 12 ,data=xtmp2);
%tmp(diab, 13 ,data=xtmp2);
%tmp(plen_cat, 14 ,data=xtmp2);
%tmp(cbmi, 15 ,data=xtmp2);


*--- Combine all RR;
data xtmp3;
  length variable $40;
  set v0(in=v0) v1-v15;
  if v0 then do; category='All women'; variable='<None>'; end;
run;


*--------------------------------------------------;
* Repeat for women WITHOUT a history of depression ;
*--------------------------------------------------;
proc datasets lib=work mt=data nolist;
  delete _v_ v0 v1-v15;
run;quit;


data xtmp4;
  set s1(where=(dephist=0));
run;

proc summary data=xtmp4 nway;
  where dephist=0;
  var event_acute pyear;
  output out=v0 sum=events pyear n=subjects;
run;



%tmp(dephist, 1, data=xtmp4);
%tmp(cbyear_cat, 2, data=xtmp4);
%tmp(mage_catb, 3, data=xtmp4);
%tmp(withfather, 4, data=xtmp4);
%tmp(cs, 5, data=xtmp4);
%tmp(deform, 6, data=xtmp4);
%tmp(psycho, 7, data=xtmp4);

%tmp(sfinkt, 8, data=xtmp4);
%tmp(forltyp, 9, data=xtmp4);
%tmp(prodeliv, 10, data=xtmp4);
*%tmp(hyp, 11, data=xtmp2);
%tmp(bp, 11, data=xtmp4);
%tmp(wperc, 12, data=xtmp4);
%tmp(diab, 13, data=xtmp4);
%tmp(plen_cat, 14, data=xtmp4);
%tmp(cbmi, 15, data=xtmp4);


*--- Combine all RR;
data xtmp5;
  length variable $40;
  set v0(in=v0) v1-v15;
  if v0 then do; category='All women'; variable='<None>';end;
run;


*-- Now, create a dataset to print;
data acute_basic(label='Rate, cases, person year, percent PPD etc by exposure group');
  length sub $40;
  label pyear='Person Years' rate='Rate (acute PPD/10,000)' pct='Percent acute PPD' events='Acute PPD cases'
        subjects='Number of women(=births)' sub='Subgroup'
  ;
  format events rate comma6. subjects pyear comma9. pct 8.1;
  set xtmp1(in=xtmp1) xtmp3(in=xtmp3) xtmp5(in=xtmp5);

  if xtmp1 then do;sub='All women';  end;
  if xtmp3 then do;sub='With depression history'; end;
  if xtmp5 then do;sub='Without depression history'; end;

  rate = 10000 * events / pyear;
  pct  = put(100*events/subjects, 6.2);
run;


*---------------------------------------;
* Additional analyses for BMI           ;
* 2014-12-05 svesan                     ;
*---------------------------------------;
options ls=160;

title1 'Additional analysis for BMI. Risk of PPD. All women';
title2 'Adjusting for interval cbyear_cat mage_catb dephist  cbmi';
%tit(prog=s_poana_acute_ppd8);
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist cbmi;

  model event_acute= dephist mage_catb cbyear_cat interval cbmi
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'With depr. history' dephist -1 1 / exp alpha=0.05;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


title1 'Additional analysis for BMI. Risk of PPD. Restricted to mothers with depr. history bef birth';
title2 'Adjusting for interval cbyear_cat mage_catb cbmi';
%tit(prog=s_poana_acute_ppd8);
*ods output estimates=acute_ppdest2;
proc glimmix data=s5 order=internal;
  where dephist=1;
  class interval cbyear_cat mage_catb cbmi;

  model event_acute= mage_catb cbyear_cat interval cbmi
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


title1 'Additional analysis for BMI. Risk of PPD. Restricted to mothers with NO depr. history bef birth';
title2 'Adjusting for interval cbyear_cat mage_catb cbmi';
%tit(prog=s_poana_acute_ppd8);
proc glimmix data=s5 order=internal;
  where dephist=0;
  class interval cbyear_cat mage_catb cbmi;

  model event_acute= mage_catb cbyear_cat interval cbmi
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'B. Year 2003-2008 / 1997-2002' cbyear_cat -1 1 / exp alpha=0.05;

  estimate 'M.Age 15-19 vs 25-29' mage_catb 1 0 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 20-24 vs 25-29' mage_catb 0 1 -1 0 0 0   / exp alpha=0.05;
  estimate 'M.Age 30-34 vs 25-29' mage_catb 0 0 -1 1 0 0   / exp alpha=0.05;
  estimate 'M.Age 35-39 vs 25-29' mage_catb 0 0 -1 0 1 0   / exp alpha=0.05;
  estimate 'M.Age >39   vs 25-29' mage_catb 0 0 -1 0 0 1   / exp alpha=0.05;

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

  estimate 'BMI: <18.8 vs 18.5-25'   cbmi  1 -1  0  0 / exp alpha=0.05;
  estimate 'BMI: 25-35 vs 18.5-25'   cbmi  0 -1  1  0 / exp alpha=0.05;
  estimate 'BMI: >35 vs 18.5-25'     cbmi  0 -1  0  1 / exp alpha=0.05;
run;


*============================================;
*  Rescale the rates to cases per 10,000     ;
*  2014-12-05 svesan                         ;
*============================================;

*-- Rate development by depressive history (adj for calendar time, maternal);
ods output lsmeans=acute_ppd_lsm2;
ods select lsmeans;

proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist;

  model event_acute= dephist mage_catb cbyear_cat interval interval*dephist
  / dist=poisson offset=logoffset link=log s htype=2;

  lsmeans interval*dephist / ilink plots alpha=0.05;
run;


*--------------------------------------------;
*  Rescale the rates to cases per 10,000     ;
*--------------------------------------------;
data acute_ppd_lsmx2;
  label mu='Rate per 10,000';
  rename mu=p lowermu=lcl uppermu=ucl;
  set acute_ppd_lsm2(keep=interval mu lowermu uppermu dephist);
  mu     =exp(log(mu*10000)) ;
  lowermu=exp(log(lowermu*10000)) ;
  uppermu=exp(log(uppermu*10000)) ;
run;


*-- Define output directory for the figures ;
data _null_;
  call symput('slask',trim(pathname('result')));
run;


title;
ods listing  gpath="&slask";
ods graphics / reset=index imagefmt=png imagename="acute_ppd_dephist";
*title1 'Depression rate by depression history';
%tit(prog=s_poana_long3,h=0.91);
proc sgpanel data=acute_ppd_lsmx2;
  panelby dephist / rows=1 columns=2 novarname;
  step x=interval y=p;
  band   x=interval lower=lcl upper=ucl /transparency=0.5  legendlabel='95% CI' type=step;
  colaxis values=(1 to 12 by 1);
  rowaxis logbase=2 logstyle=logexpand;
  refline 13 / axis=x;
run;

proc sgplot data=acute_ppd_lsmx2;
  step  x=interval y=p / group=dephist;
  refline 13 / axis=x;
  band   x=interval lower=lcl upper=ucl /transparency=0.5 group=dephist legendlabel='95% CI' type=step;
  xaxis values=(1 to 12 by 1);
  yaxis logbase=2 type=log logstyle=logexpand;
run;

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete s1-s7 t6 t7 v1-v15 xtmp1-xtmp5 cr_acute_ppdest1-cr_acute_ppdest16
         acute_ppdest1-acute_ppdest6 acute_ppd_lsm2 acute_ppd_lsmx2;
quit;

*-- End of File --------------------------------------------------------------;
