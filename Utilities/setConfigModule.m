proj = currentProject;
% 1. Define your dictionary and the name for your configuration
dictName = fullfile(proj.RootFolder,'Data/sldd_component/SharedConfigData.sldd'); 
configName = 'MasterConfig';
Simulink.data.dictionary.closeAll;
% 2. Get the configuration set you want to save
% (e.g., extracting it from an existing model)
configTemplateModel='Node_N';
load_system(configTemplateModel);
myConfig = copy(getActiveConfigSet(configTemplateModel));

% Optional: Rename the config object so it looks clean in the dictionary
myConfig.Name = configName;

% 3. Create a new dictionary or open an existing one
if ~exist(dictName, 'file')
    dictObj = Simulink.data.dictionary.create(dictName);
else
    dictObj = Simulink.data.dictionary.open(dictName);
end

% 4. Access the specific section for Configurations
sectObj = getSection(dictObj, 'Configurations');

% 5. Add or update the configuration set in the dictionary
try
    % If the entry already exists, update its value
    entryObj = getEntry(sectObj, configName);
    setValue(entryObj, myConfig);
    disp('Updated existing configuration in the dictionary.');
catch
    % If it does not exist, create a new entry
    addEntry(sectObj, configName, myConfig);
    disp('Added new configuration to the dictionary.');
end

% 6. Save changes and close the dictionary to free memory
saveChanges(dictObj);
close(dictObj);