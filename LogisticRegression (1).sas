/*  Import the dataset */

FILENAME REFFILE '/home/u64117933/MIS 4560/GroupProject/tour_package.csv';

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
proc print data=WORK.tour_package;
run;


/* Running descriptive statistics */

proc means data=WORK.tour_package chartype mean std min max n vardef=df ;
	var  Age CityTier CustomerID DurationOfPitch MonthlyIncome NumberOfChildrenVisiting
	NumberOfFollowups NumberOfPersonVisiting NumberOfTrips OwnCar Passport 
	PitchSatisfactionScore PreferredPropertyStar ProdTaken;
run;

PROC FREQ DATA=WORK.tour_package;
    TABLES  Designation Gender MaritalStatus Occupation TypeofContact ProductPitched / NOCUM NOPERCENT;
RUN;

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

/***************************************/
/****** Logistic Regression ******/
/***************************************/

/**** Step 1 Data Partitioning (60/40 split) *****/
proc surveyselect data=WORK.tour_package1 outall
    out=WORK.tour_package_partitioned seed=12345
    samprate=0.6
    method=srs;
run;

data WORK.tour_package_train WORK.tour_package_valid;
    set WORK.tour_package_partitioned;
    if selected then output WORK.tour_package_train;
    else output WORK.tour_package_valid;
run;

/***** Step 2 Logistic FULL Regression Model ******/
proc logistic data=WORK.tour_package_train outmodel=WORK.tour_model;
    model ProdTaken(event='1') = 
        Age DurationOfPitch NumberOfFollowups PreferredPropertyStar NumberOfTrips 
        Passport OwnCar NumberOfChildrenVisiting MonthlyIncome PitchSatisfactionScore 
        Designation_AVP Designation_Executive Designation_Manager Designation_SeniorManager Designation_VP
        Gender_Female Gender_Male
        MaritalStatus_Divorced MaritalStatus_Married MaritalStatus_Single MaritalStatus_Unmarried
        Occupation_Large_Business Occupation_Salaried Occupation_Small_Business
        TypeofContact_Company_Invited TypeofContact_Self_Enquiry
        ProductPitched_Basic ProductPitched_Deluxe ProductPitched_King ProductPitched_Standard ProductPitched_SuperDeluxe
        / selection=none;
    output out=pred_train_full p=probabilities;
    ods output FitStatistics=fitstats_full;
run;

proc print data=fitstats_full;
    title 'Fit Statistics – Full Model';
run;


/***** Step 3 Scoring the FULL Model Validation Set & Confusion Matrix ******/
proc logistic inmodel=WORK.tour_model;
    score data=WORK.tour_package_valid out=pred_valid_full;
run;

data pred_valid_full;
    set pred_valid_full;
    if P_1 >= 0.5 then predicted_full = 1;
    else predicted_full = 0;
run;

/*Confusion Matrix*/
proc freq data=pred_valid_full;
    tables ProdTaken*predicted_full / nopercent norow nocol;
    title 'Confusion Matrix – Full Model';
run;

/********** Step 4 Accuracy Metrics for FULL model **********/

proc sql;
    select 
        sum(case when ProdTaken = predicted_full then 1 else 0 end) / count(*) as Accuracy label='Accuracy',
        sum(case when ProdTaken = 1 and predicted_full = 1 then 1 else 0 end) / 
        sum(case when ProdTaken = 1 then 1 else 0 end) as Sensitivity label='Sensitivity (True Positive Rate)',
        sum(case when ProdTaken = 0 and predicted_full = 0 then 1 else 0 end) / 
        sum(case when ProdTaken = 0 then 1 else 0 end) as Specificity label='Specificity (True Negative Rate)'
    from pred_valid_full;
quit;

/****** 5 Gain Chart – Full Model ******/
proc logistic data=WORK.tour_package_train plots(only)=(roc(id=prob));
    model ProdTaken(event='1') = 
        Age DurationOfPitch NumberOfFollowups PreferredPropertyStar NumberOfTrips 
        Passport OwnCar NumberOfChildrenVisiting MonthlyIncome PitchSatisfactionScore 
        Designation_AVP Designation_Executive Designation_Manager Designation_SeniorManager Designation_VP
        Gender_Female Gender_Male
        MaritalStatus_Divorced MaritalStatus_Married MaritalStatus_Single MaritalStatus_Unmarried
        Occupation_Large_Business Occupation_Salaried Occupation_Small_Business
        TypeofContact_Company_Invited TypeofContact_Self_Enquiry
        ProductPitched_Basic ProductPitched_Deluxe ProductPitched_King ProductPitched_Standard ProductPitched_SuperDeluxe;
    score data=WORK.tour_package_valid out=pred_valid_gain_full;
run;

/****** 6 Lift Chart ******/
%include '/home/u64117933/MIS 4560/GroupProject/gainlift macro.sas';

%GainLift(
    data = pred_valid_gain_full, 
    response = ProdTaken, 
    p = P_1, 
    event = '1', 
    groups = 10, 
    plots = clift, 
    graphopts = grid nobest);

/*** Running this code will produce a "WARNING: Quasi-complete separation detected in the [full] model."
To explain briefly, this happens when one or more variables almost perfectly predict the outcome, 
which can lead to unstable estimates and overfitting. To avoid this and improve the model’s reliability, 
I created a new logistic model using stepwise selection.***/ 

/*****************************************************************************/
/***** Step 2B Logistic STEPWISE Regression Model ******/
proc logistic data=WORK.tour_package_train outmodel=WORK.tour_model_stepwise;
    model ProdTaken(event='1') = 
        Age DurationOfPitch NumberOfFollowups PreferredPropertyStar NumberOfTrips 
        Passport OwnCar NumberOfChildrenVisiting MonthlyIncome PitchSatisfactionScore 
        Designation_AVP Designation_Executive Designation_Manager Designation_SeniorManager Designation_VP
        Gender_Female Gender_Male
        MaritalStatus_Divorced MaritalStatus_Married MaritalStatus_Single MaritalStatus_Unmarried
        Occupation_Large_Business Occupation_Salaried Occupation_Small_Business
        TypeofContact_Company_Invited TypeofContact_Self_Enquiry
        ProductPitched_Basic ProductPitched_Deluxe ProductPitched_King ProductPitched_Standard ProductPitched_SuperDeluxe
        / selection=stepwise slentry=0.05 slstay=0.05;
    output out=pred_train_stepwise p=probabilities;
    ods output FitStatistics=fitstats_stepwise;
run;

proc print data=fitstats_stepwise;
    title 'Fit Statistics – Stepwise Model';
run;


/* Step 3B Scoring the STEPWISE Model Validation Set & Confusion Matrix **********/
proc logistic inmodel=WORK.tour_model_stepwise;
    score data=WORK.tour_package_valid out=pred_valid_stepwise;
run;

data pred_valid_stepwise;
    set pred_valid_stepwise;
    if P_1 >= 0.5 then predicted_stepwise = 1;
    else predicted_stepwise = 0;
run;

/*Confusion Matrix*/
proc freq data=pred_valid_stepwise;
    tables ProdTaken*predicted_stepwise / nopercent norow nocol;
    title 'Confusion Matrix – Stepwise Model';
run;

/****** Step 4B Accuracy Metrics for STEPWISE model *******/
proc sql;
    select 
        sum(case when ProdTaken = predicted_stepwise then 1 else 0 end) / count(*) as Accuracy label='Accuracy',
        sum(case when ProdTaken = 1 and predicted_stepwise = 1 then 1 else 0 end) / 
        sum(case when ProdTaken = 1 then 1 else 0 end) as Sensitivity label='Sensitivity (True Positive Rate)',
        sum(case when ProdTaken = 0 and predicted_stepwise = 0 then 1 else 0 end) / 
        sum(case when ProdTaken = 0 then 1 else 0 end) as Specificity label='Specificity (True Negative Rate)'
    from pred_valid_stepwise;
quit;

/****** 5B Gain Chart – Stepwise Model ******/
proc logistic data=WORK.tour_package_train plots(only)=(roc(id=prob));
    model ProdTaken(event='1') = 
        Age DurationOfPitch NumberOfFollowups PreferredPropertyStar NumberOfTrips 
        Passport NumberOfChildrenVisiting PitchSatisfactionScore 
        Designation_AVP Designation_Executive 
        Gender_Male 
        MaritalStatus_Single MaritalStatus_Unmarried 
        Occupation_Large_Business 
        TypeofContact_Company_Invited 
        ProductPitched_Standard;
    score data=WORK.tour_package_valid out=pred_valid_gain_stepwise;
run;

/****** 6B Lift Chart ******/
%include '/home/u64117933/MIS 4560/GroupProject/gainlift macro.sas';

%GainLift(
    data = pred_valid_gain_stepwise, 
    response = ProdTaken, 
    p = P_1, 
    event = '1', 
    groups = 10, 
    plots = clift, 
    graphopts = grid nobest);