%work with data from the eyes on the bay website
%https://eyesonthebay.dnr.maryland.gov/contmon/ContMon.cfm
%from 01/01/2001 - 05/07/25
%Aquarium East Surface (AES) and Aquarium East Bottom (AEB)
%
clear all;
%read raw data
AES=readtable("newEOTBData_Patapsco_AES_25May16_TO_17Jun26.csv");
AEB=readtable("newEOTBData_Patapsco_AEB_25May16_TO_17Jun26.csv");
new_weather=readtable("Weather_data_25May2016-17June2026.txt");
%make into a time table and interpolate at 15 minute intervals
weather_TT=table2timetable(new_weather);
startTimet=weather_TT.Date(1);
startTime = datetime(startTimet.Year,startTimet.Month,startTimet.Day,startTimet.Hour,0,0);
time = (startTime:minutes(15):weather_TT.Date(end))';
weather_TT_15=retime(weather_TT,time,'linear');
%find overlap between surface and bottom
overlap=ismember(AES.DateTime,AEB.DateTime);
newAES=AES(overlap,:);
overlap2=ismember(AEB.DateTime,AES.DateTime);
newAEB=AEB(overlap2,:);
new_AESB=join(newAES,newAEB,"Keys","DateTime");
%Merge weather data as well
overlap3=ismember(weather_TT_15.Date, new_AESB.DateTime);
new_weather_TT_15=weather_TT_15(overlap3,:);
overlap4=ismember(new_AESB.DateTime, new_weather_TT_15.Date);
new_new_AESB=new_AESB(overlap4,:);
%make the final table
new_new_AESB2=renamevars(new_new_AESB,"DateTime","Date");
new_weather_TT_152=timetable2table(new_weather_TT_15);
new_AESB_weather=join(new_new_AESB2,new_weather_TT_152);
%check for new names w/ line below
%new_AESB_weather.Properties.VariableNames

%prediction time window is 3 days ahead...
%we need n3 rows then 
n3=3*4*24;

%create future columns for predicted values *this is what we want*
%future time points for predictions
current_AES_DO=new_AESB_weather.DO_mg_L_newAES;
future_AES_DO=[current_AES_DO(n3+1:end); NaN(n3,1)];

%make new table for predictions
regression_table=table();
%Indicators of PT used to predict AES DO
regression_table.DO_AES=new_AESB_weather.DO_mg_L_newAES;
regression_table.Chl_AES=new_AESB_weather.Chl_ug_L_newAES;
regression_table.Turb_AES=new_AESB_weather.Turb_NTU_newAES;
%Predictors of PT used to predict AES DO
regression_table.DO_AEB=new_AESB_weather.DO_mg_L_newAEB;
regression_table.Chl_AEB=new_AESB_weather.Chl_ug_L_newAEB;
regression_table.Turb_AEB=new_AESB_weather.Turb_NTU_newAEB;
regression_table.Salinity_AES=new_AESB_weather.Salinity_ppt_newAES;
regression_table.Salinity_AEB=new_AESB_weather.Salinity_ppt_newAEB;
regression_table.Total_PPT_IN=new_AESB_weather.Total_PPT_IN;
regression_table.Temp_AES=new_AESB_weather.Temp_C_newAES;
regression_table.Temp_AEB=new_AESB_weather.Temp_C_newAEB;
regression_table.Avg_WS_MPH=new_AESB_weather.Avg_WS_MPH;
regression_table.Max_WS_MPH=new_AESB_weather.Max_WS_MPH;
regression_table.Min_WS_MPH=new_AESB_weather.Min_WS_MPH;

%remove NaN future responses that don't exist
valid=~isnan(future_AES_DO);
%and fill missing predictors 
regression_table=fillmissing(regression_table,'linear')

%define clean, aligned versions of variables
X=regression_table(valid,:);
Y=future_AES_DO(valid);
Date_model=new_AESB_weather.Date(valid);

%split data into training and testing groups
%2016-2024 will be used to train
%2025-present will be used to test
%eventually need to test the 6/17/26-7/26 PT values
train_rows=Date_model<datetime(2025,1,1);
test_rows=Date_model>=datetime(2025,1,1);

%training data
X_train=X(train_rows,:);
Y_train=Y(train_rows);

%testing data
X_test=X(test_rows,:);
Y_test=Y(test_rows);

Date_test=Date_model(test_rows);

%Train random forest model to predict AES DO 3 days out
%Copied from Process_Data_Weather
t = templateTree('NumVariablesToSample','all',...
    'PredictorSelection','interaction-curvature','Surrogate','on');
rng(1); % For reproducibility 
Mdl = fitrensemble(X_train,Y_train,'Method','Bag','NumLearningCycles',100, ...
    'Learners',t);

%Use the model to predict from testing data
yHat=predict(Mdl,X_test);

%how good is the model?
RMSE=sqrt(mean((Y_test-yHat).^2,"omitnan"));
R2=corr(Y_test,yHat,"Rows","complete")^2
fprintf("\nAES DO 3 Day Prediction\n");
fprintf("RMSE: %.3f mg/L\n",RMSE);
fprintf("R2: %.3f\n",R2);