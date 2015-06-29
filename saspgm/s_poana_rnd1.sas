*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_poana_rnd1.sas                                              ;
* Date........: 2015-04-01                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Analyse PPD using randomly assigned date of delivery          ;
* Note........: Analysis suggested by Paul                                    ;
*-----------------------------------------------------------------------------;
* Data used...: rnd_ana1                                                      ;
* Data created:                                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M2P072314                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
*%inc saspgm(s_dmpaul);
%inc saspgm(mebpoisint5) / source;  *-- Macro for splitting time for poisson regression;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;

*------------------------------------------------------------------------------------;
* Basic summary statistics                                                           ;
*------------------------------------------------------------------------------------;

data check;
  label equal   ='Woman randomly assigned her own date of delivery'
        equal_wk='Woman randomly assigned a date of delivery +- 7 days from her own'
  ;
  set rnd_bdat;
  *if round(child_bdat, 0.01) = round(original_child_bdat);

  *equal=( (diff_dat)<0.0001 );
  if child_bdat = original_child_bdat then equal=1;
  else equal=0;

  if abs(child_bdat - original_child_bdat) le 7 then equal_wk=1;
  else equal_wk=0;

run;

title1 'Frequencies. Women randomized to her own date of delivery or to another womans';
%tit(prog=s_rnd_poana1);
proc freq data=check;
  table equal equal_wk;
run;


*------------------------------------------------------------------------------------;
* Run the code from s_poana_ppd8.sas program on the newly derived scrambled data     ;
*------------------------------------------------------------------------------------;

proc sql;
  create table s1 as
  select mother_id, 0 as entry, exit_mo, event, cs, preg_len, deform, withfather, dephist,
         mage, mbyear_cat, cbyear_cat, mage_catb, psycho, (exit_mo-0)/12 as pyear,
         sfinkt, forltyp, prodeliv, bp, wperc, diab, plen_cat, cbmi, orig_dephist
  from rnd_ana1
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
         b.mage, b.mage_catb, b.mbyear_cat, b.cbyear_cat,
         b.cs, b.preg_len, b.deform, b.withfather, b.psycho, b.dephist, b.orig_dephist,
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
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=s3 nway missing;
  var event _risk;
  class cbyear_cat dephist mage_catb dephist orig_dephist cs plen_cat preg_len
        deform withfather psycho sfinkt wperc forltyp prodeliv bp diab interval cbmi;
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

title1 'Risk of PPD. Using a random date of delivery instead of the womans true';
title2 'Note: Depr. history and PPD outcome is also derived from the random date of delivery';
title3 'Adjusting for interval dephist mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab';
%tit(prog=s_rnd_poana1);
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist cs deform withfather sfinkt forltyp prodeliv bp wperc diab plen_cat ;

  model event = interval dephist mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab
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

run;


title1 'Risk of PPD using true date of delivery to derive depr. history. Using a random date of delivery instead of the womans true';
title2 'Note: Depr. history and PPD outcome is also derived from the random date of delivery';
title3 'Adjusting for interval orig_dephist mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab';
%tit(prog=s_rnd_poana1);
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb orig_dephist cs deform withfather sfinkt forltyp prodeliv bp wperc diab plen_cat ;

  model event = interval orig_dephist mage_catb cbyear_cat cs plen_cat deform withfather sfinkt forltyp prodeliv bp wperc diab
  / dist=poisson offset=logoffset link=log s htype=2;

  estimate 'With depr. history' orig_dephist -1 1 / exp alpha=0.05;

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

run;


title1 'Distribution of depr history and PPD using true and permuted date of delivery';
%tit(prog=s_rnd_poana1);
proc freq data=rnd_ana1;
  table dephist orig_dephist postpartum orig_postpartum;
run;

title1 'Profile ML confidence intervals instead of Wald - Risk of PPD. Using a random date of delivery instead of the womans true';
%tit(prog=s_rnd_poana1);
ods output include parameterestimates;
proc genmod data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist;
  model event = dephist mage_catb cbyear_cat interval
  / dist=poisson offset=logoffset link=log LRCI;
run;

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete s1-s5 check;
quit;

*-- End of File --------------------------------------------------------------;
