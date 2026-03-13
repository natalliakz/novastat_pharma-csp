/*=============================================================================
  PROGRAM   : cdisc_validation.sas
  STUDY     : NSVT-001
  SPONSOR   : NovaStat Therapeutics (FICTIONAL - AI-generated demo only)
  PURPOSE   : CDISC compliance validation macros for ADSL and ADAE
              Demonstrates GxP-relevant validation within Altair SLC
  NOTE      : ALL DATA IS SYNTHETIC. For demonstration purposes only.
  OUTPUT    : ./sas/tfl/output/cdisc_validation_report.html
=============================================================================*/

options validvarname=upcase nodate nonumber ls=200;

libname sdtm "./data/sdtm";
libname adam "./data/adam";

/* Validation results collector */
data _val_results;
  length check_id $10 domain $6 check_name $80 status $4 n_issues 8 details $200;
  stop;
run;

/*=============================================================================
  MACRO: Log a validation result
=============================================================================*/
%macro log_check(id=, domain=, name=, status=PASS, n=0, details=);
  data _tmp;
    check_id  = "&id";
    domain    = "&domain";
    check_name= "&name";
    status    = "&status";
    n_issues  = &n;
    details   = "&details";
  run;
  proc append base=_val_results data=_tmp force; run;
%mend log_check;

/*=============================================================================
  CHECK 1: USUBJID Format
  Must follow pattern: STUDYID-SITEID-SUBJID (e.g., NSVT-001-101-001)
=============================================================================*/
proc sql noprint;
  select count(*) into :n_bad_usubjid trimmed
  from sdtm.dm
  where not prxmatch('/^NSVT-001-\d{3}-\d{3}$/', strip(usubjid));
quit;

%if &n_bad_usubjid = 0 %then %do;
  %log_check(id=CHK-01, domain=DM, name=USUBJID format conforms to STUDYID-SITEID-SUBJID,
             status=PASS, n=0, details=All USUBJIDs match expected pattern);
%end; %else %do;
  %log_check(id=CHK-01, domain=DM, name=USUBJID format conforms to STUDYID-SITEID-SUBJID,
             status=FAIL, n=&n_bad_usubjid, details=&n_bad_usubjid records have non-conforming USUBJID);
%end;

/*=============================================================================
  CHECK 2: Required DM Variables Present
=============================================================================*/
%macro check_vars_exist(domain=, vars=);
  %let n_missing = 0;
  %let missing_list = ;
  %let dsid = %sysfunc(open(&domain));
  %let vlist = %sysfunc(compbl(&vars));

  %let i = 1;
  %let v = %scan(&vlist, &i, %str( ));
  %do %while (&v ne );
    %if %sysfunc(varnum(&dsid, &v)) = 0 %then %do;
      %let n_missing = %eval(&n_missing + 1);
      %let missing_list = &missing_list &v;
    %end;
    %let i = %eval(&i + 1);
    %let v = %scan(&vlist, &i, %str( ));
  %end;
  %let rc = %sysfunc(close(&dsid));
  &n_missing /* return value */
%mend;

%let dm_required_vars = STUDYID DOMAIN USUBJID SUBJID SITEID AGE SEX RACE ETHNIC COUNTRY;
%let n_miss_dm = %check_vars_exist(domain=sdtm.dm, vars=&dm_required_vars);

%if &n_miss_dm = 0 %then %do;
  %log_check(id=CHK-02, domain=DM, name=Required DM SDTM variables present,
             status=PASS, n=0, details=All required DM variables found);
%end; %else %do;
  %log_check(id=CHK-02, domain=DM, name=Required DM SDTM variables present,
             status=FAIL, n=&n_miss_dm, details=Missing: &missing_list);
%end;

/*=============================================================================
  CHECK 3: One Record Per Subject in ADSL
=============================================================================*/
proc sql noprint;
  select count(*) - count(distinct usubjid) into :n_dup_adsl trimmed
  from adam.adsl;
quit;

%if &n_dup_adsl = 0 %then %do;
  %log_check(id=CHK-03, domain=ADSL, name=One record per subject (no duplicates),
             status=PASS, n=0, details=ADSL has unique records per USUBJID);
%end; %else %do;
  %log_check(id=CHK-03, domain=ADSL, name=One record per subject (no duplicates),
             status=FAIL, n=&n_dup_adsl, details=&n_dup_adsl duplicate USUBJID records found);
%end;

/*=============================================================================
  CHECK 4: DPTFL Consistency with DSDECOD
=============================================================================*/
proc sql noprint;
  /* DPTFL='Y' should have a non-COMPLETED DSDECOD */
  select count(*) into :n_inconsist trimmed
  from adam.adsl
  where (dptfl='Y' and dsdecod='COMPLETED')
     or (dptfl='N' and dsdecod ne 'COMPLETED');
quit;

%if &n_inconsist = 0 %then %do;
  %log_check(id=CHK-04, domain=ADSL, name=DPTFL consistent with DSDECOD,
             status=PASS, n=0, details=Dropout flag aligns with disposition reason);
%end; %else %do;
  %log_check(id=CHK-04, domain=ADSL, name=DPTFL consistent with DSDECOD,
             status=FAIL, n=&n_inconsist, details=&n_inconsist subjects have inconsistent DPTFL/DSDECOD);
%end;

/*=============================================================================
  CHECK 5: Date Integrity - RFSTDTC before RFENDTC
=============================================================================*/
proc sql noprint;
  select count(*) into :n_bad_dates trimmed
  from adam.adsl
  where input(rfstdtc, yymmdd10.) >= input(rfendtc, yymmdd10.);
quit;

%if &n_bad_dates = 0 %then %do;
  %log_check(id=CHK-05, domain=ADSL, name=RFSTDTC before RFENDTC for all subjects,
             status=PASS, n=0, details=All subjects have valid date ordering);
%end; %else %do;
  %log_check(id=CHK-05, domain=ADSL, name=RFSTDTC before RFENDTC for all subjects,
             status=FAIL, n=&n_bad_dates, details=&n_bad_dates subjects have RFSTDTC >= RFENDTC);
%end;

/*=============================================================================
  CHECK 6: AE Severity Values are in Controlled Terminology
=============================================================================*/
proc sql noprint;
  select count(*) into :n_bad_aesev trimmed
  from sdtm.ae
  where aesev not in ('MILD', 'MODERATE', 'SEVERE');
quit;

%if &n_bad_aesev = 0 %then %do;
  %log_check(id=CHK-06, domain=AE, name=AESEV within CDISC controlled terminology,
             status=PASS, n=0, details=All AESEV values are MILD / MODERATE / SEVERE);
%end; %else %do;
  %log_check(id=CHK-06, domain=AE, name=AESEV within CDISC controlled terminology,
             status=FAIL, n=&n_bad_aesev, details=&n_bad_aesev records have invalid AESEV values);
%end;

/*=============================================================================
  CHECK 7: Treatment Arm Balance (within 5 subjects per arm)
=============================================================================*/
proc sql noprint;
  select max(n) - min(n) into :arm_imbalance trimmed
  from (select trt01pn, count(*) as n from adam.adsl group by trt01pn);
quit;

%if &arm_imbalance <= 5 %then %do;
  %log_check(id=CHK-07, domain=ADSL, name=Treatment arm balance (max imbalance <= 5),
             status=PASS, n=0, details=Arms balanced - max imbalance is &arm_imbalance subjects);
%end; %else %do;
  %log_check(id=CHK-07, domain=ADSL, name=Treatment arm balance (max imbalance <= 5),
             status=WARN, n=&arm_imbalance, details=Arm imbalance of &arm_imbalance subjects detected);
%end;

/*=============================================================================
  CHECK 8: SAFFL and ITTFL Population Flags
=============================================================================*/
proc sql noprint;
  select count(*) into :n_missing_flags trimmed
  from adam.adsl
  where saffl not in ('Y','N') or ittfl not in ('Y','N');
quit;

%if &n_missing_flags = 0 %then %do;
  %log_check(id=CHK-08, domain=ADSL, name=SAFFL and ITTFL flags valid (Y or N),
             status=PASS, n=0, details=All population flags contain valid values);
%end; %else %do;
  %log_check(id=CHK-08, domain=ADSL, name=SAFFL and ITTFL flags valid (Y or N),
             status=FAIL, n=&n_missing_flags, details=&n_missing_flags records with invalid flag values);
%end;

/*=============================================================================
  CHECK 9: Compliance Percentage in Valid Range [0, 100]
=============================================================================*/
proc sql noprint;
  select count(*) into :n_bad_comp trimmed
  from adam.adsl
  where complpct < 0 or complpct > 100;
quit;

%if &n_bad_comp = 0 %then %do;
  %log_check(id=CHK-09, domain=ADSL, name=Compliance percentage in valid range [0-100],
             status=PASS, n=0, details=All compliance values are within expected range);
%end; %else %do;
  %log_check(id=CHK-09, domain=ADSL, name=Compliance percentage in valid range [0-100],
             status=FAIL, n=&n_bad_comp, details=&n_bad_comp records have out-of-range compliance);
%end;

/*=============================================================================
  CHECK 10: AE Records Link to Valid Subjects
=============================================================================*/
proc sql noprint;
  select count(*) into :n_orphan_ae trimmed
  from sdtm.ae ae
  where ae.usubjid not in (select usubjid from sdtm.dm);
quit;

%if &n_orphan_ae = 0 %then %do;
  %log_check(id=CHK-10, domain=AE, name=All AE records link to valid DM subjects,
             status=PASS, n=0, details=No orphan AE records found);
%end; %else %do;
  %log_check(id=CHK-10, domain=AE, name=All AE records link to valid DM subjects,
             status=FAIL, n=&n_orphan_ae, details=&n_orphan_ae AE records have no matching DM subject);
%end;

/*=============================================================================
  OUTPUT: HTML Validation Report
=============================================================================*/

/* Summary stats for report header */
proc sql noprint;
  select count(*) into :n_subj from adam.adsl;
  select count(*) into :n_ae   from sdtm.ae;
  select sum(dptfl='Y') into :n_dropout from adam.adsl;
  select sum(status='PASS') into :n_pass from _val_results;
  select sum(status='FAIL') into :n_fail from _val_results;
  select sum(status='WARN') into :n_warn from _val_results;
quit;

ods html
  file   = "./sas/tfl/output/cdisc_validation_report.html"
  style  = HTMLBlue
  gtitle
  gfootnote;

title1 "NSVT-001: CDISC Compliance Validation Report";
title2 "NovaStat Therapeutics | Study Drug: NST-4892 | Generated: &sysdate9";
title3 "(NOTE: All data is AI-generated and synthetic - for demonstration purposes only)";

footnote1 "Validation performed via Altair SLC within Positron IDE";
footnote2 "PASS=&n_pass  FAIL=&n_fail  WARN=&n_warn | Subjects=&n_subj | AE Records=&n_ae | Dropouts=&n_dropout";

proc print data=_val_results noobs label;
  var check_id domain check_name status n_issues details;
  label
    check_id   = 'Check ID'
    domain     = 'Domain'
    check_name = 'Validation Check'
    status     = 'Status'
    n_issues   = 'N Issues'
    details    = 'Details';
run;

title;
footnote;
ods html close;

%put NOTE: Validation complete. Report: ./sas/tfl/output/cdisc_validation_report.html;
%put NOTE: PASS=&n_pass  FAIL=&n_fail  WARN=&n_warn;
