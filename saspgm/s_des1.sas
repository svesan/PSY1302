*-- Cohort description;
data t1;
  length mb_yr cb_yr 4;
  set sasperm.ana1;
  mb_yr=year(mother_bdat);
  cb_yr=year(child_bdat);
run;

proc sql;
  select count(distinct mother_id) as no_of_mothers
  from t1;
quit;

proc means data=t1 nway maxdec=0 min max median sum n nmiss;
  var mb_yr cb_yr event cens mage postpartum preg_len;
run;

proc freq data=t1;
  table cs preg_len ;
run;
options notes source;

%misspat(data=t1, var=mage preg_len cs mage mb_yr cb_yr, print=Y, event=event);
