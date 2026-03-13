/*=============================================================================
  PROGRAM   : generate_sdtm.sas
  STUDY     : NSVT-001
  SPONSOR   : NovaStat Therapeutics (FICTIONAL - AI-generated demo only)
  PURPOSE   : Generate synthetic SDTM datasets for a Phase 3 RA clinical trial
              Domains: DM, AE, EX, VS, DS
  NOTE      : ALL DATA IS SYNTHETIC AND AI-GENERATED. For demonstration only.
              Run via Altair SLC in Positron, or standard SAS 9.4+.
  OUTPUT    : ./data/sdtm/{dm,ae,ex,vs,ds}.csv
=============================================================================*/

options validvarname=upcase nodate nonumber ls=200 ps=max;

%let studyid  = NSVT-001;
%let drug     = NST-4892;
%let rand_seed = 42;

/*--- Ensure output directories exist ---*/
%macro mkdirs;
  %local rc fref;
  %let fref = sdtmdir;
  %if %sysfunc(fileexist(./data)) = 0 %then %do;
    %let rc = %sysfunc(dcreate(data, .));
  %end;
  %if %sysfunc(fileexist(./data/sdtm)) = 0 %then %do;
    %let rc = %sysfunc(dcreate(sdtm, ./data));
  %end;
  %put NOTE: Output directory ./data/sdtm is ready.;
%mend mkdirs;
%mkdirs;

libname sdtm "./data/sdtm";

/*=============================================================================
  STEP 1: DEMOGRAPHICS (DM)
  CDISC SDTM v3.3 DM domain
=============================================================================*/

/* Site reference data */
data _sites;
  length siteid $3 country $3 region $15;
  input siteid $ country $ region : $15. n_subj;
  datalines;
101 USA Americas 40
102 USA Americas 35
103 USA Americas 38
104 USA Americas 37
105 DEU Europe 32
106 DEU Europe 30
107 GBR Europe 33
108 JPN AsiaPacific 35
;
run;

/* Generate subject-level demographics */
data dm_work (drop=_: n_subj subj_n);
  length studyid $10 domain $2 usubjid $20 subjid $5 siteid $3
         country $3 region $15 sex $1 race $50 ethnic $40 agegr1 $6
         trt01p $20 arm $20 actarm $20 rfstdtc $10 rfendtc $10 dasgrp $10;

  set _sites;
  call streaminit(&rand_seed);

  do subj_n = 1 to n_subj;

    /* --- Identifiers --- */
    studyid = "&studyid";
    domain  = 'DM';
    subjid  = put(subj_n, z3.);
    usubjid = cats(studyid, '-', siteid, '-', put(subj_n, z3.));

    /* --- Age: 25-70, typical RA range --- */
    age = round(25 + rand('uniform') * 45);
    select;
      when (age < 40) agegr1 = '<40';
      when (age < 65) agegr1 = '40-64';
      otherwise       agegr1 = '>=65';
    end;

    /* --- Sex: 60% Female (RA population skews female) --- */
    sex = ifc(rand('bernoulli', 0.60) = 1, 'F', 'M');

    /* --- Race: country-appropriate distribution --- */
    select (country);
      when ('USA') _r = rand('table', 0.62, 0.13, 0.12, 0.13);
      when ('DEU') _r = rand('table', 0.90, 0.03, 0.04, 0.03);
      when ('GBR') _r = rand('table', 0.86, 0.06, 0.05, 0.03);
      when ('JPN') _r = rand('table', 0.01, 0.01, 0.97, 0.01);
      otherwise    _r = rand('table', 0.50, 0.15, 0.25, 0.10);
    end;
    select (_r);
      when (1) race = 'WHITE';
      when (2) race = 'BLACK OR AFRICAN AMERICAN';
      when (3) race = 'ASIAN';
      when (4) race = 'AMERICAN INDIAN OR ALASKA NATIVE';
      otherwise race = 'UNKNOWN';
    end;

    /* --- Ethnicity --- */
    if country = 'USA' and rand('bernoulli', 0.18) = 1
      then ethnic = 'HISPANIC OR LATINO';
    else ethnic = 'NOT HISPANIC OR LATINO';

    /* --- Physical characteristics (sex-adjusted) --- */
    if sex = 'F' then do;
      heightbl = max(148, min(185, round(158 + rand('normal', 0, 6))));
      weightbl = max(44,  min(112, round(64  + rand('normal', 0, 11))));
    end;
    else do;
      heightbl = max(158, min(200, round(175 + rand('normal', 0, 7))));
      weightbl = max(54,  min(135, round(82  + rand('normal', 0, 13))));
    end;
    bmibl = round(weightbl / ((heightbl / 100) ** 2), 0.1);

    /* --- DAS28 (Disease Activity Score): 2.0-8.5, mean ~5.2 --- */
    /* Higher DAS28 = more severe RA, correlates with more AEs and dropout */
    dascr = max(2.0, min(8.5, round(5.2 + rand('normal', 0, 1.1), 0.1)));
    select;
      when (dascr < 3.2) dasgrp = 'Remission';
      when (dascr < 3.7) dasgrp = 'Low';
      when (dascr < 5.1) dasgrp = 'Moderate';
      otherwise          dasgrp = 'High';
    end;

    /* --- Treatment: 1:1:1 balanced within site --- */
    trt01pn = mod(subj_n - 1, 3);
    select (trt01pn);
      when (0) trt01p = 'Placebo';
      when (1) trt01p = cats("&drug", ' 100mg');
      when (2) trt01p = cats("&drug", ' 200mg');
    end;
    arm    = trt01p;
    actarm = trt01p;

    /* --- Study dates --- */
    /* Randomization: Jan 2023 - Jun 2023 (180-day window) */
    _rfstdt = '01Jan2023'd + floor(rand('uniform') * 180);
    rfstdtc = put(_rfstdt, yymmdd10.);
    /* Planned EOS: 24 weeks (168 days) from randomization */
    rfendtc = put(_rfstdt + 168, yymmdd10.);

    output;
  end;
run;

/* Add sequence numbers and flags */
data sdtm.dm;
  set dm_work;
  by siteid;
  dmseq  = _n_;
  saffl  = 'Y';
  ittfl  = 'Y';
  pprotfl = ifc(rand('bernoulli', 0.95) = 1, 'Y', 'N');
  label
    studyid = 'Study Identifier'
    usubjid = 'Unique Subject Identifier'
    age     = 'Age (years)'
    sex     = 'Sex'
    race    = 'Race'
    dascr   = 'DAS28 Score at Baseline'
    bmibl   = 'BMI at Baseline (kg/m2)'
    trt01p  = 'Planned Treatment for Period 01'
    trt01pn = 'Planned Treatment for Period 01 (N)'
    rfstdtc = 'Subject Reference Start Date/Time'
    rfendtc = 'Subject Reference End Date/Time';
run;

proc export data=sdtm.dm
  outfile="./data/sdtm/dm.csv"
  dbms=csv replace;
run;
%put NOTE: DM: %sysfunc(attrn(open(sdtm.dm), nobs)) subjects generated.;

/*=============================================================================
  STEP 2: ADVERSE EVENTS (AE)
  Generates 1 record per AE occurrence; ~1.5-3 AEs per subject on active
=============================================================================*/

/* AE term dictionary with base probabilities and severity weights */
data _ae_dict;
  length aedecod $60 aebodsys $60;
  input aedecod : $60. aebodsys : $60. base_prob sev_severe_p;
  datalines;
Headache                          Nervous_System_Disorders                0.28 0.04
Nausea                            Gastrointestinal_Disorders              0.22 0.03
Fatigue                           General_Disorders                       0.25 0.06
Upper_Respiratory_Tract_Infection Infections_and_Infestations             0.16 0.02
Arthralgia                        Musculoskeletal_Disorders               0.20 0.07
Hypertension                      Vascular_Disorders                      0.13 0.10
Rash                              Skin_and_Subcutaneous_Tissue_Disorders  0.11 0.08
Dizziness                         Nervous_System_Disorders                0.13 0.03
Insomnia                          Psychiatric_Disorders                   0.10 0.02
ALT_Increased                     Investigations                          0.09 0.12
;
run;

/* Replace underscores with spaces in labels */
data _ae_dict;
  set _ae_dict;
  aedecod = tranwrd(aedecod, '_', ' ');
  aebodsys = tranwrd(aebodsys, '_', ' ');
run;

/* Cross-join subjects with AE types, apply random filter */
proc sql noprint;
  create table _ae_cross as
  select
    d.usubjid,
    d.trt01pn,
    d.age,
    d.dascr,
    d.rfstdtc,
    d.siteid,
    a.aedecod,
    a.aebodsys,
    /* Adjust AE probability: active drug has more AEs, older and sicker subjects too */
    min(0.60,
      a.base_prob
      * (1 + d.trt01pn * 0.18)
      * (1 + max(0, (d.age - 45) * 0.008))
      * (1 + max(0, (d.dascr - 4.5) * 0.06))
    ) as adj_prob,
    a.sev_severe_p
  from sdtm.dm d
  cross join _ae_dict a;
quit;

data sdtm.ae (drop=_: adj_prob sev_severe_p trt01pn age dascr rfstdtc siteid);
  length studyid $10 domain $2 usubjid $20 aedecod $60 aebodsys $60
         aesev $10 aeser $1 aerel $30 aeout $60
         aestdtc $10 aeendtc $10 visit $15;

  set _ae_cross;
  by usubjid;

  call streaminit(777);

  if first.usubjid then _seq = 0;

  /* Randomly include this AE based on adjusted probability */
  if rand('uniform') < adj_prob then do;

    studyid = "&studyid";
    domain  = 'AE';
    _seq    + 1;
    aeseq   = _seq;

    _rfstdt  = input(rfstdtc, yymmdd10.);
    _visit_n = ceil(rand('uniform') * 6);   /* Visit 1-6 */
    visitnum = _visit_n;
    visit    = cats('WEEK ', _visit_n * 4);

    _ae_day = max(1, floor(rand('uniform') * (_visit_n * 28)));
    aestdtc = put(_rfstdt + _ae_day, yymmdd10.);
    _dur    = max(1, round(rand('gamma', 2, 7)));
    aeendtc = put(_rfstdt + _ae_day + _dur, yymmdd10.);

    /* Severity: weighted toward mild/moderate */
    _sv = rand('uniform');
    if _sv < sev_severe_p * (1 + trt01pn * 0.15) then do;
      aesev  = 'SEVERE';  _aesevn = 3;
    end;
    else if _sv < 0.38 then do;
      aesev  = 'MODERATE'; _aesevn = 2;
    end;
    else do;
      aesev  = 'MILD';     _aesevn = 1;
    end;

    /* Seriousness: only severe can be serious */
    aeser = ifc(_aesevn = 3 and rand('bernoulli', 0.35) = 1, 'Y', 'N');

    /* Relationship to study drug */
    _rel_p = ifc(trt01pn = 0, 0.12, 0.32 + trt01pn * 0.08);
    aerel  = ifc(rand('bernoulli', _rel_p) = 1, 'RELATED', 'NOT RELATED');

    /* Outcome */
    if _aesevn = 3 and rand('bernoulli', 0.15) = 1
      then aeout = 'NOT RECOVERED/NOT RESOLVED';
    else aeout = 'RECOVERED/RESOLVED';

    output;
  end;
  retain _seq;
run;

proc export data=sdtm.ae
  outfile="./data/sdtm/ae.csv"
  dbms=csv replace;
run;
%put NOTE: AE: %sysfunc(attrn(open(sdtm.ae), nobs)) adverse event records generated.;

/*=============================================================================
  STEP 3: EXPOSURE (EX)
  One record per dose administration summary visit
=============================================================================*/

data sdtm.ex (drop=_: subj_n trt01pn rfstdtc);
  length studyid $10 domain $2 usubjid $20
         extrt $30 exdosu $5 exroute $10 exoccur $1
         exstdtc $10 exendtc $10 visit $15;

  set sdtm.dm (keep=usubjid trt01pn rfstdtc siteid);
  call streaminit(321);

  studyid = "&studyid";
  domain  = 'EX';
  exroute = 'SUBCUTANEOUS';
  exdosu  = 'mg';

  _rfstdt = input(rfstdtc, yymmdd10.);

  select (trt01pn);
    when (0) do; extrt = 'PLACEBO';          exdose = 0;   end;
    when (1) do; extrt = cats("&drug",' 100mg'); exdose = 100; end;
    when (2) do; extrt = cats("&drug",' 200mg'); exdose = 200; end;
  end;

  /* One EX record per 4-week visit block (6 visits) */
  do _vis = 1 to 6;
    visitnum = _vis;
    visit    = cats('WEEK ', _vis * 4);

    /* Compliance: ~88% average, more variable for active arms */
    _comp = max(0, min(1, 0.88 + rand('normal', 0, 0.08)));

    /* Missing dose (non-compliance) */
    exoccur = ifc(rand('bernoulli', _comp) = 1, 'Y', 'N');

    _vis_start = _rfstdt + (_vis - 1) * 28;
    _vis_end   = _rfstdt + _vis * 28 - 1;

    exstdtc = put(_vis_start, yymmdd10.);
    exendtc = put(_vis_end, yymmdd10.);
    exseq   = _vis;

    output;
  end;
run;

proc export data=sdtm.ex
  outfile="./data/sdtm/ex.csv"
  dbms=csv replace;
run;
%put NOTE: EX: %sysfunc(attrn(open(sdtm.ex), nobs)) exposure records generated.;

/*=============================================================================
  STEP 4: VITAL SIGNS (VS)
  DAS28-CRP proxy measurements per visit
=============================================================================*/

data sdtm.vs (drop=_: rfstdtc trt01pn dascr);
  length studyid $10 domain $2 usubjid $20 vstestcd $8 vstest $40
         vsorresu $10 vsstresn 8 vsstresc $20 visit $15 vsdtc $10;

  set sdtm.dm (keep=usubjid trt01pn dascr rfstdtc);
  call streaminit(456);

  studyid = "&studyid";
  domain  = 'VS';

  _rfstdt = input(rfstdtc, yymmdd10.);

  /* Treatment effect on DAS28: active drug reduces score over time */
  _trt_effect = trt01pn * 0.35;  /* per visit reduction for active */

  do _vis = 0 to 6;  /* Visit 0 = Screening/Baseline */
    visitnum = _vis;
    if _vis = 0 then visit = 'SCREENING';
    else visit = cats('WEEK ', _vis * 4);

    _vsdtc = _rfstdt + _vis * 28;
    vsdtc  = put(_vsdtc, yymmdd10.);
    vsseq  + 1;

    /* DAS28 score */
    vstestcd = 'DAS28';
    vstest   = 'DAS28-CRP Disease Activity Score';
    vsorresu = 'score';
    _das_val = max(1.0, min(9.4,
      dascr
      - (_vis * _trt_effect)
      + rand('normal', 0, 0.4)
    ));
    vsstresn = round(_das_val, 0.1);
    vsstresc = put(vsstresn, 5.1);
    output;

    /* Tender Joint Count (TJC28) */
    vstestcd = 'TJC28';
    vstest   = 'Tender Joint Count (28 joints)';
    vsorresu = 'count';
    vsstresn = max(0, round(8 - (_vis * trt01pn * 0.3) + rand('normal', 0, 1.5)));
    vsstresc = put(vsstresn, 4.);
    output;

    /* Swollen Joint Count (SJC28) */
    vstestcd = 'SJC28';
    vstest   = 'Swollen Joint Count (28 joints)';
    vsorresu = 'count';
    vsstresn = max(0, round(6 - (_vis * trt01pn * 0.25) + rand('normal', 0, 1.3)));
    vsstresc = put(vsstresn, 4.);
    output;

  end;
  retain vsseq;
run;

proc export data=sdtm.vs
  outfile="./data/sdtm/vs.csv"
  dbms=csv replace;
run;
%put NOTE: VS: %sysfunc(attrn(open(sdtm.vs), nobs)) vital sign records generated.;

/*=============================================================================
  STEP 5: DISPOSITION (DS)
  Determine dropout and reason; one record per subject
=============================================================================*/

/* Aggregate AE burden per subject (drives dropout) */
proc sql noprint;
  create table _ae_summary as
  select
    usubjid,
    count(*)                                 as aenum,
    sum(aeser = 'Y')                         as aesnum,
    max(case aesev
          when 'SEVERE'   then 3
          when 'MODERATE' then 2
          else 1 end)                        as aemaxsevn
  from sdtm.ae
  group by usubjid;
quit;

/* Compliance summary per subject */
proc sql noprint;
  create table _ex_summary as
  select
    usubjid,
    mean(exoccur = 'Y') * 100 as complpct format=5.1
  from sdtm.ex
  group by usubjid;
quit;

/* Compute dropout probability and generate DS */
proc sql noprint;
  create table _dropout_input as
  select
    d.usubjid,
    d.trt01pn,
    d.siteid,
    d.rfstdtc,
    d.rfendtc,
    coalesce(a.aenum,     0) as aenum,
    coalesce(a.aesnum,    0) as aesnum,
    coalesce(a.aemaxsevn, 0) as aemaxsevn,
    coalesce(e.complpct, 100) as complpct
  from sdtm.dm d
  left join _ae_summary  a on d.usubjid = a.usubjid
  left join _ex_summary  e on d.usubjid = e.usubjid;
quit;

data sdtm.ds (drop=_: aenum aesnum aemaxsevn complpct trt01pn);
  length studyid $10 domain $2 usubjid $20 dscat $30 dsscat $20
         dsdecod $60 dsterm $80 dsstdtc $10;

  set _dropout_input;
  call streaminit(888);

  studyid = "&studyid";
  domain  = 'DS';
  dscat   = 'DISPOSITION EVENT';
  dsseq   = 1;

  /* Dropout probability model */
  _dp = 0.05
      + (aenum      >  2) * 0.10
      + (aenum      >  4) * 0.08
      + (aemaxsevn  =  3) * 0.18
      + (aesnum     >= 1) * 0.08
      + (complpct   < 80) * 0.09
      + (siteid in ('107', '108')) * 0.05
      + (trt01pn    =  2) * 0.03;

  _dropout = rand('bernoulli', min(0.65, _dp));

  if _dropout then do;
    /* Dropout reason weighted by AE severity */
    if aemaxsevn = 3 or aesnum >= 1 then
      _dr = rand('table', 0.60, 0.25, 0.10, 0.05);
    else
      _dr = rand('table', 0.25, 0.45, 0.20, 0.10);

    select (_dr);
      when (1) do;
        dsdecod = 'ADVERSE EVENT';
        dsterm  = 'Discontinued due to adverse event';
        dsscat  = 'STUDY DRUG';
      end;
      when (2) do;
        dsdecod = 'WITHDRAWAL BY SUBJECT';
        dsterm  = 'Subject withdrew consent';
        dsscat  = 'SUBJECT DECISION';
      end;
      when (3) do;
        dsdecod = 'LOST TO FOLLOW-UP';
        dsterm  = 'Subject lost to follow-up';
        dsscat  = 'OTHER';
      end;
      otherwise do;
        dsdecod = 'PROTOCOL DEVIATION';
        dsterm  = 'Discontinued due to protocol deviation';
        dsscat  = 'OTHER';
      end;
    end;

    /* Dropout date: somewhere in first 5 visits */
    _rfstdt  = input(rfstdtc, yymmdd10.);
    _dpday   = round(rand('uniform') * 140) + 14;
    dsstdtc  = put(_rfstdt + _dpday, yymmdd10.);
    eosstt   = 'DISCONTINUED';
  end;
  else do;
    dsdecod = 'COMPLETED';
    dsterm  = 'Completed study as planned';
    dsscat  = 'STUDY COMPLETION';
    dsstdtc = rfendtc;
    eosstt  = 'COMPLETED';
  end;

  dptfl = ifc(_dropout = 1, 'Y', 'N');

  label
    dsdecod = 'Standardized Disposition Term'
    eosstt  = 'End of Study Status'
    dptfl   = 'Dropout Flag';
run;

proc export data=sdtm.ds
  outfile="./data/sdtm/ds.csv"
  dbms=csv replace;
run;
%put NOTE: DS: %sysfunc(attrn(open(sdtm.ds), nobs)) disposition records generated.;

/*=============================================================================
  SUMMARY REPORT
=============================================================================*/
proc sql;
  title 'NSVT-001: SDTM Dataset Summary';
  select
    'DM' as domain length=4,
    count(distinct usubjid)                                    as n_subjects,
    sum(trt01pn=0)                                             as n_placebo,
    sum(trt01pn=1)                                             as n_low_dose label='N Low Dose',
    sum(trt01pn=2)                                             as n_high_dose label='N High Dose'
  from sdtm.dm;

  select
    'Dropout Rate by Treatment' as summary length=30,
    ds.dsdecod,
    count(*) as n
  from sdtm.ds ds
  group by dsdecod
  order by n desc;
quit;
title;

%put NOTE: SDTM generation complete. Files written to ./data/sdtm/;
%put NOTE: Run create_adam.sas next to generate ADaM datasets.;
