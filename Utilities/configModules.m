% 1. Define and load the template model safely
configTemplateModel = 'Node_N';
if ~bdIsLoaded(configTemplateModel)
    load_system(configTemplateModel);
end

% 2. Extract, copy, and set the name for the source configuration
srcCs = copy(getActiveConfigSet(configTemplateModel));
newConfigName = 'defaultConfig';
set_param(srcCs, 'Name', newConfigName);

% 3. Define target modules (cleaned up formatting)
modules = {'Node_M', 'Node_NM','Path_model', 'Electrode', 'Sensing'};

% 4. Iterate through each module and apply the configuration
for i = 1:numel(modules)
    moduleName = modules{i};
    
    % Load system only if it isn't already in memory
    if ~bdIsLoaded(moduleName)
        load_system(moduleName);
    end
    
    % Get the exact name of the current active configuration
    oldConfig = getActiveConfigSet(moduleName);
    oldConfigName = get_param(oldConfig, 'Name');
    
    % Prevent naming conflict: Rename old config ONLY if it shares the new name
    if strcmp(oldConfigName, newConfigName)
        oldConfigName = [newConfigName, '_old'];
        set_param(oldConfig, 'Name', oldConfigName);
    end
    
    try
        % Attach the new config, set it active, and detach the old one
        attachConfigSet(moduleName, copy(srcCs));
        setActiveConfigSet(moduleName, newConfigName);
        detachConfigSet(moduleName, oldConfigName);
        
        % Save the modified model
        save_system(moduleName);
        fprintf('Successfully updated configuration for: %s\n', moduleName);
    catch ME
        warning('ConfigUpdate:Failed', ...
            'Failed to update %s. Reason: %s', moduleName, ME.message);
    end
end