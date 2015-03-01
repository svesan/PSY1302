*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_dm3.sas                                                     ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Data management creating analysis dataset for postpart depr   ;
* Note........: 140123 updated codes with Michael and Christina               ;
*-----------------------------------------------------------------------------;
* Data used...: crime2 tables v_mfr_base v_patient_diag                       ;
* Data created: ana1                                                          ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.03.01M2P081512                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
*%inc saspgm(mebpoisint5) / nosource; *-- Macro to split time ;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;
rsubmit;

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

*endrsubmit;
*libname sw  server=skjold slibref=work;

*rsubmit;


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
    where (substr(diagnos,1,5) in ('29620', '29621', '29622', '29623', '29630' ,'29632', '29634', '29699', '296B','30110', '30120', '30130')) or 
          (substr(diagnos,1,4) in ('301B','309','311','648E','648E0', '648E3')) or
          (substr(diagnos,1,3) in (''F32','F33','F34','F38','F39','F53'))
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
  attrib withfather length=3 format=yesno. label='Living with father'
         deform length=3 format=yesno. label='Deformation'
  ;
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

  *-- Resolve missing values from the registers;
  if missbs eq '1' then deform=1;else deform=0;
  if famsit eq '' then withfather=0;
  else withfather=1;

  if cs le .z then cs=0;

run;


*-- Analysis dataset;
data ana1(where=(_mis_=0));
  drop _a_ _b_;
  retain _a_ _b_ 0;
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
  set br2(drop=missbs famsit) end=eof;

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


  *-- Exclude due to missing values;
  _mis_=0;
  if preg_len le .z then do;_mis_=1;_a_=_a_+11; end;
  if cs le .z then do; _mis_=1; _b_=_b_+1; end;

  if eof then do;
    put 'Warning: ' _a_ ' records deleted due to missing pregnancy length';
    put 'Warning: ' _b_ ' records deleted due to missing CS';
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
proc download data=diag2      out=sasperm.diag2;run;
proc download data=dephistold out=sasperm.dephistold;run;

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
* delete br0 br1 psychotic dephist dephist1yr postpart diag1 diag2;
quit;

*-- End of File --------------------------------------------------------------;
