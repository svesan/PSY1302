data t;set diag2;pyr=year(psych_dat);run;

proc copy in=sasperm out=work;run;
proc freq data=t;table pyr;ruN;
proc freq data=ana1;table mage;ruN;

/*
* Purpose....: Fit a poissson model estimating rate of depression over live. All women born 1970 and onwards in Sweden
*/

*-- Women born 1960 and onwards enter the cohort at age 20. Then follow up to 31Dec2008 and 31dec2009 for depression;


*------------------------------------------------------------------------------------;
* Create time-splitted dataset starting follow-up one year before birth of the child ;
* psych_dat as first_dep_one_year_bef = postp_dat if happens after birth of child    ;
*------------------------------------------------------------------------------------;
proc sql;
  create table s1 as
  select a.mother_id, a.mother_bdat, a.child_bdat,
         a.mage, a.mbyear, a.cbyear, a.mbyear_cat, a.mage_cat, a.cbyear_cat,
         a.postpartum, a.postp_dat
  from ana1 as a
  where a.mage GE 20 and a.mbyear GE 1960
  ;
quit;

proc sort data=s1 nodupkey;by mother_id;run;

data s2;
  attrib mbyear     length=4 label='Mother Birth Year'
         cbyear     length=4 label='Child Birth Year'
         exit       length=8 label='Exit month, from -1 yr'
         event      length=3 label='Depr within one yr (Y/N)'
  ;
  set s1(keep=mother_id mage mbyear cbyear postpartum postp_dat mother_bdat child_bdat);

  *-- Calculate exact age at birth;
  mage_exact=round((child_bdat-mother_bdat)/365.25, 0.001);

  *-- Cohort entry at age 20;
  entry = 20;

  *-- Exit at age 31-Dec-2009 or 1 yr after birth;
  exit  = mage_exact + 1;

  *-- Since not analysing incident cases EVENT=0 for all;
  event=0;

  *-- Data exclusions ;
  if mage<15 then delete;
  if mage>49 then delete;
run;


*-- Create poisson dataset. One year interval for each age starting at age 20 ;
%mebpoisint(data=s2, out=s3, entry=entry, exit=exit, event=event,
            split_start=20, split_end=50, split_step=1, droplimits=Y, logrisk=N,
            id=mother_id);

/****
*-- First join in time varying variable for pre and postnatal period (before or after birth);
data s4;
  keep mother_id mage_exact child_bdat;
  set s1(keep=mother_id mother_bdat child_bdat mage);
  by mother_id;

  mage_exact=round((child_bdat-mother_bdat)/365.25, 0.001);
run;
***/
proc sort data=s3;by mother_id interval;run;
data s5;
  keep mother_id interval postnatal child_bdat _risk mage_exact;
  merge s2(in=s5)
        s3(in=s4 rename=(_risk=risk1));
  by mother_id;

  if s4 and s5 then do;
    a=input(scan(vvalue(interval),1), 8.);
    b=input(scan(vvalue(interval),2), 8.);

    if mage_exact > b then do;                      *-- birth later than current interval;
      event=0; _risk=risk1; postnatal=0;    output;
    end;
    else if mage_exact GE a AND mage_exact LT b then do; *-- birth in current interval;
      event=0; _risk=mage_exact-a; postnatal=0; output;
      event=0; _risk=b-mage_exact; postnatal=1; output;
    end;
    else if mage_exact < a then do;                      *-- birth + 1 yr follow-up later than current interval;
      event=0; _risk=risk1; postnatal=1;    output;
    end;
  end;
  else delete;
* if mother_id=814 then put mother_id= interval= mage_exact= _risk= postnatal=;
run;



*-- Now calculate maternal age for each psychiatric diagnoses before child birth;
data p1;
  keep postpartum postp_dat mother_id dep_age dep_age_int ppd_age ppd_age_int psych_dat;
  attrib dep_age     length=6 label='Age at depression diagnosis'
         dep_age_int length=4 label='Age at depression diagnosis'
         ppd_age     length=6 label='Age at PPD'
         ppd_age_int length=4 label='Age at PPD'
  ;
  merge s1(in=s1 keep=mother_id mother_bdat child_bdat postp_dat postpartum)
        diag2(in=diag2 keep=mother_id psych_dat);
  by mother_id;

  if not diag2 or not s1 then delete;
  else if psych_dat > child_bdat + 365 then delete;
  else do;
*    dep_yr  = round((psych_dat - child_bdat)/365.25,0.001);
    dep_age     = round((psych_dat - mother_bdat)/365.25, 0.001);
    dep_age_int = round((psych_dat - mother_bdat)/365.25, 1);

    *-- Age at PPD;
    if postpartum then do;
      ppd_age     = round((postp_dat - mother_bdat)/365.25, 0.001);
      ppd_age_int = round((postp_dat - mother_bdat)/365.25, 1);
    end;
    else do;
      ppd_age=.N; ppd_age_int=.N;
    end;
  end;

  if psych_dat GE child_bdat then delete;
run;
proc sort data=p1 nodupkey;by mother_id psych_dat;run;
proc sort data=p1 nodupkey;by mother_id;run;

proc sort data=s3;by mother_id interval;run;

*-- Join in age of depression to create time varying covariates for depression before birth;
data s6;
  keep mother_id child_bdat mage_exact dep_age interval _risk risk1 event dephist postnatal;

  length a b 3;
  merge s5(in=s5 keep=mother_id interval _risk postnatal mage_exact child_bdat rename=(_risk=risk1))
        p1(in=p1 keep=mother_id dep_age);
  by mother_id;

  if s5 and not p1 then do;
    *-- No psychiatric diagnosis;
    event=0; _risk=risk1; dephist=0;     output;
  end;
  else if s5 and p1 then do;
    a=input(scan(vvalue(interval),1), 8.);
    b=input(scan(vvalue(interval),2), 8.);

    if dep_age >= b then do;                    *-- psych later than current interval;
      if risk1 ne 1 then abort;
      event=0; _risk=1; dephist=0;    output;
    end;
    else if dep_age GE a AND dep_age LT b then do; *-- psych in current interval;
      if risk1 = 1 then do;
        event=0; _risk=dep_age-a; dephist=0; output;
        event=0; _risk=b-dep_age; dephist=1; output;
      end;
      else if risk1 < 1 then do;            *-- birth is in this interval;
        if dep_age > mage_exact then abort; *-- if depression after birth (should not be as data is organized) ;

        if postnatal=0 then do;
          event=0; _risk=dep_age-a;               dephist=0; output;
          event=0; _risk=a+risk1-dep_age;         dephist=1; output;
        end;
        else if postnatal=1 then do;
          event=0; _risk=risk1;                   dephist=1; output;
        end;
      end;
    end;
    else if dep_age < a then do;
      _risk=risk1; dephist=1; output;


    end;
    else abort;
  end;
run;


proc sql;
  create table check1 as
  select mother_id, interval, child_bdat, mage_exact, dep_age, sum(_risk) as totrisk
  from s6
  group by mother_id, child_bdat, mage_exact, dep_age, interval
  order by mother_id, child_bdat, mage_exact, dep_age, interval
  ;









proc genmod data=s6;
  class interval dephist postnatal;
  model event = interval dephist postnatal
  / family=poisson link=log;
run;


**************************************;
**************************************;
**************************************;
**************************************;
**************************************;
**************************************;
**************************************;
**************************************;


*-- Create additional format, -12 instead of -12--11 and 0 instead of 0-1;
proc format cntlout=slask1;select __ivl__;run;
data slask2;
*  drop label0;
  length label $12;
  set slask1(keep=start end type label rename=(label=label0));
  fmtname='__ivl2__';
  i=input(compress(start),8.);

  label=put(i-13,4.);
run;
ods listing close;
proc format cntlin=slask2 noprint;select __ivl2__;run;
ods listing;


*-- Join in covariates;
*-- Variable count_births needed to count children born;
proc sql;
  create table t4 as
  select a.mother_id, a.interval format=__ivl2__., a._risk, a._no_of_events, a.event,
         b.mbyear, b.cbyear, b.mage, b.mage_cat, b.mbyear_cat, b.cbyear_cat,
         case c.dephist when 1 then 1 else 0 end as dephist length=3 label='Depr hist before 1 year bef birth' format=yesno.,
         case a.interval  when 1 then 1 else 0 end as count_births length=3 label='Birth (Y/N)'
  from t3 as a
  left join t1 as b
    on a.mother_id=b.mother_id
  left join dephistold as c
    on a.mother_id=c.mother_id
  order by a.mother_id, a.interval
  ;
quit;

*-----------------------------------------------------;
* Collaps the data                                    ;
*-----------------------------------------------------;
proc summary data=t4 nway;
  var event _risk count_births;
  class cbyear_cat cbyear dephist mage_cat dephist interval;
  output out=t5(drop=_type_ _freq_) sum=;
run;


data t6;
  attrib interval label='Month since birth' big_int length=3 label='Year bef or after birth';
  set t5 end=eof;
  rate = 10000*event/(_risk);
  logoffset=log(_risk);

  *-- The year before or following birth;
  if interval LT 13 then big_int=1;
  else if interval GE 13 then big_int=2;
run;




data v1;
  set ana1(keep=mother_id psycho_dat postp_dat where=(postp_dat>.z));
run;
