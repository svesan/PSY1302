*-- Select 1 random mothers child birth date from the mothers born the same year;
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

/*
proc univariate data=t3;
  var diff_dat;
  histogram diff_dat;
run;
*/