/* THIS ALLOWS ME TO ACCESS THE KI SERVER*/

libname crime2 oracle dbprompt=no user=micsil pw="cd92An_yt7"  path=UNIVERSE schema=mgrcrime2 connection=GLOBALREAD readbuff=4000 updatebuff=40;

*libname loc server=skjold slibref=crime2;
endrsubmit;
libname sw  server=skjold slibref=work;
rsubmit;


proc format;
value yesno 1='Yes' 0='No';
run;


*-- Select all children born between 1997 and 2008;
data br0;
drop x_bfoddat;
attrib child_bdat length=4 format=yymmdd10. label='Child birth date'
;
set crime2.v_mfr_base(keep=MALDER LOPNRMOR X_MFODDAT X_BFODDAT PARITET_F SECMARK GRVBS
                      rename=(lopnrmor=mother_id));
child_bdat=input(x_bfoddat, yymmdd8.);

*if child_bdat >= '01JAN1997'd and child_bdat < '01JAN2009'd;
if child_bdat >= '01JAN1997'd and child_bdat < '01JAN1999'd;
%put ERROR: Must remove this line!!!!;

if mother_id <= .z then delete;

run;


*-- WARNING: From now on only considering the 1st child born in the chosen birth interval ;
proc sort data=br0;by mother_id child_bdat;
data br1;
 set br0;by mother_id child_bdat;
 if first.mother_id;
run;


*-- Select the depression diagnoses ;
data diag1;
 attrib psych_dat length=4 format=date9. label='Date depression';
 keep LOPNR IN_NR DIAG_NR ICD_NR DIAGNOS SOURCE psych_dat;
 set crime2.V_Patient_diag;
 rename LOPNR = mother_id;
 if substr(left(diagnos),1,3) in ('F32','F33','F34','F38','F53','296','301','F309','311','642','648') then do;
   psych_dat=input(x_date, yymmdd8.);
 end;
 else delete;

run;

*-- Sort datasets since datasets later will require this;
proc sort data=br1;by mother_id;run;
proc sort data=diag1;by mother_id psych_dat;run;


*-- Creating depression psych history variable;
data dephist;
  attrib first_psych_dat length=4 format=yymmdd10. label='Date of 1st depression'
         phist           length=3 format=yesno.    label='Psychiatric History (Y/N)'
  ;
  keep mother_id first_psych_dat;
  set diag1; by mother_id psych_dat;

  if first.mother_id then first_psych_dat=psych_dat;
  else delete;

  phist=1;
run;


*-- Creating postpartum depression variable;
data postpart1;
 attrib postp_dat    length=4 format=yymmdd10. label='Date of postpartum event'
        postpartum   length=3 format=yesno.    label='Post Partum (Y/N)'
 ;
 merge	br1 (in=br1)
		diag1(in=diag1)
        ;
 by mother_id;
 if br1 AND diag1 then do;
   if psych_dat - child_bdat > 365 then delete;
   else if psych_dat < child_bdat then delete;

   else do;
     postp_dat=psych_dat;
     postpartum=1;
	 output;
   end;
 end;
 else if diag1 and not br1 then delete;
run;

*-- Currently, there may be several rows of postpartum for a single woman. Keep the 1st one only;
proc sort data=postpart1;by mother_id postpart_dat;run;
data postpart;
  set postpart1;by mother_id postpart_dat;
  if first.mother_id;
run;


 *-- Create analysis dataset by combining the variables defined above;
 data br2;
  attrib phist length=3 label='Depr hist (Y/N)' format=yesno.;
  merge	br1 (in=br1)
		dephist(in=indephist)
		postpart 
        ;
  by mother_id;

  if br1 and indephist and first_psych_dat>.z and first_psych_dat < child_bdat then do;
    phist=1;
  end;
  else do;
    phist=0; first_psych_dat=.N;
  end;
run;


*-- Create a dataset that is inclusive of psychosis;

data psychotic;
attrib psycho          length=3 format=yesno.    label='Psychosis History (Y/N)'
       psycho_dat 	   length=4 format=yymmdd10. label='Date of psychosis';

keep mother_id psycho psycho_dat;
set diag1;

if substr(left(diagnos),1,4) in ('F322');
psycho=1;
psycho_dat=psych_dat;
run;





*-- Analysis dataset;
data ana1;
  attrib cens length=3 event length=3 exit length=4;
  set br2;
  if psych_dat>.z then do;
    exit=(psych_dat-child_bdat)/365.25;
    cens=0; event=1;
  end;
  else do;
    exit=1; cens=1; event=0;
  end;
run;

proc phreg data=ana1;
  class dephist;
  model exit*cens(1) = dephist;
run;

proc print data=br1 (obs=10);
run;
proc print data=br2 (obs=10);
run;
proc print data=br3 (obs=10);
run;
proc print data=diag1 (obs=10);
run;
proc print data=postpart (obs=10);
run;
proc print data=ana1 (obs=10);
run;

proc means data=psych_diagnoses;
run;


proc sql;
 create table new as
 select count(distinct(mother_id)) as Mothers
 from br1;

 quit;

 proc print;
 run;




*--- End of File -----------------------------------------------;

data postpartum_hx;
set br2;
if psych_dat-child_bdat<365 and dephist = 1 then diag_inrange=1;
else if psych_dat-child_bdat<365 and dephist = 0 then diag_inrange=2;
else if diag_inrange=0;


run;


length criteria $55;
if dephist=. then criteria="No Depression Dx for Mother";
else if dephist^=. and diag_inrange=0 then criteria="No Depression Dx for Mother 1 Year Post Birth";
else if dephist^=. and diag_inrange=1 then criteria="Depression Dx for Mother 1 Year Post Birth";
run;

proc print data = npostpartum (obs=10);
run;
/* THIS COMMANDS MERGES PSYCHIATRIC HISTORY FOR DEPRESSION WITH MATERAL DEPRESSION IN THE FIRST YEAR */

data dep_diag_prebirth;
set birth_diag;
if dephist=. then criteria="No Depression Hx for mother";
else if dephist < birth_diag then criteria="Positive Depression Hx";
run;
 



/* THESE FINAL SRIPTS CREATE A MERGED DATASET WITH ONE ROW OF DATA PER MOTHER WITH MULTIPLE DIAGNOSIS RECORDS STORED
AS DIFFERENT VARIABLES */

proc sort data=birth_registry;
 by LOPNRMOR;
 run;
proc sort data=diagnoses1;
 by LOPNRMOR X_DATE;
 run;

proc sort data=diagnoses1; by _LOPNRMOR;run;
data wide_diagnoses1 (keep= LOPNRMOR DIAGNOS1 DIAGNOS2 DIAGNOS3 X_DATE1 X_DATE2 X_DATE3 SOURCE1 SOURCE2 SOURCE3);
array DIAGNOSS $DIAGNOS1-DIAGNOS3;
array DATES X_DATE1-X_DATE3;
array SOURCES SOURCE1-SOURCE3;
do over DIAGNOSS;
   set diagnoses1;
	by LOPNRMOR;
      DIAGNOSS=diagnos;
	  DATES=X_DATE;
	  SOURCES=SOURCE;
	if last.LOPNRMOR then return;
end;
run;

proc sort data=birth_registry;
 by LOPNRMOR;
 run;
proc sort data=wide_diagnoses1;
 by LOPNRMOR;
 run;

 data birth_diag_wide;
 merge	birth_registry (in=a)
		wide_diagnoses1;
 by LOPNRMOR;
 if a;
 run;

/* WE WILL NEED TO CHANGE THE NUMBERS DEPENDING ON THE NUMBER OF DIAGNOSES WE'RE EXPLORING */

data birth_diag_wide_postyear;
set br1;
array XDATE {3} X_DATE1-X_DATE3;
array SOURCES {3} SOURCE1-SOURCE3;
array DIAGNOSIS {3} DIAGNOS1-DIAGNOS3;
do i=1 to 3 until (XDATE{i}^=. and XDATE{i}> X_BFODDAT and XDATE{i}< X_1YRDAT);
	date_fin=XDATE{i};
	source_fin=SOURCES{i};
	diagnosis_fin=DIAGNOSIS{i};
end;
length criteria $55;
if i=4 and X_DATE1=. then criteria="No Depression Dx for Mother";
else if i=4 and X_DATE1^=. then criteria="No Depression Dx for Mother 1 Year Post Birth";
else if i<4 then criteria="Depression Dx for Mother 1 Year Post Birth";
run;

proc freq data=birth_diag_wide_postyear;
tables criteria;
run; 



quit;



*---assess all psychiatric dx;
data psych_history;
attrib psych_hx          length=3 format=yesno.    label='Psychiatric History (Y/N)'
       psych_hx_dat 	 length=4 format=yymmdd10. label='Date of ANY psych history';
keep mother_id psych_dat psych_hx psych_hx_dat icd_nr;
set diag1; 
if (substr(left(diagnos),1,1) = 'F' and icd_nr=10) OR
(substr(left(diagnos),1,2) = '29' or '30' or '31' and icd_nr=9) OR
(substr(left(diagnos),1,2) = '29' or '30' or '31' and icd_nr=8) then do;
psych_hx=1;
psych_hx_dat=psych_dat;
run;

*---assess numner of independent psychiatric diagnoses;
proc sort data=psych_history;by mother_id psych_hx_dat;run;
data psych_diagnoses; 
retain psych_order 0;
set psych_history; by mother_id psych_hx_dat;

if first.mother_id then psych_order=1;
else psych_order=psych_order+1;
run;



('F32','F33','F34','F38','F53','296','301','F309','311','642','648') then do;
 



data x;
input diagnosis $ 1-10;

if substr(diagnosis,1,1)='F' then put _n_= diagnosis=;
cards;
F324
23988
;
run;
