% =========================================================================
% MATLAB Script: Wedderburn Number (W) Hydrodynamic Stability Model
% Calculates wind-driven mixing vs. thermal buoyancy in a water body
% Generated with AI from Google AI mode
% =========================================================================
% Find overlapping timestamps between surface and bottom

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

%% 1. Define Model Dimensions & Constants
g = 9.81; % Acceleration due to gravity (m/s^2)
rho_air = 1.2; % Approximate density of air (kg/m^3)
Cd = 0.0011; % Dimensionless wind drag coefficient for water surfaces
L = 4200.0; % Basin length in direction of wind, estimated with Google Earth Web (m)
h = 2.5; % Depth of the upper mixed layer / pycnocline (meters)
%% 2. Input Environmental Data (Example Summer Data Series)
% Replace these vectors with your actual Eyes on the Bay and BWI data
% Simulating average wind speed at 10m height (converted from mph to m/s)
wind_mph = new_AESB_weather.Avg_WS_MPH;
wind_mps=wind_mph*0.44704;

%interpolating/filling missing data
new_AESB_weather.Temp_C_newAES = fillmissing(new_AESB_weather.Temp_C_newAES, 'linear');
new_AESB_weather.Temp_C_newAEB = fillmissing(new_AESB_weather.Temp_C_newAEB, 'linear');
new_AESB_weather.Salinity_ppt_newAES = fillmissing(new_AESB_weather.Salinity_ppt_newAES, 'linear');
new_AESB_weather.Salinity_ppt_newAEB = fillmissing(new_AESB_weather.Salinity_ppt_newAEB, 'linear');

%% 3. Core Hydrodynamic Algorithm Execution
% Step A: Convert temperatures to water densities using McCutcheon equation
rho_bot=seawater_density(new_AESB_weather.Salinity_ppt_newAEB, new_AESB_weather.Temp_C_newAEB, 1.63);
rho_top=seawater_density(new_AESB_weather.Salinity_ppt_newAES, new_AESB_weather.Temp_C_newAES, 1.1);
delta_rho = rho_bot - rho_top;
g2=(g*delta_rho)./rho_top; %standardized g according to sources
% Step B: Calculate wind shear stress (Tau) acting on surface
tau = rho_air * Cd * (wind_mps.^2);
% Step C: Calculate water friction velocity (u_star)
u_star = sqrt(tau ./ rho_top);
% Step D: Compute the dimensionless Wedderburn Number (W)
% Formula: W = (g2 * h^2) / (u_star^2 * L)
W = ((g2 .* (h^2)) ./ (u_star.^2 * L));
%% 4. Generate Visualization (Logarithmic Trend Plot)
figure('Position', [100, 100, 850, 450]);
hold on;
% Plot Wedderburn Number Timeline
plot(new_AESB_weather.Date, W, 'Color',[0.0, 0.54, 0.48], 'LineWidth', 2.5, 'DisplayName', 'Wedderburn Number (W)');
% Plot Critical Mixing Threshold Line
ax_line = yline(1.0, '--r', 'LineWidth', 1.5, 'DisplayName', 'Critical Mixing Threshold (W=1)');
% Format Axes to Log Scale
set(gca, 'YScale', 'log');
ylim([0.05, 1000]);
xlim([datetime(2016,7,1), datetime(2026,7,31)]);
% Labeling and Styling
ylabel('Wedderburn Number (W) [Log Scale]', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Date', 'FontSize', 11, 'FontWeight', 'bold');
title('Hydrodynamic Stability & Mixing Potential', 'FontSize', 13, 'FontWeight', 'bold');
% Create visual shading for the Stable Stratified Zone (W > 1)
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);
legend('Location', 'southwest', 'FontSize', 10);
hold on;

%adding turbidity and DO
range=new_AESB_weather.Date>=datetime(2026,7,1,0,0,0) & ...
    new_AESB_weather.Date<=datetime(2026,7,31,23,59,0);

W_plot=W;
W_plot(W_plot <=0)=NaN;

figure;

yyaxis left
plot(new_AESB_weather.Date(range),new_AESB_weather.DO_mg_L_newAES(range), ...
    'g','LineWidth',1.3,'DisplayName','AES DO');
hold on;
plot(new_AESB_weather.Date(range),new_AESB_weather.Turb_NTU_newAES(range),...
    'blue-','LineWidth',1.3,'DisplayName','AES Turbidity');
ylabel('AES DO (mg/L) and Turbidity (NTU)');

yyaxis right
plot(new_AESB_weather.Date(range), W_plot(range),'LineWidth',1.5, ...
    'DisplayName','Wedderburn Number (log scale)');
yline(1.0, '--','LineWidth', 1.3,'DisplayName', 'W = 1');

set(gca, 'YScale', 'log'); %y axis as a log scale
ylabel('Wedderburn Number (log scale)');

xlabel('Date');

title('AES DO, Turbidity, and Wedderburn Number During July 2026 PT Window');
grid on;
legend('Location','best');
hold off;