
function [APD90, DI, locs, APD90Times, APD90Values, pks] = APD(APData, APTime)
% Determine peak AP value

[pks, locs] = findpeaks(APData, APTime, 'MinPeakProminence', 50);
TimeIndices = zeros(length(locs) + 1, 1);

for i = 1:length(locs)
    for j = 1:length(APTime)
        if APTime(j) == locs(i)
            TimeIndices(i) = j;
        end
    end
end

TimeIndices(length(TimeIndices)) = length(APTime);

% Preallocate arrays to contain the values and times of the closest values to
% 90% of each peak value
APD90Values = zeros(length(pks), 1);
APD90Times = zeros(length(pks), 1);

% Find the index of the closest value to 90% of the peak value for each
% element of the pks array

i = 1;
for i = 1:length(pks)
% while i < length(pks)
    % locs
    % pks
    % i

    % if i > length(pks)
    %     break
    % end

    AP90 = pks(i)*0.1;
    minDistance = pks(i);

    for j = TimeIndices(i):TimeIndices(i + 1) %- 1
        if abs(APData(j) - AP90) < minDistance
            APD90Values(i) = APData(j);
            APD90Times(i) = APTime(j);
            minDistance = abs(APData(j) - AP90);
        end
    end

    % i = i + 1;

    if minDistance > pks(i)*0.05
        pks(i) = [];
        APD90Values(i) = [];
        APD90Times(i) = [];
        locs(i) = [];
        % TimeIndices(i) = [];
        % i = i - 1;
    end
end

%Compute the differences in times between each element in APD90Times and
%locs to find the Action Potential Duration
APD90 = APD90Times - locs;

% Find the periods between AP peaks
Periods = zeros(length(locs), 1);

for i = 2:length(locs)
    Periods(i - 1) = locs(i) - locs(i - 1);
end

% Find the Diastolic Interval, DI for each period of the AP
DI = Periods - APD90;
DI(length(DI)) = [];
APD90(1) = [];
% DI
% APD90
% locs

end
