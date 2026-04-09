
% Find the peak locations and their respective diatolic intervals from
% simulation data
[Durations_temp, DI_temp, locs] = APD(out.ScopeData{1}.Values.Data, out.ScopeData{1}.Values.Time);
[Durations_temp1, DI_temp1, locs1] = APD(out.ScopeData1{1}.Values.Data, out.ScopeData1{1}.Values.Time);
[Durations_temp2, DI_temp2, locs2] = APD(out.ScopeData2{1}.Values.Data, out.ScopeData2{1}.Values.Time);

% Compute the time difference between peaks at each node

ConductionTime01 = locs1 - locs;
ConductionTime12 = locs2 - locs1;

% Find path distances from path_raw
PathDistance = [path_raw(2,20); path_raw(3,20)]; 
PathDistance = cell2mat(PathDistance);

% Divide the first element of PathDistance with each element of
% ConductionTime01 to find the conduction velocities to find conduction
% velocities from Node 1 to Node 2
ConductionVelocity01_temp = PathDistance(1) ./ ConductionTime01;

% Repeat the last step with the second element of PathDistance and
% ConductionTime12 to find conduction velocities from Node 2 to Node 3
ConductionVelocity12_temp = PathDistance(2) ./ ConductionTime12;

if isfile("ConductionVelocity.mat")
    load("ConductionVelocity.mat");
else
    ConductionVelocity01 = [];
    ConductionVelocity12 = [];
end

if isfile("DIPath.mat")
    load("DIPath.mat")
else
    DI1 = [];
    DI2 = [];
end

ConductionVelocity01_temp(1) = [];
ConductionVelocity12_temp(1) = [];

ConductionVelocity01 = vertcat(ConductionVelocity01, ConductionVelocity01_temp);
ConductionVelocity12 = vertcat(ConductionVelocity12, ConductionVelocity12_temp);

DI1 = vertcat(DI1, DI_temp1);
DI2 = vertcat(DI2, DI_temp2);

save("ConductionVelocity.mat", "ConductionVelocity01", "ConductionVelocity12");
save("DIPath.mat", "DI1", "DI2");

% Plot Conduction Velocities against their respective Distolic Intervals
figure
scatter(DI1, ConductionVelocity01, "red");

hold on

scatter(DI2, ConductionVelocity12, "green");

hold off