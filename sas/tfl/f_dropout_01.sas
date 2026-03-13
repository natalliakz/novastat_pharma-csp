/*=============================================================================
  PROGRAM   : f_dropout_01.sas
  STUDY     : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
  OUTPUT    : Figure 14.1.1 - Patient Dropout Rate by Site and Treatment Arm
  NOTE      : ALL DATA IS SYNTHETIC. For demonstration purposes only.
=============================================================================*/

options validvarname=upcase nodate nonumber ls=200;

libname adam "./data/adam";

ods html
  file="./sas/tfl/output/f_dropout_01.html"
  style=HTMLBlue
  gtitle gfootnote;
ods graphics on / width=900px height=600px imagefmt=png;

title1 "Figure 14.1.1";
title2 "Patient Dropout Rate by Site";
title3 "Intent-to-Treat Population | Study NSVT-001";
title4 "(NOTE: All data is AI-generated and synthetic - for demonstration purposes only)";
footnote1 "Dropout = Subjects who discontinued prior to study completion for any reason";
footnote2 "Numbers above bars indicate N dropout / N enrolled per site";

/* Dropout rate by site */
proc sql noprint;
  create table _site_dropout as
  select
    siteid,
    country,
    region,
    count(*)             as n_total,
    sum(dptfl='Y')       as n_dropout,
    mean(dptfl='Y')*100  as pct_dropout format=5.1,
    mean(complpct)       as mean_comp   format=5.1,
    mean(aenum)          as mean_ae     format=4.1
  from adam.adsl
  where ittfl='Y'
  group by siteid, country, region
  order by pct_dropout desc;
quit;

/* Figure 1: Dropout by site with country colour */
proc sgplot data=_site_dropout;
  vbar siteid / response=pct_dropout group=country
               groupdisplay=cluster
               datalabel
               datalabelattrs=(size=9 weight=bold)
               fillattrs=(transparency=0.15);
  refline 25 / axis=y lineattrs=(pattern=dash color=red)
               label='Overall Target (<25%)' labelattrs=(color=red);
  xaxis label='Clinical Site ID' discreteorder=data;
  yaxis label='Dropout Rate (%)' min=0 max=60 grid;
  keylegend / title='Country';
  inset "Dashed line = 25% target threshold" / position=topleft;
run;

/* Figure 2: Dropout rate by treatment arm */
proc sql noprint;
  create table _trt_dropout as
  select
    trt01p,
    trt01pn,
    count(*)             as n_total,
    sum(dptfl='Y')       as n_dropout,
    mean(dptfl='Y')*100  as pct_dropout format=5.1
  from adam.adsl
  where ittfl='Y'
  group by trt01p, trt01pn
  order by trt01pn;
quit;

title2 "Dropout Rate by Treatment Arm";
proc sgplot data=_trt_dropout;
  vbar trt01p / response=pct_dropout
               datalabel datalabelattrs=(size=10 weight=bold)
               fillattrs=(color=CX1B4F8A transparency=0.2)
               barwidth=0.5;
  xaxis label='Treatment Arm';
  yaxis label='Dropout Rate (%)' min=0 max=50 grid;
run;

/* Figure 3: Dropout reason breakdown */
title2 "Dropout Reason Distribution by Treatment";
proc sql noprint;
  create table _reason_trt as
  select
    trt01p, trt01pn,
    dsdecod,
    count(*) as n
  from adam.adsl
  where dptfl='Y' and ittfl='Y'
  group by trt01p, trt01pn, dsdecod;
quit;

proc sgplot data=_reason_trt;
  vbar trt01p / response=n group=dsdecod
               groupdisplay=stack
               datalabel
               fillattrs=(transparency=0.1);
  xaxis label='Treatment Arm';
  yaxis label='Number of Subjects' grid;
  keylegend / title='Discontinuation Reason' position=topright;
run;

/* Figure 4: Kaplan-Meier style dropout over time (approximated by visit) */
title2 "Cumulative Dropout by Week and Treatment Arm";
proc sql noprint;
  /* Approximate visit from dropout date */
  create table _km_data as
  select
    trt01p,
    trt01pn,
    case
      when dcdt = ' ' then 168
      else min(168, max(0, input(dcdt, yymmdd10.) - input(rfstdtc, yymmdd10.)))
    end as days_to_event,
    (dptfl='Y') as event_fl
  from adam.adsl
  where ittfl='Y';
quit;

proc lifetest data=_km_data plots=survival(atrisk nocensor) notable;
  time days_to_event * event_fl(0);
  strata trt01p / order=internal;
  label days_to_event='Days on Study';
  title3 'Time to Dropout by Treatment Arm (Survival = Retention)';
run;

title;
footnote;
ods graphics off;
ods html close;

%put NOTE: Figure f_dropout_01 written to ./sas/tfl/output/f_dropout_01.html;
