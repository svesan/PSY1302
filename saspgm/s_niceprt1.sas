*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_niceprt1.sas                                                ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Condensed printout of RR estimates                            ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...: est1-est3 ppdest1-ppdest3                                     ;
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

*-- RR for depression starting -12 month before birth;
title1 'RR of depression';
title2 'Following mothers from 1 year bef birth to 1 year after';
title3 'Adjust for month from birth, calendar time, maternal age and depr. history';
%tit(prog=s_niceprt1);
%prtest(data=est1);

title1 'RR of depression - Restricted to mothers with depr. history at -12 month';
title2 'Following mothers from 1 year bef birth to 1 year after';
title3 'Adjust for month from birth, calendar time, maternal age and depr. history';
%tit(prog=s_niceprt1);
%prtest(data=est2);

title1 'RR of depression - Restricted to mothers with NO depr. history at -12 month';
title2 'Following mothers from 1 year bef birth to 1 year after';
title3 'Adjust for month from birth, calendar time, maternal age and depr. history';
%tit(prog=s_niceprt1);
%prtest(data=est3);



*-- RR for PPD starting at birth;
title1 'RR of PPD';
title2 'Adjust for month from birth, calendar time, maternal age and depr. history,';
title3 'CS, Deformations, Prenancy lengths (weeks), Mo. living with father, History of psychosis';
%tit(prog=s_niceprt1);
%prtest(data=ppdest1);

title1 'RR of PPD - Restricted to mothers with depr. history at birth';
title2 'Adjust for month from birth, calendar time, maternal age and depr. history,';
title3 'CS, Deformations, Prenancy lengths (weeks), Mo. living with father, History of psychosis';
%tit(prog=s_niceprt1);
%prtest(data=ppdest2);

title1 'RR of PPD - Restricted to mothers with NO depr. history at birth';
title2 'Adjust for month from birth, calendar time, maternal age and depr. history,';
title3 'CS, Deformations, Prenancy lengths (weeks), Mo. living with father, History of psychosis';
%tit(prog=s_niceprt1);
%prtest(data=ppdest3);

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
delete _null_;
quit;

*-- End of File --------------------------------------------------------------;
