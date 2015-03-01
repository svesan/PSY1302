

data b;
set a;
sex=kon/1;
*sex as numeric variable;
*grdbs is gestational age in days;
*bvikt is birth weight;


**************************;
IF sex=1 THEN DO;
	M_Weight=(-(1.907345*10**(-6))*grdbs**4
	+(1.140644*10**(-3))*grdbs**3
	-1.336265*10**(-1)*grdbs**2
	+1.976961*10**(0)*grdbs+2.410053*10**(2));

	M_StandardWeight=(bvikt-M_Weight)/(M_Weight*0.12);
END;

IF sex=2 THEN DO;
	M_Weight=(-(2.761948*10**(-6))*grdbs**4
	+(1.744841*10**(-3))*grdbs**3
	-2.893626*10**(-1)*grdbs**2
	+1.891197*10**(1)*grdbs-4.135122*10**(2));

	M_StandardWeight=(bvikt-M_Weight)/(M_Weight*0.12);
END;
M_StandardWeight=round(M_StandardWeight,.01);
if M_standardWeight lt -5 then M_StandardWeight=.;
if M_standardWeight gt 5 then M_StandardWeight=.;
*M_STANDARDWEIGHT I PERCENTILER: wperc=1 <3,wperc=2 3-<10,wperc=3 10-90, wperc=4 >90-97,wperc=5 >97;
**BASED ON LIVE SINGLE BIRTHS 1973-1990;
IF (-5 LE M_STANDARDWEIGHT LE -2.17) THEN WPERC=1;
ELSE IF (-2.16 LE M_STANDARDWEIGHT LE -1.5) THEN WPERC=2;
ELSE IF (-1.49 LE M_STANDARDWEIGHT LE 1.22) THEN WPERC=3;
ELSE IF (1.23 LE M_STANDARDWEIGHT LE 1.99) THEN WPERC=4;
ELSE IF M_STANDARDWEIGHT GE 2.0 THEN WPERC=5;
proc freq;
tables wperc;
run;
