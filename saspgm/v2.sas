%inc saspgm(s_dmpaul);

*-- External programs --------------------------------------------------------;
%inc saspgm(mebpoisint5) / source;  *-- Macro for splitting time for poisson regression;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;

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
         b.cs, b.preg_len, b.deform, b.withfather, b.psycho, b.dephist, b.orig_dephist
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
title2 'Note: Adjusting for interval cbyear_cat mage_catb dephist';
%tit(prog=s_rnd_poana1);
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb dephist;
  model event = dephist mage_catb cbyear_cat interval
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


title1 'Risk of PPD using true date of delivery to derive depr. history. Using a random date of delivery instead of the womans true';
title2 'Note: Depr. history and PPD outcome is also derived from the random date of delivery';
title2 'Note: Adjusting for interval cbyear_cat mage_catb dephist';
%tit(prog=s_rnd_poana1);
proc glimmix data=s5 order=internal;
  class interval cbyear_cat mage_catb orig_dephist;
  model event = orig_dephist mage_catb cbyear_cat interval
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
