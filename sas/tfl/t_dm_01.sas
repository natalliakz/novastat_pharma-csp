/*=============================================================================
  PROGRAM   : t_dm_01.sas
  STUDY     : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
  OUTPUT    : Table 14.1.1 - Summary of Demographic and Baseline Characteristics
  NOTE      : ALL DATA IS SYNTHETIC. For demonstration purposes only.
=============================================================================*/

options validvarname=upcase nodate nonumber ls=200;

libname adam "./data/adam";

ods html
  file="./sas/tfl/output/t_dm_01.html"
  style=HTMLBlue
  gtitle gfootnote;

title1 "Table 14.1.1";
title2 "Summary of Demographic and Baseline Characteristics";
title3 "Intent-to-Treat Population";
title4 "Study NSVT-001 | NovaStat Therapeutics";
title5 "(NOTE: All data is AI-generated and synthetic - for demonstration purposes only)";

footnote1 "N = Number of subjects in treatment group";
footnote2 "DAS28 = Disease Activity Score 28-joint count using CRP";
footnote3 "Source: ADSL - Generated via Altair SLC in Positron";

/* --- Continuous variables by treatment --- */
proc tabulate data=adam.adsl(where=(ittfl='Y')) format=8.1;
  class trt01p / order=formatted;
  var age bmibl das28bl complpct aenum;
  table
    (age bmibl das28bl complpct aenum)
      * (n mean std median min max),
    trt01p all
    / box='Continuous Variables';
  keylabel
    n    = 'N'
    mean = 'Mean'
    std  = 'SD'
    median = 'Median'
    min  = 'Min'
    max  = 'Max';
run;

/* --- Categorical variables: Sex --- */
proc freq data=adam.adsl(where=(ittfl='Y')) noprint;
  table sex * trt01p / out=_sex_ct outpct;
run;

proc tabulate data=adam.adsl(where=(ittfl='Y'));
  class trt01p sex agegr1 race dasgrp complfl / order=formatted;
  table
    (sex agegr1 race dasgrp complfl),
    trt01p * (n pctn<trt01p>)
    / box='Categorical Variables (N and %)';
  keylabel n='N' pctn='%';
run;

/* --- Site distribution --- */
proc tabulate data=adam.adsl(where=(ittfl='Y'));
  class trt01p siteid country / order=formatted;
  table siteid * country,
        trt01p * n
        / box='Subjects by Site and Country';
  keylabel n='N';
run;

title;
footnote;
ods html close;

%put NOTE: Table t_dm_01 written to ./sas/tfl/output/t_dm_01.html;
