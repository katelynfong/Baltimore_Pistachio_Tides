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

%predict AES DO instead of PT here
DO_AES_response=new_AESB_weather.DO_mg_L_newAES;

%make the regression table
diff=new_AESB_weather.Temp_C_newAES-new_AESB_weather.Temp_C_newAEB;
regression_struct=struct();
%Sample Depth doesn't exist in original data
%regression_struct.SampleDepth_m_newAEB = new_AESB_weather.SampleDepth_m_newAEB;
regression_struct.Salinity_ppt_newAES = new_AESB_weather.Salinity_ppt_newAES;
regression_struct.pH_newAEB=new_AESB_weather.pH_newAEB;
regression_struct.Temp_C_newAES = discretize(new_AESB_weather.Temp_C_newAES,500);
regression_struct.Temp_C_newAEB = discretize(new_AESB_weather.Temp_C_newAEB,500);
regression_struct.Temp_C_diff = discretize(diff,500);
regression_struct.DO_mg_L_newAEB = new_AESB_weather.DO_mg_L_newAEB;
regression_struct.Max_WS_MPH = discretize(new_AESB_weather.Max_WS_MPH,500);
regression_struct.Avg_WS_MPH = discretize(new_AESB_weather.Avg_WS_MPH,500);
regression_struct.Min_WS_MPH = discretize(new_AESB_weather.Min_WS_MPH,500);
regression_struct.Total_PPT_IN = new_AESB_weather.Total_PPT_IN;

regression_struct.Turb_NTU_newAES = new_AESB_weather.Turb_NTU_newAES;
regression_struct.Chl_ug_L_newAES = new_AESB_weather.Chl_ug_L_newAES;
%regression_struct.DO_mg_L_newAES = new_AESB_weather.DO_mg_L_newAES;
regression_table = struct2table(regression_struct);

t = templateTree('NumVariablesToSample','all',...
   'PredictorSelection','interaction-curvature','Surrogate','on');
rng(1); % For reproducibility
Mdl = fitrensemble(regression_table,DO_AES_response, 'Method','Bag','NumLearningCycles',100, ...
   'Learners',t);
%yHat = model's predicted AES DO
yHat = oobPredict(Mdl);

%model performance and figure below
R2 = corr(Mdl.Y,yHat)^2;
RMSE=sqrt(mean((Mdl.Y-yHat).^2,"omitnan"));

impOOB = oobPermutedPredictorImportance(Mdl);
figure
bar(impOOB)
title('Predictor Importance for AES DO Model')
xlabel('Predictor variable')
ylabel('Importance')
h = gca;
h.XTickLabel = Mdl.PredictorNames;
h.XTickLabelRotation = 45;
h.TickLabelInterpreter = 'none';