proc sql;
  connect to oracle (user=svesan pw="{SAS002}1EA5152055A835B6561F91FA343842795497A910" path=UNIVERSE);
  execute (alter session set current_schema=mgrcrime2 ) by oracle;

  create table dcheck1 as
  select lopnrmor as mother_id, mdiag

  from connection to oracle (
    select LOPNRMOR, MDIAG_NR, ICD_NR, MDIAG, X_BFODDAT

    from v_mfr_mother_mdiag
    where (substr(trim(mdiag),1,4) in ('O702','O703')) or
          (substr(trim(mdiag),1,3) in ('O63') ) or
          (substr(trim(mdiag),1,4) in ('O240','O241','O242','O243','O244')) or
          (substr(trim(mdiag),1,3) in ('O10','O11')) or
          (substr(trim(mdiag),1,3) in ('O14','O15'))
  );

proc sql;
  connect to oracle (user=svesan pw="{SAS002}1EA5152055A835B6561F91FA343842795497A910" path=UNIVERSE);
  execute (alter session set current_schema=mgrcrime2 ) by oracle;

  create table dcheck2 as
  select lopnrmor as mother_id, gdiag as mdiag

  from connection to oracle (
    select LOPNRMOR, GDIAG_NR, ICD_NR, GDIAG, X_BFODDAT

    from v_mfr_mother_gdiag
    where (substr(trim(gdiag),1,4) in ('O702','O703')) or
          (substr(trim(gdiag),1,3) in ('O63') ) or
          (substr(trim(gdiag),1,4) in ('O240','O241','O242','O243','O244')) or
          (substr(trim(gdiag),1,3) in ('O10','O11')) or
          (substr(trim(gdiag),1,3) in ('O14','O15'))
  );

proc sql;
  create table wom as select distinct mother_id from ana1;

  create table dcheck3 as
  select distinct wom.mother_id, mdiag
  from dcheck1
  join wom
  on dcheck1.mother_id = wom.mother_id;

  create table dcheck4 as
  select mdiag, count(*) as n
  from dcheck3
  group by mdiag;

  create table dcheck5 as select count(distinct mother_id) as n_woman from wom;
proc sql;
  create table dcheck6 as
  select a.mdiag, a.n, b.n_woman, 100*a.n/b.n_woman as percent
  from dcheck4 as a
  cross join dcheck5 as b
  ;

proc print data=dcheck6;
  var mdiag n percent n_woman;
  format percent 8.2;
run;


proc freq data=old;
table mdiag;
run;

proc freq data=scdiag1;
table mdiag;
run;

libname sw  server=skjold slibref=work;

proc freq data=br1;
table forltyp kon_barn wperc;
run;
