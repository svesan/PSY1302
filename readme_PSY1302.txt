File name ...... : readme_PSY1302.txt
Purpose..........: This file describes the storage and file usage for the analysis of the study PSY1302
Study............: PSY1302
Study description: A descriptive study on post-partum depression by Michael Silverman Mount Sinai New York
Study comments...: Describing the time course of post-partum depression in Swedish patient registers from 1997 and
                   onwards when ICD-10 is used. The time deveolpments will be 1 year before birth and 1 year after
                   for different sets of women. Michael Silverman Mount Sinai NY as 1st author, Sven Sandin as
                   biostatistician and involving Christina Hultman, Henrik Larsson, Paul Lichtenstein from KI and
                   Avi Reichenberg from Mount Sinai NY.
Creation date....: 07NOV2013
Author...........: svesan  (through the SAS macro createstudy)
SAS version......: 9.03.01M2P081512
Operating system.: Linux
Study root path..: /home/workspace/projects/AAA/AAA_Research/sasproj/PSY
 

Files and data storage
---------------------                                                                                                                                                                                   
For analysing the study PSY1302 the associated files are stored in a directory tree as described below:                                                                                                 
                                                                                                                                                                                                        
.../PSY                                                                                                                                                                                                 
.../PSY/sasdsn                Project raw SAS data (if any) applicable to the entire cohort, e.g. questionnaire data covering an entire cohort                                                          
.../PSY/tmpdsn                Other project SAS data (if any), e.g. cancer data applicable to several studies                                                                                           
.../PSY/sasfmt                Project SAS formats                                                                                                                                                       
.../PSY/PSY1302               Study directory path                                                                                                                                                      
.../PSY/PSY1302/documents     Study documents, e.g. draft and final manuscripts                                                                                                                         
.../PSY/PSY1302/sasdsn        Study SAS datasets applicable for this study. Text or other raw data formats should be found under                                                                        
                              the subdirectory /other and read into SAS datasets using a SAS program in directory                                                                                       
                              /saspgm                                                                                                                                                                   
.../PSY/PSY1302/sasfmt        Study SAS formats (SAS format catalog)                                                                                                                                    
.../PSY/PSY1302/saspgm        Study SAS programs                                                                                                                                                        
.../PSY/PSY1302/sasout        Study SAS output                                                                                                                                                          
.../PSY/PSY1302/saslog        Study SAS log files                                                                                                                                                       
.../PSY/PSY1302/sastmp        Created SAS datasets for 'permanent' storage                                                                                                                              
.../PSY/PSY1302/temp          Files for temporary storage. To be erased before archiving.                                                                                                               
.../PSY/PSY1302/R-Stata       Files (program and output files) for analysing the data using R or Stata                                                                                                  
.../PSY/PSY1302/R-Stata/data  R data (.RData, .csv etc, etc)                                                                                                                                            
.../PSY/PSY1302/R-Stata/graph R graphs                                                                                                                                                                  
.../PSY/PSY1302/other         Other files                                                                                                                                                               
                                                                                                                                                                                                        
Note: ".../PSY" indicate the study root path above                                                                                                                                                      
                                                                                                                                                                                                        
                                                                                                                                                                                                        
SAS environment                                                                                                                                                                                         
---------------                                                                                                                                                                                         
The SAS programs for this study have been created allocating the study using the SAS macro setstudy. If this macro is not available the following                                                       
should be set when starting SAS (Start SAS and cut-and-paste the code below into the SAS editor and submit)                                                                                             
                                                                                                                                                                                                        
libname  projdata ('...PSY/sasdsn','...PSY/sastmp') access=readonly;                                                                                                                                    
libname  psasfmt   '...PSY/sasfmt'                  access=readonly;                                                                                                                                    
libname  study     '...PSY/PSY1302/sasdsn' access=readonly;                                                                                                                                             
libname  sasfmt    '...PSY/PSY1302/sasfmt' access=readonly;                                                                                                                                             
libname  sasperm   '...PSY/PSY1302/sastmp';                                                                                                                                                             
libname  tmpdsn    '...PSY/PSY1302/temp';                                                                                                                                                               
                                                                                                                                                                                                        
filename saspgm    '...PSY/PSY1302/saspgm';                                                                                                                                                             
filename log       '...PSY/PSY1302/saslog';                                                                                                                                                             
filename result    '...PSY/PSY1302/sasout';                                                                                                                                                             
                                                                                                                                                                                                        
options ls=130 ps=43 nodate nonumber nocenter source source2 stimer                                                                                                                                     
        notes dsnferr serror fmterr details                                                                                                                                                             
        mautosource sasautos=('...PSY/PSY1302/saspgm') nomstored mrecall                                                                                                                                
        fmtsearch=(work sasfmt psasfmt)                                                                                                                                                                 
        nomacrogen nosymbolgen nomtrace nomlogic nomprint                                                                                                                                               
        mergenoby=WARN validvarname=upcase                                                                                                                                                              
;                                                                                                                                                                                                       
                                                                                                                                                                                                        
goptions gwait=0 targetdevice=cgmof97l;                                                                                                                                                                 
                                                                                                                                                                                                        
                                                                                                                                                                                                        
Tips                                                                                                                                                                                                    
----                                                                                                                                                                                                    
In the 'saspgm' directory there should be a file s_alvX.sas where X is a version number. Running this file execute all programs needed for analysing                                                    
the study. In this file you will find a sequence of statements such as                                                                                                                                  
                                                                                                                                                                                                        
     %inc saspgm(xxxxx1);                                                                                                                                                                               
     %inc saspgm(xxxxx2);                                                                                                                                                                               
     %inc saspgm(xxxxx3);                                                                                                                                                                               
                                                                                                                                                                                                        
where saspgm id defined as above. Each such statment will run the program within parenthesis, e.g. xxxxx1.sas, xxxxx2.sas, xxxxx3.sas etc                                                               
                                                                                                                                                                                                        
There may be SAS macros not available/missing. The reason for this is most likely that the macro has an administrative purpose such as assigning date                                                   
and time tags to output. Thus, if SAS complains about a missing macro (not resolved) create a dummy macro. Say the macro hepp is not found then run:                                                    
                                                                                                                                                                                                        
     %macro hepp(data=);                                                                                                                                                                                
       *;                                                                                                                                                                                               
     %mend;                                                                                                                                                                                             
                                                                                                                                                                                                        
The macro parameters may of course vary from macro to macro                                                                                                                                             
                                                                                                                                                                                                        
Note: All filenames should be in lowercase since there may be problems with case sensitivity running the programs in Unix or Linux                                                                      
Note: All filenames should be 'short' and only contain letters a-z, 0-9 and with a 'dot' only before the file extension. Empty space in the filename                                                    
      should be avoided.                                                                                                                                                                                
