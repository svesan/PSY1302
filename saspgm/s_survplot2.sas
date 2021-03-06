*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_survplot2.sas                                               ;
* Date........: 2014-01-20                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Plot PPD survival curves                                      ;
* Note........: 150107 added figure with log probability curves               ;
*-----------------------------------------------------------------------------;
* Data used...: ana1                                                          ;
* Data created:                                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M0P061913                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;
title;footnote;

proc sql;
  create table s1 as
  select mother_id, 0 as entry, exit_mo, event, cs, preg_len, deform, withfather, dephist,
         mage, mbyear_cat, cbyear_cat, mage_cat, psycho
  from ana1
  where mage GE 15 and mage LE 49
  ;
quit;


ods listing close;

*-- Overall ;
proc lifetest data=s1 outsurv=surv1;
  time exit_mo*event(0);
run;

*-- For mothers with and without psychiatric history;
proc lifetest data=s1 outsurv=surv2;
  time exit_mo*event(0);
  strata dephist;
run;

data surv3;
  attrib strata length=$40 label='Strata' exit_day label='Days since birth';
  set surv1(in=surv1 keep=survival exit_mo sdf_lcl sdf_ucl)
      surv2(in=surv2 keep=survival exit_mo sdf_lcl sdf_ucl dephist);

  if exit_mo>.z and survival>.z then do;
    ppd=1-survival;
    sdf_lcl=1-sdf_lcl;
    sdf_ucl=1-sdf_ucl;

    *-- Approximating days since delivery for descriptive purposes;
    exit_day=exit_mo*30;

    *-- 2015-01-07 added log survival;
    log_ppd= log(ppd);
    log_lcl= log(sdf_lcl);
    log_ucl= log(sdf_ucl);

  end;
  else delete;

  if surv1 then strata='All mothers';
  else if dephist=0 then strata='No earlier depression';
  else if dephist=1 then strata='Earlier Depressed';
run;

*-- Define output directory for the figures ;
data _null_;
  call symput('slask',trim(pathname('result')));
run;


title;
ods listing  gpath="&slask";
ods graphics / reset=index imagefmt=png imagename="survival";
*title1 'Depression rate by depression history. 1st year after birth';
proc sgpanel data=surv3;
  panelby strata / rows=1 columns=3 novarname;
  series x=exit_mo y=ppd;
  band   x=exit_mo lower=sdf_lcl upper=sdf_ucl /transparency=0.5  legendlabel='95% CI';
  colaxis values=(0 to 12 by 1);
run;

*title1 'Depression rate by depression history. 1st month after birth';
proc sgpanel data=surv3;
  where exit_mo le 1;
  panelby strata / rows=1 columns=3 novarname;
  series x=exit_day y=ppd;
  band   x=exit_day lower=sdf_lcl upper=sdf_ucl /transparency=0.5  legendlabel='95% CI';
  colaxis values=(0 to 30 by 5);
run;

ods graphics off;

*---------------------------------------------------------;
*   2015-01-07 Added overlaid plots of log survival       ;
*---------------------------------------------------------;
proc format;
  value logfmt -2='0.135335'  -4='0.018316'  -6='0.002479'
               -8='0.000335' -10='0.000045' -12='0.000006';
run;

title;
ods listing  gpath="&slask";
ods graphics / reset=index imagefmt=png imagename="logsurvA1";
*title1 'Depression rate by depression history. 1st year after birth';
proc sgplot data=surv3;
  label exit_mo='Month since birth' log_ucl='log(Survival)';
  where dephist > .z;
  band   x=exit_mo lower=log_lcl upper=log_ucl /transparency=0.5  legendlabel='95% CI' group=strata;
run;


title;
ods listing  gpath="&slask";
ods graphics / reset=index imagefmt=png imagename="logsurvA2";
*title1 'Depression rate by depression history. 1st year after birth';
proc sgplot data=surv3;
  label log_ucl='log(Survival)';
  where dephist > .z and exit_mo le 1;
  band   x=exit_day lower=log_lcl upper=log_ucl /transparency=0.5  legendlabel='95% CI'
         group=strata;
run;


/******
CURVELABELLOC=inside
*-- Repeat two figs above but format the y-axis differently as probabilities;
ods graphics / reset=index imagefmt=png imagename="logsurvB1";
*title1 'Depression rate by depression history. 1st year after birth';
proc sgplot data=surv3;
  label exit_mo='Month since birth';
  where dephist > .z;
  band   x=exit_mo lower=log_lcl upper=log_ucl /transparency=0.5  legendlabel='95% CI' group=strata;
  format log_lcl logfmt.;
run;


title;
ods listing  gpath="&slask";
ods graphics / reset=index imagefmt=png imagename="logsurvB2";
*title1 'Depression rate by depression history. 1st year after birth';
proc sgplot data=surv3;
  where dephist > .z and exit_mo le 1;
  band   x=exit_day lower=log_lcl upper=log_ucl /transparency=0.5  legendlabel='95% CI' group=strata;
  format log_lcl logfmt.;
run;

****/


*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete s1 surv1-surv3;
quit;

*-- End of File --------------------------------------------------------------;
