clear all;

%Read the raw data
AES=readtable("EOTBData_AES_25May16_TO_31Jul26.csv");
AEB=readtable("EOTBData_AEB_25May16_TO_31Jul26.csv");

%Find overlapping timestamps between surface and bottom
overlap_AES=ismember(AES.DateTime, AEB.DateTime);
newAES=AES(overlap_AES,:);
overlap_AEB=ismember(AEB.DateTime, AES.DateTime);
newAEB=AEB(overlap_AEB,:);

%Join surface and bottom data by matching timestamp
data = join(newAES, newAEB, "Keys", "DateTime");

%Define pressure (in bars) based on sensor depths
p_surface = 1 + (1/10);     % surface sensor ~1 m deep
p_bottom  = 1 + (6.3/10);   % bottom sensor ~6.3 m deep

%Calculate density at surface and bottom
rho_surface=seawater_density(data.Salinity_ppt_newAES, data.Temp_C_newAES, p_surface);
rho_bottom=seawater_density(data.Salinity_ppt_newAEB, data.Temp_C_newAEB, p_bottom);

%Density difference
diff_rho=rho_surface - rho_bottom;

% Plot it
plot(data.DateTime, diff_rho);
xlabel("Date");
ylabel("Density difference (kg/m^3)");
title("Surface - Bottom Density Difference");