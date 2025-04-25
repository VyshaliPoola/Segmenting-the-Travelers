/*  Import the dataset */

FILENAME REFFILE '/home/u63336885/sasuser.v94/Intro To Data Science/Final Project/tour_package.csv';

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
/****** Neural Network ******/
/***************************************/


/********** 01. Partition Data: 60% Train, 40% Validate **********/
proc surveyselect data=WORK.tour_package1 out=WORK.tour_package_partitioned
    method=srs samprate=0.6 seed=12345 outall;
run;

data tour_train tour_valid;
    set WORK.tour_package_partitioned;
    if selected then output tour_train;
    else output tour_valid;
run;

/********** 02. Standardize Numerical Variables **********/
proc stdize data=tour_train out=tour_train_std method=range;
    var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
        NumberOfTrips NumberOfChildrenVisiting MonthlyIncome;
run;

proc stdize data=tour_valid out=tour_valid_std method=range;
    var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
        NumberOfTrips NumberOfChildrenVisiting MonthlyIncome;
run;

/********** 03. Train Neural Network Model **********/
proc hpneural data=tour_train_std;
    input 
        Designation_AVP Designation_Executive Designation_Manager Designation_SeniorManager Designation_VP
        Gender_Female Gender_Male
        MaritalStatus_Divorced MaritalStatus_Married MaritalStatus_Single MaritalStatus_Unmarried
        Occupation_Large_Business Occupation_Salaried Occupation_Small_Business
        TypeofContact_Company_Invited TypeofContact_Self_Enquiry
        ProductPitched_Basic ProductPitched_Deluxe ProductPitched_King ProductPitched_Standard ProductPitched_SuperDeluxe
    / level=nominal;

    input Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
          NumberOfTrips NumberOfChildrenVisiting MonthlyIncome
    / level=interval;

    target ProdTaken / level=nominal;

    hidden 5;
    hidden 3;
    train;
    score out=WORK.nn_scored;
    performance details;
    code file="%sysfunc(getoption(work))/score_nn_tour_package.sas";
run;

/********** 04. Score the Validation Data **********/
data tour_valid_scored;
    set tour_valid_std;
    %include "%sysfunc(getoption(work))/score_nn_tour_package.sas";
run;

/********** 05. Confusion Matrix **********/
data tour_valid_scored;
    set tour_valid_scored;
    if P_ProdTaken1 >= 0.5 then Prediction = 1;
    else Prediction = 0;
run;

proc freq data=tour_valid_scored;
    tables ProdTaken*Prediction / norow nocol nopercent;
    title "Confusion Matrix - Neural Network (Tourism)";
run;

/* Optional: ROC Curve */
PROC LOGISTIC DATA=WORK.tour_valid_scored;
    MODEL ProdTaken(event='1') = P_ProdTaken1 / nofit;
    SCORE DATA=WORK.tour_valid_scored OUT=Scored_Valid;
    ROC 'NN Prediction' P_ProdTaken1;
    ROCCONTRAST;
RUN;

