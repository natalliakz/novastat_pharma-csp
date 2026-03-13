/*=============================================================================
  PROGRAM   : create_adam.sas
  STUDY     : NSVT-001
  SPONSOR   : NovaStat Therapeutics (FICTIONAL - AI-generated demo only)
  PURPOSE   : Create ADaM datasets (ADSL, ADAE) from SDTM source
  REQUIRES  : generate_sdtm.sas must be run first
  NOTE      : ALL DATA IS SYNTHETIC. For demonstration purposes only.
  OUTPUT    : ./data/adam/{adsl,adae}.csv
=============================================================================*/

options validvarname=upcase nodate nonumber ls=200;

%let studyid = NSVT-001;

/*--- Ensure output directory ---*/
%macro mkdirs;
  %if %sysfunc(fileexist(./data/adam)) = 0 %then %do;
    %let rc = %sysfunc(dcreate(adam, ./data));
  %end;
  %put NOTE: Output directory ./data/adam is ready.;
%mend mkdirs;
%mkdirs;

libname sdtm "./data/sdtm";
libname adam "./data/adam";

/*=============================================================================
  ADSL: Subject Level Analysis Dataset
  One record per subject; contains all subject-level variables used in ML
=============================================================================*/

/* --- Aggregate AE features (ML predictors) --- */
proc sql noprint;
  create table _ae_feat as
  select
    usubjid,
    count(*)                                             as aenum
      label='Total AE Count',
    sum(aeser = 'Y')                                     as aesnum
      label='Serious AE Count',
    max(case aesev
          when 'SEVERE'   then 3
          when 'MODERATE' then 2
          else 1 end)                                    as aemaxsevn
      label='Max AE Severity (N)',
    max(case aesev
          when 'SEVERE'   then 'SEVERE'
          when 'MODERATE' then 'MODERATE'
          else 'MILD' end)                               as aemaxsev length=10
      label='Max AE Severity',
    sum(aedecod = 'ALT Increased')                       as n_alt_ae
      label='N ALT Increased AEs',
    sum(aedecod in ('Headache','Nausea','Fatigue','Dizziness','Insomnia'))
                                                         as n_neuro_gi_ae
      label='N Neuro/GI AEs'
  from sdtm.ae
  group by usubjid;
quit;

/* --- Compliance from EX --- */
proc sql noprint;
  create table _ex_feat as
  select
    usubjid,
    mean(exoccur = 'Y') * 100   as complpct format=5.1
      label='% Doses Taken (Compliance)',
    sum(exoccur = 'N')          as n_missed_doses
      label='N Missed Doses'
  from sdtm.ex
  group by usubjid;
quit;

/* --- Baseline and last DAS28 from VS --- */
proc sql noprint;
  create table _vs_feat as
  select
    b.usubjid,
    b.vsstresn                       as das28bl  label='DAS28 at Baseline',
    l.vsstresn                       as das28last label='DAS28 at Last Visit',
    l.vsstresn - b.vsstresn          as das28chg  label='DAS28 Change from Baseline',
    case
      when (l.vsstresn - b.vsstresn) < -1.2 then 'RESPONDER'
      else 'NON-RESPONDER'
    end                              as acr20fl length=15
      label='ACR20 Response Flag'
  from
    (select usubjid, vsstresn from sdtm.vs
     where vstestcd='DAS28' and visitnum=0) b
  join
    (select usubjid, max(visitnum) as last_vis from sdtm.vs
     where vstestcd='DAS28' group by usubjid) lv
    on b.usubjid = lv.usubjid
  join
    (select usubjid, visitnum, vsstresn from sdtm.vs
     where vstestcd='DAS28') l
    on l.usubjid = lv.usubjid and l.visitnum = lv.last_vis;
quit;

/* --- Build ADSL --- */
proc sql noprint;
  create table adam.adsl as
  select
    d.studyid,
    'ADSL'                       as dataset  length=4,
    d.usubjid,
    d.subjid,
    d.siteid,
    d.country,
    d.region,
    d.age,
    d.agegr1,
    d.sex,
    case d.sex when 'F' then 1 else 2 end as sexn
      label='Sex (N)',
    d.race,
    case d.race
      when 'WHITE'                          then 1
      when 'BLACK OR AFRICAN AMERICAN'      then 2
      when 'ASIAN'                          then 3
      else 4
    end                          as racen
      label='Race (N)',
    d.ethnic,
    d.heightbl,
    d.weightbl,
    d.bmibl,
    case
      when d.bmibl < 18.5 then 'Underweight'
      when d.bmibl < 25.0 then 'Normal'
      when d.bmibl < 30.0 then 'Overweight'
      else                     'Obese'
    end                          as bmigrp length=12
      label='BMI Group',
    d.dascr    as das28bl        label='DAS28 at Baseline',
    d.dasgrp   as das28grp,
    d.trt01p,
    d.trt01pn,
    d.arm,
    d.actarm,
    d.rfstdtc,
    d.rfendtc,
    d.saffl,
    d.ittfl,
    d.pprotfl,
    ds.dsdecod,
    ds.eosstt,
    ds.dptfl,
    ds.dsstdtc as dcdt           label='Discontinuation Date',
    coalesce(ae.aenum,        0) as aenum,
    coalesce(ae.aesnum,       0) as aesnum,
    coalesce(ae.aemaxsevn,    0) as aemaxsevn,
    coalesce(ae.aemaxsev, 'NONE') as aemaxsev  length=10,
    coalesce(ae.n_alt_ae,     0) as n_alt_ae,
    coalesce(ae.n_neuro_gi_ae,0) as n_neuro_gi_ae,
    coalesce(ex.complpct,   100) as complpct,
    coalesce(ex.n_missed_doses,0) as n_missed_doses,
    case when coalesce(ex.complpct, 100) >= 80
         then 'Compliant' else 'Non-Compliant' end as complfl length=14
      label='Compliance Flag (>=80%)',
    coalesce(vs.das28chg,  0)    as das28chg,
    coalesce(vs.acr20fl, 'UNKNOWN') as acr20fl  length=15
  from sdtm.dm d
  left join sdtm.ds  ds on d.usubjid = ds.usubjid
  left join _ae_feat ae on d.usubjid = ae.usubjid
  left join _ex_feat ex on d.usubjid = ex.usubjid
  left join _vs_feat vs on d.usubjid = vs.usubjid
  order by d.siteid, d.usubjid;
quit;

/* Add region numeric for ML */
data adam.adsl;
  set adam.adsl;
  regionn = (region = 'Europe') * 1 + (region = 'AsiaPacific') * 2;
  label regionn = 'Region (N): 0=Americas, 1=Europe, 2=AsiaPac';

  /* Target variable numeric: 1=dropout, 0=completed */
  dptn = (dptfl = 'Y');
  label dptn = 'Dropout (1=Yes, 0=No)';
run;

proc export data=adam.adsl
  outfile="./data/adam/adsl.csv"
  dbms=csv replace;
run;
%put NOTE: ADSL: %sysfunc(attrn(open(adam.adsl), nobs)) subjects.;
%put NOTE: Dropout rate: check ADSL.DPTFL;

/*=============================================================================
  ADAE: Adverse Event Analysis Dataset
  One record per AE; includes treatment-emergent flag and ADSL merge
=============================================================================*/

proc sql noprint;
  create table adam.adae as
  select
    a.studyid,
    'ADAE'        as dataset  length=4,
    a.usubjid,
    s.siteid,
    s.trt01p,
    s.trt01pn,
    s.age,
    s.sex,
    s.dptfl,
    a.aeseq,
    a.aedecod,
    a.aebodsys,
    a.aesev,
    case a.aesev
      when 'SEVERE'   then 3
      when 'MODERATE' then 2
      else 1
    end           as aesevn   label='AE Severity (N)',
    a.aeser,
    a.aerel,
    a.aeout,
    a.aestdtc,
    a.aeendtc,
    a.visitnum,
    a.visit,
    /* Treatment-emergent: AE starts on/after treatment start */
    case when input(a.aestdtc, yymmdd10.) >= input(s.rfstdtc, yymmdd10.)
         then 'Y' else 'N' end as trtemfl length=1
      label='Treatment-Emergent AE Flag'
  from sdtm.ae a
  join adam.adsl s on a.usubjid = s.usubjid
  order by a.usubjid, a.aeseq;
quit;

proc export data=adam.adae
  outfile="./data/adam/adae.csv"
  dbms=csv replace;
run;
%put NOTE: ADAE: %sysfunc(attrn(open(adam.adae), nobs)) AE records.;

/*=============================================================================
  SUMMARY CHECK
=============================================================================*/
proc sql;
  title 'ADSL: Subject Counts by Treatment and Dropout Status';
  select trt01p,
         count(*)             as n_total,
         sum(dptfl='Y')       as n_dropout,
         mean(dptfl='Y')*100  as pct_dropout format=5.1
  from adam.adsl
  group by trt01p
  order by trt01pn;

  title 'ADSL: Mean Compliance and AE Count by Dropout Status';
  select dptfl,
         count(*)             as n,
         mean(complpct)       as mean_compliance format=5.1,
         mean(aenum)          as mean_ae_count   format=4.1,
         mean(aemaxsevn)      as mean_max_sev    format=4.2
  from adam.adsl
  group by dptfl;
quit;
title;

%put NOTE: ADaM creation complete. Files written to ./data/adam/;
%put NOTE: Run cdisc_validation.sas next to validate the datasets.;
