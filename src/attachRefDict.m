function attachRefDict(slddHeart,references)
proj=currentProject;
root=proj.RootFolder;
dictPath=fullfile(...
    root,...
    "Data",...
    "sldd_system",...
    slddHeart);
%% Create dictionary
if isfile(dictPath)
    warning('%s exists.',dictPath)
    dd=openDictionaryWithRetry(dictPath);
else
    Simulink.data.dictionary.create(dictPath);
    dd=openDictionaryWithRetry(dictPath);
end

% 1. Retrieve the list of existing data sources attached to the dictionary
existingSources = dd.DataSources;

for i = 1:numel(references)
    refName = references(i);

    % 2. Check if the current reference is already in the list
    if ~any(strcmp(existingSources, refName))
        addDataSource(dd, refName);
        fprintf('Attached data source: %s\n', refName);
    else
        % 3. Handle the case where it already exists (skip gracefully)
        fprintf('Data source already exists, skipping: %s\n', refName);
    end
end
saveChanges(dd);
close(dd);
end