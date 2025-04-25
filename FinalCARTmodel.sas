/*  Import the dataset */

FILENAME REFFILE '/home/u64128357/Final Project/tour_package.csv';

PROC IMPORT DATAFILE=REFFILE
    DBMS=CSV
    OUT=WORK.tour_packageOriginal
    REPLACE;
    GETNAMES=YES;
RUN;
PROC CONTENTS DATA=WORK.tour_packageOriginal; 
RUN;
/* First few Observations */

PROC PRINT DATA=WORK.tour_packageOriginal (OBS=10);
RUN;

/********* Check Missing Values ********/

PROC MEANS DATA=WORK.tour_packageOriginal NMISS N; /* PROC MEANS with the NMISS option only counts missing values for numerical variables. */
RUN;
/******** Handling Missing Data ********/
/* Calculate the median for numerical variables */

proc univariate data=WORK.tour_packageOriginal noprint;
    var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
    NumberOfTrips NumberOfChildrenVisiting MonthlyIncome;
    output out=median_values 
        median=median_Age median_Duration median_Followups 
        median_PropertyStar median_Trips median_ChildrenVisiting median_Income;
run;
/* Replace missing values with the calculated median */

data WORK.tour_package;
    set WORK.tour_packageOriginal;
    if _N_ = 1 then set median_values; /* Read in calculated median values */

    /* Replace missing values */
    if Age = . then Age = median_Age;
    if DurationOfPitch = . then DurationOfPitch = median_Duration;
    if NumberOfFollowups = . then NumberOfFollowups = median_Followups;
    if PreferredPropertyStar = . then PreferredPropertyStar = median_PropertyStar;
    if NumberOfTrips = . then NumberOfTrips = median_Trips;
    if NumberOfChildrenVisiting = . then NumberOfChildrenVisiting = median_ChildrenVisiting;
    if MonthlyIncome = . then MonthlyIncome = median_Income;
    /* Drop unnecessary median columns */
    drop median_Age median_Duration median_Followups median_PropertyStar 
    median_Trips median_ChildrenVisiting median_Income;
run;

PROC MEANS DATA=WORK.tour_package NMISS N; /* PROC MEANS with the NMISS option only counts missing values for numerical variables. */
RUN;

/* View the resulting dataset */
/*proc print data=WORK.tour_package;
run;*/


/* Running descriptive statistics */

proc means data=WORK.tour_package chartype mean std min max n vardef=df ;
	var  Age CityTier CustomerID DurationOfPitch MonthlyIncome NumberOfChildrenVisiting
	NumberOfFollowups NumberOfPersonVisiting NumberOfTrips OwnCar Passport 
	PitchSatisfactionScore PreferredPropertyStar ProdTaken;
run;

PROC FREQ DATA=WORK.tour_package;
    TABLES  Designation Gender MaritalStatus Occupation TypeofContact ProductPitched / NOCUM NOPERCENT;
RUN;
/* Bar charts for categorical variables */

proc sgplot data=WORK.tour_package;
   vbar Designation;
   title "Customer Designation Distribution";
run;

proc sgplot data=WORK.tour_package;
   vbar ProductPitched;
   title "Distribution of Products Pitched";
run;

proc sgplot data=WORK.tour_package;
   vbar Gender;
   title "Customer Gender ";
run;

proc sgplot data=WORK.tour_package;
   vbar MaritalStatus;
   title "Customer MaritalStatus";
run; 

proc sgplot data=WORK.tour_package;
   vbar Occupation;
   title "Customer Occupation Distribution";
run;
proc sgplot data=WORK.tour_package;
   vbar ProductPitched;
   title "Product Pitched ";
run;
/* Boxplots for numeric variables vs ProdTaken */

proc sgplot data=WORK.tour_package;
   vbox Age / category=ProdTaken;
   title "Boxplot of Age by Tour Purchase (ProdTaken)";
run;

proc sgplot data=WORK.tour_package;
   vbox MonthlyIncome / category=ProdTaken;
   title "Monthly Income by Tour Purchase";
run;

proc sgplot data=WORK.tour_package;
   vbox PitchSatisfactionScore / category=ProdTaken;
   title "Pitch Satisfaction vs Tour Purchase";
run;
proc sgplot data=WORK.tour_package;
   vbox Passport / category=ProdTaken;
   title "Boxplot of Passport by Tour Purchase (ProdTaken)";
run;

proc sgplot data=WORK.tour_package;
   vbox DurationOfPitch / category=ProdTaken;
   title "DurationOfPitch by Tour Purchase";
run;

proc sgplot data=WORK.tour_package;
   vbox PreferredPropertyStar / category=ProdTaken;
   title "PreferredPropertyStar vs Tour Purchase";
run;

/*** Creating binary dummy variables ***/
/***************************************/
data WORK.tour_package1;
	set WORK.tour_package;
	
	if Designation='AVP' then Designation_AVP=1; else Designation_AVP=0;
	if Designation='Executive' then Designation_Executive=1; else Designation_Executive=0;
	if Designation='Manager' then Designation_Manager=1; else Designation_Manager=0;
	if Designation='SeniorManager' then Designation_SeniorManager=1; else Designation_SeniorManager=0;
	if Designation='VP' then Designation_VP=1; else Designation_VP=0;
	
	if Gender='Female' then Gender_Female=1; else Gender_Female=0;
	if Gender='Male' then Gender_Male=1; else Gender_Male=0;
	
	if MaritalStatus='Divorced' then MaritalStatus_Divorced=1; else MaritalStatus_Divorced=0;
	if MaritalStatus='Married' then MaritalStatus_Married=1; else MaritalStatus_Married=0;
	if MaritalStatus='Single' then MaritalStatus_Single=1; else MaritalStatus_Single=0;
	if MaritalStatus='Unmarried' then MaritalStatus_Unmarried=1; else MaritalStatus_Unmarried=0;
	
	if Occupation='Large Business' then Occupation_Large_Business=1; else Occupation_Large_Business=0;
	if Occupation='Salaried' then Occupation_Salaried=1; else Occupation_Salaried=0;
	if Occupation='Small Business' then Occupation_Small_Business=1; else Occupation_Small_Business=0;
	
	if TypeofContact='Company Invited' then TypeofContact_Company_Invited=1; else TypeofContact_Company_Invited=0;
    if TypeofContact='Self Enquiry' then TypeofContact_Self_Enquiry=1; else TypeofContact_Self_Enquiry=0;
    
    if ProductPitched='Basic' then ProductPitched_Basic =1; else ProductPitched_Basic =0;
    if ProductPitched='Deluxe' then ProductPitched_Deluxe =1; else ProductPitched_Deluxe =0;
    if ProductPitched='King' then ProductPitched_King =1; else ProductPitched_King =0;
    if ProductPitched='Standard' then ProductPitched_Standard =1; else ProductPitched_Standard =0;
    if ProductPitched='Super Deluxe' then ProductPitched_SuperDeluxe =1; else ProductPitched_SuperDeluxe =0;
	
	drop Designation Gender MaritalStatus Occupation ProductPitched TypeofContact; 
run;
/******************************************/
/***** Tuning a Classification Tree ****/
/******************************************/
/* Partition the data (60:40)*/
proc surveyselect data=WORK.tour_package1 outall
    out=WORK.tour_partitioned seed=12345
    samprate=0.6
    method=srs;
run;

data WORK.tour_train WORK.tour_test;
    set WORK.tour_partitioned;
    if selected then output WORK.tour_train;
    else output WORK.tour_test;
run;
/* Running a tree with cross-validation and pruning using gini */

proc hpsplit data=WORK.tour_train Maxdepth=30 SEED=0
             CVMETHOD=RANDOM(5) CVCOSTCOMPLEXITY CVMODELFIT;
   class ProdTaken;
   model ProdTaken = Age CityTier DurationOfPitch MonthlyIncome NumberOfChildrenVisiting
       NumberOfFollowups NumberOfPersonVisiting NumberOfTrips OwnCar Passport 
       PitchSatisfactionScore PreferredPropertyStar 
       Designation_AVP Designation_Executive Designation_Manager Designation_SeniorManager Designation_VP
       Gender_Female Gender_Male
       MaritalStatus_Divorced MaritalStatus_Married MaritalStatus_Single MaritalStatus_Unmarried
       Occupation_Large_Business Occupation_Salaried Occupation_Small_Business
       TypeofContact_Company_Invited TypeofContact_Self_Enquiry
       ProductPitched_Basic ProductPitched_Deluxe ProductPitched_King 
       ProductPitched_Standard ProductPitched_SuperDeluxe;
   grow gini;  
   prune costcomplexity;
   code file="/home/u64128357/Final Project/score_cart_cv.sas"; 
   output out=pred_cv;
run;

/* Testing/scoring the CV classification tree model */
data scored_test;
    set WORK.tour_test;
    %include "/home/u64128357/Final Project/score_cart_cv.sas";
run;

/* Performance Evaluation */
/* Data preparation */
data scored_test;
	set scored_test;
	if P_ProdTaken0 >= 0.5 then P_ProdTaken = 0;
	else P_ProdTaken = 1;
run;

/* Confusion matrix */
proc freq data=scored_test;
   tables ProdTaken*P_ProdTaken / norow nocol nopercent;
   title "Confusion Matrix-Gini";
run;

/* Calculate accuracy, sensitivity, specificity and other metrics */
proc sql;
   create table perf_metrics as
   select 
      sum(case when ProdTaken=1 and P_ProdTaken=1 then 1 else 0 end) as TP,
      sum(case when ProdTaken=0 and P_ProdTaken=0 then 1 else 0 end) as TN,
      sum(case when ProdTaken=0 and P_ProdTaken=1 then 1 else 0 end) as FP,
      sum(case when ProdTaken=1 and P_ProdTaken=0 then 1 else 0 end) as FN
   from scored_test;

   select 
      (TP+TN)/(TP+TN+FP+FN) as Accuracy,
      TP/(TP+FN) as Sensitivity,
      TN/(TN+FP) as Specificity,
      TP/(TP+FP) as Precision,
      2 * ((TP / (TP + FP)) * (TP / (TP + FN))) / ((TP / (TP + FP)) + (TP / (TP + FN))) as F1_Score
   from perf_metrics;
quit;
/*  ROC Curve and AUC */
proc logistic data=scored_test;
   model ProdTaken(event='1') = P_ProdTaken1;
   roc;
   roccontrast;
   title "ROC Curve and AUC for CART with CV";
run;

/* Running a tree with cross-validation and pruning using entropy */
proc hpsplit data=WORK.tour_train Maxdepth=30 SEED=0
             CVMETHOD=RANDOM(5) CVCOSTCOMPLEXITY CVMODELFIT;
   class ProdTaken;
   model ProdTaken = Age CityTier DurationOfPitch MonthlyIncome NumberOfChildrenVisiting
       NumberOfFollowups NumberOfPersonVisiting NumberOfTrips OwnCar Passport 
       PitchSatisfactionScore PreferredPropertyStar 
       Designation_AVP Designation_Executive Designation_Manager Designation_SeniorManager Designation_VP
       Gender_Female Gender_Male
       MaritalStatus_Divorced MaritalStatus_Married MaritalStatus_Single MaritalStatus_Unmarried
       Occupation_Large_Business Occupation_Salaried Occupation_Small_Business
       TypeofContact_Company_Invited TypeofContact_Self_Enquiry
       ProductPitched_Basic ProductPitched_Deluxe ProductPitched_King 
       ProductPitched_Standard ProductPitched_SuperDeluxe;
   grow entropy;
   prune costcomplexity;
   code file="/home/u64128357/Final Project/score_cart_entropy_cv.sas"; 
   output out=pred_cv_entropy;
run;

/* Testing/scoring the CV classification tree model */
data scored_test_entropy;
    set WORK.tour_test;
    %include "/home/u64128357/Final Project/score_cart_entropy_cv.sas";
run;


/* Performance Evaluation */
/* Data preparation */
data scored_test_entropy;
	set scored_test_entropy;
	if P_ProdTaken0 >= 0.5 then P_ProdTaken = 0;
	else P_ProdTaken = 1;
run;

/* Confusion matrix */
proc freq data=scored_test_entropy;
   tables ProdTaken*P_ProdTaken / norow nocol nopercent;
   title "Confusion Matrix - Entropy";
run;

/* Calculate accuracy, sensitivity, specificity and other metrics */
proc sql;
   create table perf_metrics_entropy as
   select 
      sum(case when ProdTaken=1 and P_ProdTaken=1 then 1 else 0 end) as TP,
      sum(case when ProdTaken=0 and P_ProdTaken=0 then 1 else 0 end) as TN,
      sum(case when ProdTaken=0 and P_ProdTaken=1 then 1 else 0 end) as FP,
      sum(case when ProdTaken=1 and P_ProdTaken=0 then 1 else 0 end) as FN
   from scored_test_entropy;

   select 
      (TP+TN)/(TP+TN+FP+FN) as Accuracy,
      TP/(TP+FN) as Sensitivity,
      TN/(TN+FP) as Specificity,
      TP/(TP+FP) as Precision,
      2 * ((TP / (TP + FP)) * (TP / (TP + FN))) / ((TP / (TP + FP)) + (TP / (TP + FN))) as F1_Score
   from perf_metrics_entropy;
quit;
/* ROC Curve and AUC */
proc logistic data=scored_test_entropy;
   model ProdTaken(event='1') = P_ProdTaken1;
   roc;
   roccontrast;
   title "ROC Curve and AUC for CART with Entropy";
run;



