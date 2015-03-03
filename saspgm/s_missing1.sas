title1 'Patterns of missing values';
%tit(prog=s_missing1);
%misspat(data=sasperm.ana1, print=Y,
         var=sfinkt wperc forltyp prodeliv bp mage_cat cbyear_cat cs preg_len deform withfather);
