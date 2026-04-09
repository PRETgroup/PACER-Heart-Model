% Assign scope data from each node to a variable
Node1AP = out.ScopeData{1}.Values.Data;
Node2AP = out.ScopeData1{1}.Values.Data;
Node3AP = out.ScopeData2{1}.Values.Data;

time = out.ScopeData{1}.Values.Time;

[Durations1, DI1, locs1, APD90Times1, APD90Values1, pks1] = APD(Node1AP, time);
[Durations2, DI2, locs2, APD90Times2, APD90Values2, pks2] = APD(Node2AP, time);
[Durations3, DI3, locs3, APD90Times3, APD90Values3, pks3] = APD(Node3AP, time);

pks1 = pks1*0.5;
pks2 = pks2*0.5;
pks3 = pks3*0.5;

% Plot AP data against time
figure

ax(1) = subplot(3, 1, 1);
plot(time, Node1AP, "black");
title('Node 1 (NM)');
ylabel('Voltage (mV)');
xlabel('Time (s)');

yl = ylim;
ylim(yl);

hold on

scatter(locs1, pks1, "black");
scatter(APD90Times1, APD90Values1, "black");
set(ax(1), 'Clipping', 'off');

plot([locs1 locs1], [-300 50], '--r', 'DisplayName', 'Upstroke');
plot([APD90Times1 APD90Times1], [-300 15], ':r', 'DisplayName', 'APD90');

%legend('', '', '', '', '', '', '', '', '', '', '', '','','', '', 'Upstroke', 'APD90');

hold off

ax(2) = subplot(3, 1, 2);
plot(time, Node2AP, "black");
title('Node 2 (M)');
ylabel('Voltage (mV)');
xlabel('Time (s)');

yl = ylim;
ylim(yl);

hold on

scatter(locs2, pks2, "black");
scatter(APD90Times2, APD90Values2, "black");
plot([locs1 locs1], yl, '--r');
plot([APD90Times1 APD90Times1], yl, ':r');

hold off

ax(3) = subplot(3, 1, 3);
plot(time, Node3AP, "black");
title('Node 3 (M)');
ylabel('Voltage (mV)');
xlabel('Time (s)');

yl = ylim;
ylim(yl);

hold on

scatter(locs3, pks3, "black");
scatter(APD90Times3, APD90Values3, "black");
plot([locs1 locs1], yl, '--r');
plot([APD90Times1 APD90Times1], yl, ':r');

hold off

