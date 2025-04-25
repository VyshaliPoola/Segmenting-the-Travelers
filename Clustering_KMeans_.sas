/****************************************/
/*** STEP 1: Import and Handle Missing Values ***/
/****************************************/

FILENAME REFFILE '/home/u64117933/MIS 4560/GroupProject/tour_package.csv';

PROC IMPORT DATAFILE=REFFILE
    DBMS=CSV
    OUT=WORK.tour_packageOriginal
    REPLACE;
    GETNAMES=YES;
RUN;

/* Impute missing numeric values using medians */
proc univariate data=WORK.tour_packageOriginal noprint;
    var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
        NumberOfTrips NumberOfChildrenVisiting MonthlyIncome;
    output out=median_values 
        median=median_Age median_Duration median_Followups 
        median_PropertyStar median_Trips median_ChildrenVisiting median_Income;
run;

data tour_package;
    set tour_packageOriginal;
    if _N_ = 1 then set median_values;

    if Age = . then Age = median_Age;
    if DurationOfPitch = . then DurationOfPitch = median_Duration;
    if NumberOfFollowups = . then NumberOfFollowups = median_Followups;
    if PreferredPropertyStar = . then PreferredPropertyStar = median_PropertyStar;
    if NumberOfTrips = . then NumberOfTrips = median_Trips;
    if NumberOfChildrenVisiting = . then NumberOfChildrenVisiting = median_ChildrenVisiting;
    if MonthlyIncome = . then MonthlyIncome = median_Income;

    drop median_:;
run;

/****************************************/
/*** STEP 2: Standardize & Compute Distance Matrix ***/
/****************************************/
/* Step 2A: Drop ID to avoid skew */
data tour_package_model;
    set tour_package;
    drop CustomerID;
run;

/* Step 2B: Standardize all numeric variables */
proc standard data=WORK.tour_package_model out=WORK.tour_package_std mean=0 std=1;
   var _numeric_;
run;

/* Step 2C: Calculate pairwise Euclidean distances */
proc distance data=WORK.tour_package_std out=dist_matrix method=euclid;
   var interval(_numeric_);
run;

proc print data=dist_matrix (obs=10);
run;

/****************************************/
/***** STEP 3: Hierarchical Clustering *****/
/****************************************/

proc cluster data=WORK.tour_package_std method=average outtree=tree_output 
            print=15 ccc pseudo; 
   var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
       NumberOfTrips Passport PitchSatisfactionScore OwnCar 
       NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting; 
   /* the variables to be used in the clustering */
run;

/* Create clusters */
proc tree data=tree_output out=clusters_hier nclusters=10;
run;

/* View cluster membership */
proc sort data=clusters_hier;
   by cluster;
run;

proc print data=clusters_hier (obs=4888);
   var cluster _NAME_;
   title 'Customers in Each Cluster (Hierarchical)';
run;

/****************************************/
/*** STEP 4: K-Means Clustering *********/
/****************************************/

/* Run k-means clustering */
proc fastclus data=WORK.tour_package_std 
              out=clustered 
              maxclusters=10 
              maxiter=100 
              mean=centroids 
              outstat=stats; 
   var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
       NumberOfTrips Passport PitchSatisfactionScore OwnCar 
       NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting;
run;

/* View cluster assignments */
proc sort data=clustered;
   by cluster;
run;

proc print data=clustered (obs=4888);
   var cluster;
   title 'Customers in Each Cluster (K-Means)';
run;


/****************************************/
/*** STEP 5: Cluster Centroid Profile Chart ***/
/****************************************/

/* Transpose centroids data so each row is a variable and each column is a cluster */
proc transpose data=centroids out=centroids_t name=variable;
   var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
       NumberOfTrips Passport PitchSatisfactionScore OwnCar 
       NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting;
   id cluster;
run;

/* Plot the cluster profiles */
proc sgplot data=centroids_t;
   series x=variable y='1'n / lineattrs=(color=blue thickness=2);
   series x=variable y='2'n / lineattrs=(color=red thickness=2);
   series x=variable y='3'n / lineattrs=(color=green thickness=2);
   series x=variable y='4'n / lineattrs=(color=black thickness=2);
   series x=variable y='5'n / lineattrs=(color=orange thickness=2);
   series x=variable y='6'n / lineattrs=(color=purple thickness=2);
   series x=variable y='7'n / lineattrs=(color=gray thickness=2);
   series x=variable y='8'n / lineattrs=(color=magenta thickness=2);
   series x=variable y='9'n / lineattrs=(color=olive thickness=2);
   series x=variable y='10'n / lineattrs=(color=cyan thickness=2);
   xaxis label="Variables";
   yaxis label="Centroid Values";
   title "Cluster Centroid Profiles";
run;

/****************************************/
/*** STEP 6: Within-Cluster Sum of Squares ***/
/****************************************/

proc sql;
   create table cluster_summary as
   select clustered.cluster, 
          count(*) as count,
          sum(distance*distance) as within_cluster_ss
   from clustered
   group by cluster
   order by cluster;
quit;

proc print data=cluster_summary;
   format within_cluster_ss 10.2;
   title "Within-Cluster Sum of Squared Distances";
run;

/****************************************/
/*** STEP 7: Between-Cluster Centroid Distances ***/
/****************************************/

/* Add a character label to each cluster */
data centroids_char;
   set centroids;
   cluster_char = put(cluster, 8.);
run;

/* Compute pairwise Euclidean distances between centroids */
proc distance data=centroids_char method=euclid out=centroid_distances;
	var interval(Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
                 NumberOfTrips Passport PitchSatisfactionScore OwnCar 
                 NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting);
	id cluster_char;
run;

proc print data=centroid_distances;
   title "Pairwise Euclidean Distances Between Cluster Centroids";
run;

/****************************************/
/*** STEP 8: K-Means Elbow Plot *********/
/****************************************/

%let max_k = 10;

data cluster_stats;
    length k 8 avg_within_cluster_distance 8;
run;

%macro cluster_loop;
    %do k = 1 %to &max_k;

        /* Run k-means clustering for current k */
        proc fastclus data=tour_package_std 
                      maxclusters=&k 
                      out=outclus_&k 
                      outstat=stat_&k 
                      summary;
            var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
                NumberOfTrips Passport PitchSatisfactionScore OwnCar 
                NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting;
        run;

        /* Extract WITHIN_STD row and compute total variance */
        data within_&k;
            set stat_&k;
            if _TYPE_ = 'WITHIN_STD';
            array nums {*} _numeric_;
            sumsq = 0;
            do i = 1 to dim(nums);
                sumsq + nums[i]**2;
            end;
            avg_within_cluster_distance = sumsq;
            k = &k;
            keep k avg_within_cluster_distance;
        run;

        /* Append to the cluster_stats table */
        %if &k = 1 %then %do;
            data cluster_stats;
                set within_&k;
            run;
        %end;
        %else %do;
            proc datasets library=work nolist;
                append base=cluster_stats data=within_&k;
            quit;
        %end;

    %end;
%mend;

%cluster_loop;

/* Plot the elbow curve */
proc sgplot data=cluster_stats;
    series x=k y=avg_within_cluster_distance / markers lineattrs=(thickness=2);
    xaxis label='Number of Clusters (k)';
    yaxis label='Average Within-Cluster Distance';
    title "Elbow Plot for Optimal k";
run;

/****************************************/
/*** FINAL MODEL USING K = 6 (based on results from elbow plot) ***/
/*** Re-run clustering and plots based on the new optimal cluster count ***/
/****************************************/

/****************************************/
/*** STEP 4: K-Means Clustering (k=6) ***/
/****************************************/
proc fastclus data=WORK.tour_package_std 
              out=clustered 
              maxclusters=6 
              maxiter=100 
              mean=centroids 
              outstat=stats; 
   var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
       NumberOfTrips Passport PitchSatisfactionScore OwnCar 
       NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting;
run;

proc sort data=clustered;
   by cluster;
run;

proc print data=clustered (obs=4888);
   var cluster;
   title 'Customers in Each Cluster (K-Means)';
run;

/****************************************/
/*** STEP 5: Cluster Centroid Profile Chart (k=6) ***/
/****************************************/

proc transpose data=centroids out=centroids_t name=variable;
   var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
       NumberOfTrips Passport PitchSatisfactionScore OwnCar 
       NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting;
   id cluster;
run;

proc sgplot data=centroids_t;
   series x=variable y='1'n / lineattrs=(color=blue thickness=2);
   series x=variable y='2'n / lineattrs=(color=red thickness=2);
   series x=variable y='3'n / lineattrs=(color=green thickness=2);
   series x=variable y='4'n / lineattrs=(color=black thickness=2);
   series x=variable y='5'n / lineattrs=(color=orange thickness=2);
   series x=variable y='6'n / lineattrs=(color=purple thickness=2);
   xaxis label="Variables";
   yaxis label="Centroid Values";
   title "Cluster Centroid Profiles";
run;

/****************************************/
/*** STEP 6: Within-Cluster Sum of Squares ***/
/****************************************/

proc sql;
   create table cluster_summary as
   select clustered.cluster, 
          count(*) as count,
          sum(distance*distance) as within_cluster_ss
   from clustered
   group by cluster
   order by cluster;
quit;

proc print data=cluster_summary;
   format within_cluster_ss 10.2;
   title "Within-Cluster Sum of Squared Distances";
run;

/****************************************/
/*** STEP 7: Between-Centroid Distance Matrix ***/
/****************************************/

data centroids_char;
   set centroids;
   cluster_char = put(cluster, 8.);
run;

proc distance data=centroids_char method=euclid out=centroid_distances;
	var interval(Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
                 NumberOfTrips Passport PitchSatisfactionScore OwnCar 
                 NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting);
	id cluster_char;
run;

proc print data=centroid_distances;
   title "Pairwise Euclidean Distances Between Cluster Centroids";
run;

/****************************************/
/*** STEP 8: Parallel Coordinates Plot ***/
/****************************************/

data centroids_labeled;
   set centroids;
   cluster_label = cats('Cluster ', cluster);
run;

proc transpose data=centroids_labeled out=centroids_long name=Variable;
   by cluster_label;
   var Age DurationOfPitch NumberOfFollowups PreferredPropertyStar 
       NumberOfTrips Passport PitchSatisfactionScore OwnCar 
       NumberOfChildrenVisiting MonthlyIncome NumberOfPersonVisiting;
run;

proc sgplot data=centroids_long;
   series x=Variable y=Col1 / group=cluster_label lineattrs=(thickness=3);
   xaxis discreteorder=data;
   yaxis label="Centroid Value";
   title "Cluster Centroid Profiles (Parallel Coordinates Plot)";
run;
