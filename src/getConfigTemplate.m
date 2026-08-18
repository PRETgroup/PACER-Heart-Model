function getConfigTemplate(dictName,configName,configTemplateModel)
proj=currentProject;
root=proj.RootFolder;
dictPath=fullfile(...
    root,...
    "Data",...
    "sldd_system",...
    dictName);
closeConflictingOpenDictionaries(dictPath, dictName);
Simulink.data.dictionary.closeAll;

load_system(configTemplateModel);
myConfig = copy(getActiveConfigSet(configTemplateModel));

% Optional: Rename the config object so it looks clean in the dictionary
myConfig.Name = configName;

% 3. Create a new dictionary or open an existing one
if ~exist(dictPath, 'file')
    dictObj = Simulink.data.dictionary.create(dictPath);
else
    dictObj = Simulink.data.dictionary.open(dictPath);
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
end