/*************************************************************************
Match Mortgage & Transaction Data in GSE and TITLE
Step 1:	Filter GSE fannie acuisition data
Step 2:	Filter Title dataset (mortgage + transaction)
Step 3:	Match GSE & Title 
Step 4:	Show Result
Date:	May 27, 2015
Author:	Yuancheng Zhang
On server:	/opt/data/PRJ/Match_GSE_Title/
Github:		github.com/vmvc2v/match-gse-title
*************************************************************************/

option compress = yes;

libname f	"./";
libname gseds	"/opt/data/datamain/GSE/sas_dataset/";
libname titleds	"/opt/data/PRJ/Rep_All/Rep2014Q4/sas_dataset/";

/*******************/ 
/*	Source dataset	;
GSE 2012Q1:						fannie_acquisition2012.sas7bdat
Mortgage and transaction data:	match_trans_mort_matchlong.sas7bdat
********************/

/********************/
/*   set macro var	*/
%let macro_yr = 2012;
%let macro_qt = Q1;	/* if for all year data, put 0 here */
%let alpha = 0.05;
*********************;

/********************/
/*   The main steps	*/
%macro main(yr = &macro_yr, qt = substr("&macro_qt.",2,1));
%put ~~~~~ Start Running ~~~~~;
%filter_gse(&yr., &qt.);
%filter_mort(&yr., &qt.);
%match();
%result();
%mend main;

/*****************************/
/* Step 1: Filter GSE fannie acuisition dataset*/
%macro filter_gse(yr, qt);
%put ~~~~~ Step 1: Filter GSE fannie acuisition dataset ~~~~~;
%test0_1(&yr);
%step1_1(&yr);
%step1_2();
%step1_3(&yr., &qt.);
%step1_4();
%mend filter_gse; 

/* Test 1: Output a part of GSE/TITLE data as test sets */
%macro test0_1(yr);
%put ~~~~~ Test 1: Output a part of GSE/TITLE data as test sets ~~~~~;
data f.test_gse;
set gseds.fannie_acquisition&yr. (obs=500);
run;
data f.test_long;
set titleds.match_trans_mort_matchlong (obs=500);
run;
data f.test_wide;
set titleds.match_trans_mort_matchwide_all (obs=500);
run;
%mend test0_1;

/* Step 1.1: Input & Fomat GSE data
1. import file;
2. change var names for different years in a same format;
3. pick out useful vars */
%macro step1_1(yr);
%put ~~~~~ Step 1.1: Input & Fomat GSE data ~~~~~;
%if &yr = 2012 %then %do;
data f.tmp1_1;
set gseds.fannie_acquisition&yr.;
date 			=	put(Orig_date, yymmn6.);
seller 			=	SELLER;
loan_term		=	ORIG_TERM;
ltv				=	OLTV;
mort_amt	=	ORIG_AMT;
loan_purpose	=	LOAN_PURPOSE;
prop_type		=	PROP_TYPE;
zip				=	ZIP_3;
state			=	STATE;
%end;
%if &yr = 2014 %then %do;
data f.tmp1_1;
set gseds.fannie_acquisition&yr.;
date 			=	scan(trim(Orig_date),2)*100+scan(trim(Orig_date),1)*1;
seller 			=	seller_name;
loan_term		=	orig_loan_term;
ltv				=	ltv;
mort_amt	=	orig_upb;
loan_purpose	=	loan_purpose;
prop_type		=	prop_type;
zip				=	zipcode;
state			=	st;
%end;
keep date seller loan_term ltv mort_amt loan_purpose prop_type zip state;
run;
%mend step1_1;

/* Step 1.2: Filter out Cook county & Single-family & Purchased obs */
%macro step1_2();
%put ~~~~~ Step 1.2: Filter out Cook county & Single-family & Purchased obs ~~~~~;
PROC SQL;
	CREATE TABLE F.tmp1_2 AS 
		SELECT t.PROP_TYPE, 
		t.SELLER, 
		t.LOAN_PURPOSE, 
		t.DATE, 
		t.LOAN_TERM, 
		t.LTV, 
		t.MORT_AMT,
		t.ZIP
	FROM F.tmp1_1 t
	WHERE UPPER(t.STATE) = 'IL'
		AND UPPER(t.PROP_TYPE) = 'SF'
		AND UPPER(t.LOAN_PURPOSE) = 'P';
QUIT;
%mend step1_2;

/* Step 1.3: Filter out certain year and quater obs */
%macro step1_3(yr, qt);
%put ~~~~~ Step 1.3: Filter out certain year and quater obs ~~~~~;
data 	f.tmp1_3;
set 	f.tmp1_2;
prop_type 	= upcase(prop_type);
year 		= int(date / 100);
month 		= mod(date, 100);
if year = &yr.;
if (month <= &qt.*3 and month > &qt.*3-3);
*drop year month;
run;
%mend step1_3;

/* Step 1.4: Turn out transaction amount
1. Remove no value mortgage or LTV
2. Add Transaction Amount = Mortgage Amount / LTV */
%macro step1_4();
%put ~~~~~ Step 1.4: Turn out transaction amount ~~~~~;
data 	f.tmp1_4;
set 	f.tmp1_3;
if mort_amt ^= 0 and mort_amt ^= .;
if ltv ^= 0 and ltv ^= .;
trans_amt 	= ceil(mort_amt / ltv * 100);
run;
%mend step1_4;


/********************************************************/
/* Step 2: Filter Title dataset (mortgage + transaction)*/
%macro filter_mort(yr, qt);
%put ~~~~~ Step 2: Filter Title dataset (mortgage + transaction) ~~~~~;
*%step2_0();
%step2_1();
%step2_2(&yr, &qt);
%step2_3(&yr, &qt);
%step2_4();
%step2_5();
%mend filter_mort;

/* Step 2.0: Output a part of title data as a test set */
%macro step2_0();
%put ~~~~~ Step 2.0: Output a part of title data as a test set ~~~~~;
data f.test_long;
set titleds.match_trans_mort_matchlong (obs = 50);
run;
data f.test_wide;
set titleds.match_trans_mort_matchwide_all (obs = 50);
run;
%mend step2_0;

/* Step 2.1: Input & Fomat TITLE data
1. import file;
2. change var names for different years in a same format;
3. pick out useful vars, drop others, reduce the file size.*/
%macro step2_1();
%put ~~~~~ Step 2.1: Input & Fomat TITLE data ~~~~~;
data f.tmp2_1;
set titleds.match_trans_mort_matchwide_all;
FORMAT pin z14.;
date 			=	date_doc_m1;
mort_amt		=	amount_m1;
trans_amt 		=	amount_prime;
pin				=	pin1;
keep date mort_amt trans_amt pin;
run;
%mend step2_1;

/* Step 2.2: Filter out certain data
1. target year and quater obs 
2. mortgage or transaction amount is not null*/
%macro step2_2(yr, qt);
%put ~~~~~ Step 2.2: Filter out certain data ~~~~~;
data f.tmp2_2;
set f.tmp2_1(rename=(date=date1));
if mort_amt ^= . and mort_amt ^= 0;
if trans_amt ^= . and trans_amt ^= 0;
year 	= year(date1);
month	= month(date1);
date 	= put(date1, yymmn6.);
drop date1;
if year = &yr.;
if (month <= &qt.*3 and month > &qt.*3-3);
run;
%mend step2_2;

/* Step 2.3: Filter out lender names
1. reduce the scrop of obs by date
2. remove empty or blank leader name
3. remove other useless varibles */
%macro step2_3(yr, qt);
%put ~~~~~ Step 2.3: Filter out lender names ~~~~~;
data f.tmp2_3;
set titleds.match_trans_mort_matchlong;
FORMAT pin z14.;
date1 	= date_doc;
date 	= put(date1, yymmn6.);
pin 	= pin1;
year 	= year(date1);
month	= month(date1); 
if year = &yr.;
if (month <= &qt.*3 and month > &qt.*3-3);
if length(lender1) > 1;
keep date pin year month lender1 lender2 lender3;
run;
%mend step2_3;

/* Step 2.4: Add lender names into dataset*/
%macro step2_4();
%put ~~~~~ Step 2.4: Add lender names into dataset ~~~~~;
PROC SQL;
	CREATE TABLE F.tmp2_4 AS 
		SELECT DISTINCT
			wide.date AS DATE,
			wide.mort_amt AS MORT_AMT,
			wide.trans_amt AS TRANS_AMT,
			wide.pin AS PIN,
			long.lender1 AS LENDER1,
			long.lender2 AS LENDER2,
			long.lender3 AS LENDER3,
			wide.year AS YEAR,
			wide.month AS MONTH
	FROM F.tmp2_2 wide
		LEFT JOIN F.tmp2_3 long
		ON wide.pin = long.pin
		AND wide.year = long.year
		AND wide.month = long.month
	ORDER BY YEAR, MONTH, MORT_AMT;
QUIT;
%mend step2_4;

/* Step 2.5: test step2_4*/
%macro step2_5();
%put ~~~~~ Step 2.5: test step2_4 ~~~~~;
PROC SQL;
	CREATE TABLE F.tmp2_5 AS 
		SELECT t.PIN AS PIN,
			COUNT(t.PIN) AS COUNT
	FROM F.tmp2_4 t
	GROUP BY t.PIN
	ORDER BY COUNT;
QUIT;
%mend step2_5;

/***********************************/
/* Step 3: Match GSE and TITLE data */
%macro match();
%put ~~~~~ Step 3: Match GSE and TITLE data ~~~~~;
%step3_1();
%mend match;

/* Step 3.1: Match based on 
1. mortgage amount
2. transaction amount
3. month and year */
%macro step3_1();
%put ~~~~~ Step 3.1: Matching ~~~~~;
PROC SQL;
	CREATE TABLE F.tmp3_1 AS 
		SELECT DISTINCT
			t.pin AS PIN,
			g.mort_amt AS G_MORT_AMT,
			t.mort_amt AS T_MORT_AMT,
			g.trans_amt AS G_TRANS_AMT,
			t.trans_amt AS T_TRANS_AMT,
			ABS(g.trans_amt - t.trans_amt) AS DIFF,
			(ABS(g.trans_amt - t.trans_amt))/g.trans_amt AS RATE,
			g.seller AS G_SELLER,
			t.lender1 AS T_LENDER1,
			t.lender2 AS T_LENDER2,
			t.lender3 AS T_LENDER3,
			g.year AS YEAR,
			g.month AS MONTH
	FROM F.tmp1_4 g
		INNER JOIN F.tmp2_4 t
		ON g.mort_amt = t.mort_amt
		AND (ABS(g.trans_amt - t.trans_amt))/g.trans_amt < &alpha.
		AND g.year = t.year
		AND g.month = t.month;
QUIT;
%mend step3_1;

/***********************************/
/* Step 4: Show matching result */
%macro result();
%put ~~~~~ Step 4: Show matching result ~~~~~;
%step4_1();
%mend result;

/* Step 4.1: Matching Result */
%macro step4_1();
%put ~~~~~ Step 4.1: Matching Result ~~~~~;
data _NULL_;
set f.tmp1_4;
call symput("gno", strip(_N_));
run;
data _NULL_;
set f.tmp2_5;
call symput("tno", strip(_N_));
run;
data _NULL_;
set f.tmp3_1;
call symput("mno", strip(_N_));
run;
%put ~~~~~~~ GSE input Obs number: &gno. ~~~~~;
%put ~~~~~ TITLE input Obs number: &tno. ~~~~~;
%put ~~~~ match output Obs number: &tno. ~~~~~;
%mend step4_1;


/* Run main()*/
%main();
