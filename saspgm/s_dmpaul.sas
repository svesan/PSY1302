*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_dmpaul.sas                                                  ;
* Date........: 2015-04-01                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: DM for analysis of permuted delivery dates                    ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...: ana1, diag2                                                   ;
* Data created: rnd_ana1 rnd_bdat                                             ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M2P072314                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;

*------------------------------------------------------------------------------------;
* Select 1 random mothers child birth date from the mothers born the same year       ;
*------------------------------------------------------------------------------------;

data t1;
  drop seed;
  retain seed 2349778;
  set ana1(keep=mother_id mbyear child_bdat);
  x=uniform(seed);
run;


*-- List of mothers to study;
proc sort data=t1 out=t1;
  by mbyear mother_id;
run;

*-- Scramble the mothers to use as random birth dates ;
proc sort data=t1 out=t2;
  by mbyear x;
run;

*-- Now assign the random birth dates from mothers in T2 to mothers in T1 ;
data rnd_bdat(label='Permuted child birth dates');
  attrib diff_dat label='Years between true birth date and assigned random date' length=6;
  merge t1(keep=mother_id child_bdat mbyear
           rename=(child_bdat=original_child_bdat))
        t2(keep=mother_id child_bdat
           rename=(mother_id=random_mother));

  diff_dat=round( (original_child_bdat-child_bdat)/356.25, 0.01);
run;
proc sort data=rnd_bdat;by mother_id;run;


*------------------------------------------------------------------------------------;
* Now, create a new ANA1 dataset using the permuted date of birth of each child      ;
*------------------------------------------------------------------------------------;

proc sql;
  create table rnd_diag2 as
  select a.*, b.child_bdat
  from diag2(drop=child_bdat) as a
  left join rnd_bdat as b
  on a.mother_id = b.mother_id
  order by mother_id
  ;
quit;

data rnd_dephist
     rnd_dephist1yr(rename=(dephist_dat=dep1yr_dat) label='Depr hist within one yr bef birth')
     rnd_dephistold(rename=(dephist_dat=depold_dat) label='Depr hist before one yr bef birth')
  ;
  attrib dephist_dat length=4 format=yymmdd10. label='Date of 1st depression'
         dephist     length=3 format=yesno.    label='Psychiatric History (Y/N)'
  ;
  keep mother_id dephist_dat dephist;

  set rnd_diag2; by mother_id psych_dat;

  dephist=1;

  if first.mother_id and psych_dat < child_bdat then do;
    dephist_dat=psych_dat;
    output rnd_dephist;

    if psych_dat>intnx('year', child_bdat, -1, 'same') then output rnd_dephist1yr;
    else if psych_dat<intnx('year', child_bdat, -1, 'same')+1 then output rnd_dephistold;
  end;
  else delete;
run;


*-- Creating postpartum depression variable;
data postpart1;
  keep mother_id postp_dat postpartum;
  attrib postp_dat    length=4 format=yymmdd10. label='Date of postpartum event'
         postpartum   length=3 format=yesno.    label='Post Partum (Y/N)'
  ;
  set rnd_diag2(in=diag1 keep=mother_id psych_dat child_bdat);

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
data rnd_postpart;
  set postpart1;by mother_id postp_dat;
  if first.mother_id;
run;


*-- Create a dataset that is inclusive of psychosis;
data rnd_psychotic;
  attrib psycho      length=3 format=yesno.    label='Psychosis History (Y/N)'
         psycho_dat  length=4 format=yymmdd10. label='Date of psychosis';

  keep mother_id psycho psycho_dat;
  set rnd_diag2;

  if substr(left(diagnos),1,4) in ('F322') and psych_dat<child_bdat then do;
    psycho=1;
    psycho_dat=psych_dat;
  end;
  else delete;
run;

*-- ... from this create psychotic history ;
proc sort data=rnd_psychotic;by mother_id psycho_dat;run;
proc sort data=rnd_psychotic nodupkey;by mother_id;run;


*-- Analysis dataset;
data slask rnd_ana1(label='Analysis dataset using random dates for child birth dates');
  drop _a_ _b_ _c_;
  attrib cens  length=3 label='Censored (Y/N)'
         event length=3 label='Postpartum event (Y/N)'
         exit  length=4 label='Age at cohort exit'
         mother_id label='Mother ID'

         mbyear     length=4 label='Mother Birth Year'
         cbyear     length=4 label='Child Birth Year'
         mbyear_cat length=3 label='Mother Birth Year'        format=mbcfmt.
         cbyear_cat length=3 label='Child Birth Year'         format=cyr.
         mage_cat   length=3 label='Child Birth Year'         format=mage.
         mage       length=4 label='Mother age'
         exit_mo             label='Month of cohort exit'
         mage_catb  length=3 label='Maternal age'             format=mageb.
         plen_cat   length=3 label='Pregnancy length (weeks)' format=plencat.
  ;

  retain _a_ _b_ _c_ 0;
  merge ana1(in=ana1 drop=dephist_dat postp_dat psycho psycho_dat cbyear cbyear_cat
             rename=(dephist=orig_dephist postpartum=orig_postpartum child_bdat=orig_child_bdat))

        rnd_bdat(in=rnd_bdat keep=mother_id child_bdat)
        rnd_dephist(in=in_dephist)
        rnd_dephist1yr(in=in_dephist)
        rnd_postpart(in=postpart)
        rnd_psychotic(in=psychotic)
  ;
  by mother_id;

  if ana1 then do;
    if postp_dat>.z then do;
      exit   =(postp_dat - child_bdat)/365.25;
      exit_mo=exit*12;
      cens=0; event=1;

      *-- In poisson regression step PPD the same day as birth were removed;
      if exit_mo=0 then exit_mo=1/30;
    end;
    else do;
      exit=1; cens=1; event=0; exit_mo=12;
    end;


    if not rnd_bdat then abort;
    *-- Depression history;
    if not in_dephist then dephist=0;

    *-- Postpartum ;
    if not postpart then postpartum=0;

    *-- Psychotic history;
    if not psychotic then psycho=0;

    cbyear=year(child_bdat);

    if cbyear GE 1997 and cbyear LE 2002 then cbyear_cat=1;
    else if cbyear GE 2003 and cbyear LE 2008 then cbyear_cat=2;
    else abort;

  end;
  else delete;

run;

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete postpart1 rnd_postpart1 rnd_psychotic rnd_diag2 t1 t2;
quit;

*-- End of File --------------------------------------------------------------;
