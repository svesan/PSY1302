*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_s1_niceprt3.sas                                                ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Condensed printout of RR estimates                            ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...: est1-est3 ppdest1a-ppdest3a  basic                            ;
* Data created:                                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M0P061913                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;

*-- SAS macros ---------------------------------------------------------------;
%macro prtest(data=);
  data temp;
    attrib contrast length=$20 label='Contrast';
    set &data;
    ci=put(expestimate,5.2)||' ('||put(explower,5.2)||'-'||put(expupper,5.2)||')';
    if substr(label,1,5)='M.Age' then contrast='Maternal Age';
    else if scan(reverse(label),1)='feb' then contrast='Monthly';
    else if scan(reverse(label),1)='retfa' then contrast='Monthly';
    else if index(label,'before')>0 then contrast='Year bef and after';
    else contrast='BL characteristics';
  run;

  proc print data=temp label noobs uniform;
    var label probt ci;
    by contrast notsorted;id contrast;
  run;
%mend;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;


title1 'Cases, Women, Person Years and Rate PPD overall';
%tit(prog=s_s1_niceprt3);

%scarep(data=s1_basic,id=sub lbl, var=category events subjects pyear rate pct);

*-- RR for PPD starting at birth;
title1 'Sensitivity analysis. RR of PPD. Birth 2005-08 and Depr. Hist within 2 yrs';
title2 'Adjust for month from birth, calendar time, maternal age and depr. history,';
title3 'CS, Deformations, Prenancy lengths (weeks), Mo. living with father, History of psychosis';
%tit(prog=s_s1_niceprt3);
%prtest(data=s1_ppdest1a);

title1 'Sensitivity analysis. RR of PPD - Restricted to mothers with depr. history at birth. Birth 2005-08 and Depr. Hist within 2 yrs';
title2 'Adjust for month from birth, calendar time, maternal age and depr. history,';
title3 'CS, Deformations, Prenancy lengths (weeks), Mo. living with father, History of psychosis';
%tit(prog=s_s1_niceprt3);
%prtest(data=s1_ppdest2a);

title1 'Sensitivity analysis. RR of PPD - Restricted to mothers with NO depr. history at birth. Birth 2005-08 and Depr. Hist within 2
 yrs';
title2 'Adjust for month from birth, calendar time, maternal age and depr. history,';
title3 'CS, Deformations, Prenancy lengths (weeks), Mo. living with father, History of psychosis';
%tit(prog=s_s1_niceprt3);
%prtest(data=s1_ppdest3a);


*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete _null_;
quit;

*-- End of File --------------------------------------------------------------;
