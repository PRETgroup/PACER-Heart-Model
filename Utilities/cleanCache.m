% 1. Close all models to release active Simulink file locks
bdclose('all');

% 2. Clear standard workspace variables and Simulation Data Inspector
evalin('base', 'clearvars'); 
Simulink.sdi.clear;

% 3. Retrieve the dedicated folder paths directly from Simulink
cfg = Simulink.fileGenControl('getConfig');
foldersToClean = {cfg.CacheFolder, cfg.CodeGenFolder};

% 4. Loop through and empty both folders safely
for i = 1:length(foldersToClean)
    targetFolder = foldersToClean{i};
    
    if exist(targetFolder, 'dir')
        % Get all contents inside the folder
        contents = dir(targetFolder);
        
        for j = 1:length(contents)
            itemName = contents(j).name;
            itemPath = fullfile(targetFolder, itemName);
            
            % Skip the '.' (current) and '..' (parent) directory pointers
            if strcmp(itemName, '.') || strcmp(itemName, '..')
                continue;
            end
            
            % Use try/catch to gracefully handle locked files/folders
            try
                if contents(j).isdir
                    rmdir(itemPath, 's');
                else
                    delete(itemPath);
                end
            catch ME
                % If a file is locked, print a warning but keep going!
                fprintf('Skipped locked item: %s\n  -> Reason: %s\n', itemName, ME.message);
            end
        end
        fprintf('Finished cleaning folder:\n -> %s\n', targetFolder);
    else
        fprintf('Folder does not exist (nothing to clean):\n -> %s\n', targetFolder);
    end
end

disp('Cleanup complete. You are ready to force a clean rebuild.');