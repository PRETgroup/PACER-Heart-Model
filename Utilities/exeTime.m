% Configuration
numIterations = 10;
proj = currentProject;
% 1. Create a bulletproof absolute path for Windows
% This automatically builds: C:\Your\Current\Path\CodeGeneration\Heart3D_N43.exe
exePath = fullfile(proj.RootFolder, 'CodeGeneration', 'Heart3D_N43.exe');
% Wrap the path in quotes to protect against spaces in folder names
sysCmd = sprintf('"%s"', exePath);
exe_time_0 = zeros(1, numIterations);
fprintf('Starting warm-up run (not timed)...\n');
% 2. Warm-up Run using the safe command
[status, cmdout] = system(sysCmd);

if status ~= 0
    error('Executable failed during warm-up with status %d.\nOutput:\n%s', status, cmdout);
end

fprintf('Starting %d timed executions...\n', numIterations);

% 3. Execution Loop
for i = 1:numIterations
    tic;
    [status, ~] = system(sysCmd);
    exe_time_0(i) = toc;
    
    if status == 0
        fprintf('Iteration %2d: %.4f seconds\n', i, exe_time_0(i));
    else
        fprintf('Iteration %2d: FAILED (Status %d)\n', i, status);
        exe_time_0(i) = NaN;
    end
end

% 4. Summary Statistics
fprintf('\n--- Execution Summary ---\n');
fprintf('Average Time: %.4f seconds\n', mean(exe_time_0, 'omitnan'));
fprintf('Median Time:  %.4f seconds\n', median(exe_time_0, 'omitnan'));
fprintf('Min Time:     %.4f seconds\n', min(exe_time_0, [], 'omitnan'));
fprintf('Max Time:     %.4f seconds\n', max(exe_time_0, [], 'omitnan'));
fprintf('Std Dev:      %.4f seconds\n', std(exe_time_0, 'omitnan'));