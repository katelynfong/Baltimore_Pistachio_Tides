%work with data from the eyes on the bay website
%https://eyesonthebay.dnr.maryland.gov/contmon/ContMon.cfm
%from 01/01/2001 - 05/07/25
%Aquarium East Surface (AES) and Aquarium East Bottom (AEB)
%
clear all;
%read raw data
AES=readtable("EOTBData_AES_25May16_TO_31Jul26.csv");
AEB=readtable("EOTBData_AEB_25May16_TO_31Jul26.csv");
new_weather=readtable("Weather_data_25May2016-31Jul2026.csv");
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
%diff= new_AESB.Chl_ug_L_newAES -new_AESB.Turb_NTU_newAES;
%find values lower than some threshold as tides
Chl_idx=find(new_AESB_weather.Chl_ug_L_newAES<2);
DO_idx=find(new_AESB_weather.DO_mg_L_newAES<2);
Turb_idx=find(new_AESB_weather.Turb_NTU_newAES>5);
%find where these all overlap
overlapDOChl=ismember(DO_idx,Chl_idx);
newDO_idx=DO_idx(overlapDOChl);
overlabTurbDOCh=ismember(Turb_idx,newDO_idx);
newTurb_idx=Turb_idx(overlabTurbDOCh);
%Make Pistachio Tide index 1 for combination of variables
PT=zeros(height(new_AESB_weather),1);
PT(newTurb_idx)=1;
%But I think the Bottom oxygen levels might also be impacting this
%scatter(new_AESB.Turb_NTU_newAES(idx), new_AESB.DO_mg_L_newAEB(idx),5,new_AESB.Temp_C_newAEB(idx), "filled");
%xlabel("Turb (surface)");
%ylabel("DO (bottom)");
%This approximates the difference in density between surface and bottom
%Don't have the measured pressure, so not perfect
%diff_rho=seawater_density(new_AESB.Salinity_ppt_newAES,new_AESB.Temp_C_newAES,1) - seawater_density(new_AESB.Salinity_ppt_newAEB,new_AESB.Temp_C_newAEB,1);
%Relative resistance to mixing
%RTR = ((diff_rho) * 10^6)/8;
%Figure out stretches where Turb > 5, Chl and DO < 2
plot(new_AESB_weather.Date,new_AESB_weather.Turb_NTU_newAES);
hold on;
plot(new_AESB_weather.Date,new_AESB_weather.Chl_ug_L_newAES, "red");
plot(new_AESB_weather.Date,new_AESB_weather.DO_mg_L_newAES, "green");
plot(new_AESB_weather.Date,PT, "black");
xlabel('Date');
ylabel('Value')
title('AES, Turbidity, Chlorophyll, DO, and PT Index')
legend('Turbidity','Chlorophyll','DO','PT Index','Location','best')
%make the regression table
diff=new_AESB_weather.Temp_C_newAES-new_AESB_weather.Temp_C_newAEB;
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
%remove these for real model
%regression_struct.Turb_NTU_newAES = new_AESB_weather.Turb_NTU_newAES;
%regression_struct.Chl_ug_L_newAES = new_AESB_weather.Chl_ug_L_newAES;
%regression_struct.DO_mg_L_newAES = new_AESB_weather.DO_mg_L_newAES;
regression_table = struct2table(regression_struct);
%this doesn't yield anything
%regression_table.RESPONSE=PT;
%results=stepwiselm(regression_table,'PEnter',0.01);
%countLevels = @(x)numel(categories(categorical(x)));
%numLevels = varfun(countLevels,regression_table,'OutputFormat','uniform');
%figure
%bar(numLevels);
t = templateTree('NumVariablesToSample','all',...
   'PredictorSelection','interaction-curvature','Surrogate','on');
rng(1); % For reproducibility
Mdl = fitrensemble(regression_table,PT, 'Method','Bag','NumLearningCycles',200, ...
   'Learners',t);
yHat = oobPredict(Mdl);
R2 = corr(Mdl.Y,yHat)^2;
%results without predictors is 0.7488
impOOB = oobPermutedPredictorImportance(Mdl);
figure
bar(impOOB)
title('Unbiased Predictor Importance Estimates')
xlabel('Predictor variable')
ylabel('Importance')
h = gca;
h.XTickLabel = Mdl.PredictorNames;
h.XTickLabelRotation = 45;
h.TickLabelInterpreter = 'none';

