*-----------------------------------------------------------------------------;
* Study.......: PSY1302                                                       ;
* Name........: s_dm3.sas                                                     ;
* Date........: 2014-01-16                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Data management creating analysis dataset for postpart depr   ;
* Note........: 140123 updated codes with Michael and Christina               ;
*-----------------------------------------------------------------------------;
* Data used...: crime2 tables v_mfr_base v_patient_diag                       ;
* Data created: ana1                                                          ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.03.01M2P081512                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
*%inc saspgm(mebpoisint5) / nosource; *-- Macro to split time ;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;
rsubmit;

proc format;
  value yesno 1='Yes' 0='No';
  value mage 1='15-19' 2='20-24' 3='25-29' 4='30-34' 5='35-39' 6='40-44' 7='45-49';
  value cyr  1='1997-2002' 2='2003-2008';
  value mbcfmt 1960='1960-69' 1970='1970-79' 1980='1980-89';
run;


*-- Main program -------------------------------------------------------------;
/* THIS ALLOWS ME TO ACCESS THE KI SERVER*/
options stimer;

libname crime2 oracle dbprompt=no user=micsil pw="cd92An_yt7"  path=UNIVERSE schema=mgrcrime2 connection=GLOBALREAD readbuff=4000 updatebuff=40;

*--;
proc sql;
  connect to oracle (user=svesan pw="{SAS002}1EA5152055A835B6561F91FA343842795497A910" path=UNIVERSE);
  execute (alter session set current_schema=mgrcrime2 ) by oracle;

  create table scdiag1 as
  select lopnrmor as mother_id,
         input(x_bfoddat, yymmdd8.) as child_bdat length=4 format=yymmdd10. label='Date of birth',
         mdiag_nr, icd_nr length=3 label='ICD',
         mdiag label='Maternal MFR Diagnosis'

  from connection to oracle (
    select LOPNRMOR, MDIAG_NR, ICD_NR, MDIAG, X_BFODDAT

    from v_mfr_mother_mdiag
    where (mdiag in ('O702','O703')) or
          (mdiag in ('O63') ) or
          (mdiag in ('O240','O241','O242','O243','O244')) or
          (mdiag in ('O10','O11')) or
          (mdiag in ('O14','O15'))
    order by lopnrmor x_bfoddat
  );
  disconnect from oracle;

run;quit;

proc sort data=br0;by mother_id child_bdat;
data br1;
  set br0;by mother_id child_bdat;
  if first.mother_id;
run;

*-- Create covariates from mother diagnosis;
proc sort data=scdiag1;by mother_id child_bdat;
data scdiag2;
  attrib sfinkt   length=3 format=yesno. label='Sfinkter Rupture'
         prodeliv length=3 format=yesno. label='Prolonged delivery'
         diab     length=3 format=yesno. label='Diabetes'
         hyperton length=3 format=yesno. label='Hypertonia'
         bp       length=3 format=yesno. label='BP disease'
  ;

  merge br1(in=br1) scdiag1(in=scdiag1);
  by mother_id child_bdat;

  if br1 and scdiag1 then do;
    sfinkt=0; prodeliv=0; diab=0; bp=0;
    if mdiag in ('O702','O703') then sfinkt=1;
    else if mdiag in ('O63') then prodeliv=1;
    else if mdiag in ('O240','O241','O242','O243','O244') then diab=1;
    else if mdiag in ('O10','O11') then hyperton=1;
    else if mdiag in ('O14','O15') then bp=1;
  end;
  else delete;
run;
