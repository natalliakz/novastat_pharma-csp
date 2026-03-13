/*=============================================================================
  PROGRAM   : t_ae_01.sas
  STUDY     : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
  OUTPUT    : Table 14.3.1 - Summary of Treatment-Emergent Adverse Events
  NOTE      : ALL DATA IS SYNTHETIC. For demonstration purposes only.
=============================================================================*/

options validvarname=upcase nodate nonumber ls=200;

libname sdtm "./data/sdtm";
libname adam "./data/adam";

ods html
  file="./sas/tfl/output/t_ae_01.html"
  style=HTMLBlue
  gtitle gfootnote;

title1 "Table 14.3.1";
title2 "Summary of Treatment-Emergent Adverse Events";
title3 "Safety Population";
title4 "Study NSVT-001 | NovaStat Therapeutics";
title5 "(NOTE: All data is AI-generated and synthetic - for demonstration purposes only)";

footnote1 "TEAE = Treatment-Emergent Adverse Event";
footnote2 "Subjects may be counted once per AE term; multiple AEs of same term counted once";
footnote3 "Source: ADAE - Generated via Altair SLC in Positron";

/* Denominator: N per treatment arm */
proc sql noprint;
  select trt01pn,
         trt01p,
         count(*) as n_arm
  into :tpn1-:tpn99, :tp1-:tp99, :na1-:na99
  from adam.adsl where saffl='Y'
  group by trt01pn, trt01p
  order by trt01pn;
  %let n_arms = &sqlobs;
quit;

/* Overall AE summary */
proc sql;
  title6 "Overall TEAE Summary";
  select
    'Any TEAE'                                  as category length=60,
    count(distinct case when trt01pn=0 and trtemfl='Y' then usubjid end) as n_plc,
    count(distinct case when trt01pn=1 and trtemfl='Y' then usubjid end) as n_low,
    count(distinct case when trt01pn=2 and trtemfl='Y' then usubjid end) as n_high,
    count(distinct case when trtemfl='Y' then usubjid end)               as n_total
  from adam.adae

  union all

  select
    'Any Serious TEAE',
    count(distinct case when trt01pn=0 and trtemfl='Y' and aeser='Y' then usubjid end),
    count(distinct case when trt01pn=1 and trtemfl='Y' and aeser='Y' then usubjid end),
    count(distinct case when trt01pn=2 and trtemfl='Y' and aeser='Y' then usubjid end),
    count(distinct case when trtemfl='Y' and aeser='Y' then usubjid end)
  from adam.adae

  union all

  select
    'Any TEAE Leading to Dropout',
    count(distinct case when trt01pn=0 and trtemfl='Y' and dptfl='Y' then usubjid end),
    count(distinct case when trt01pn=1 and trtemfl='Y' and dptfl='Y' then usubjid end),
    count(distinct case when trt01pn=2 and trtemfl='Y' and dptfl='Y' then usubjid end),
    count(distinct case when trtemfl='Y' and dptfl='Y' then usubjid end)
  from adam.adae;
quit;

/* Top AEs by System Organ Class */
title6 "TEAEs by System Organ Class and Preferred Term (>=5% in Any Arm)";
proc sql;
  create table _ae_by_term as
  select
    aebodsys,
    aedecod,
    count(distinct case when trt01pn=0 then usubjid end) as n_plc,
    count(distinct case when trt01pn=1 then usubjid end) as n_low,
    count(distinct case when trt01pn=2 then usubjid end) as n_high,
    count(distinct usubjid)                              as n_total
  from adam.adae
  where trtemfl='Y'
  group by aebodsys, aedecod
  having max(n_plc, n_low, n_high) >= 3
  order by aebodsys, n_total desc;
quit;

proc print data=_ae_by_term noobs label;
  var aebodsys aedecod n_plc n_low n_high n_total;
  label
    aebodsys = 'System Organ Class'
    aedecod  = 'Preferred Term'
    n_plc    = 'Placebo (n)'
    n_low    = 'NST-4892 100mg (n)'
    n_high   = 'NST-4892 200mg (n)'
    n_total  = 'Total (n)';
run;

/* AE severity distribution */
title6 "TEAE Severity Distribution by Treatment";
proc freq data=adam.adae(where=(trtemfl='Y'));
  table aesev * trt01p / nocum nopercent;
run;

title;
footnote;
ods html close;

%put NOTE: Table t_ae_01 written to ./sas/tfl/output/t_ae_01.html;
