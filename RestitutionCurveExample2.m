

% % Find the action potential durations from simulation data
% [Durations_temp, DI_temp] = APD(out.ScopeData{1}.Values.Data, out.ScopeData{1}.Values.Time);
% [Durations_temp1, DI_temp1] = APD(out.ScopeData1{1}.Values.Data, out.ScopeData1{1}.Values.Time);
% [Durations_temp2, DI_temp2] = APD(out.ScopeData2{1}.Values.Data, out.ScopeData2{1}.Values.Time);
% 
% BCL = PulsePeriod;

if isfile("Durations_Paced.mat")
    load("Durations_Paced.mat");
else
    Durations = [];
    Durations1 = [];
    Durations2 = [];
end

if isfile("DI_Paced.mat")
    load("DI_Paced.mat")
else
    DI = [];
    DI1 = [];
    DI2 = [];
end

% Durations_temp = horzcat(Durations_temp, BCL*ones(length(Durations_temp),1));
% Durations_temp1 = horzcat(Durations_temp1, BCL*ones(length(Durations_temp1),1));
% Durations_temp2 = horzcat(Durations_temp2, BCL*ones(length(Durations_temp2),1));
% 
% Durations = vertcat(Durations, Durations_temp);
% Durations1 = vertcat(Durations1, Durations_temp1);
% Durations2 = vertcat(Durations2, Durations_temp2);
% 
% DI = vertcat(DI, DI_temp);
% DI1 = vertcat(DI1, DI_temp1);
% DI2 = vertcat(DI2, DI_temp2);
% 
% save("Durations_Paced.mat", "Durations", "Durations1", "Durations2");
% save("DI_Paced.mat", "DI", "DI1", "DI2");

% Plot Durations against DI to find the Restitution Curve
figure

hold on

cmap = jet(256);
colormap jet

scatter1 = scatter(DI, Durations(:,1), 50, cmap(round(Durations(:,2)*301.1765), :), "o", 'DisplayName', 'Node 1 (NM)');
scatter2 = scatter(DI1, Durations1(:,1), 50, cmap(round(Durations1(:,2)*301.1765), :), "square", 'DisplayName', 'Node 2 (M)');
scatter3 = scatter(DI2, Durations2(:,1), 50, cmap(round(Durations2(:,2)*301.1765), :), "^", 'DisplayName', 'Node 3 (M)');

c = colorbar('TickLabels',{'0','0.085','0.17','0.255','0.34','0.425','0.51','0.595','0.68','0.765','0.85'});
c.Label.String = 'Pulse Period (s)';

scatter1.DataTipTemplate.DataTipRows(1).Label = 'Diastolic Interval (s)';
scatter1.DataTipTemplate.DataTipRows(2).Label = 'Action Potential Duration (s)';
scatter1.DataTipTemplate.DataTipRows(3).Label = 'Base Cycle Length (s)';
scatter1.DataTipTemplate.DataTipRows(3).Value = Durations(:,2);

scatter2.DataTipTemplate.DataTipRows(1).Label = 'Diastolic Interval (s)';
scatter2.DataTipTemplate.DataTipRows(2).Label = 'Action Potential Duration (s)';
scatter2.DataTipTemplate.DataTipRows(3).Label = 'Base Cycle Length (s)';
scatter2.DataTipTemplate.DataTipRows(3).Value = Durations1(:,2);

scatter3.DataTipTemplate.DataTipRows(1).Label = 'Diastolic Interval (s)';
scatter3.DataTipTemplate.DataTipRows(2).Label = 'Action Potential Duration (s)';
scatter3.DataTipTemplate.DataTipRows(3).Label = 'Base Cycle Length (s)';
scatter3.DataTipTemplate.DataTipRows(3).Value = Durations2(:,2);

legend();

hold off

title('Restitution Curve')
ylabel('Action Potential Duration (s)');
xlabel('Diastolic Interval (s)');

% APPlot