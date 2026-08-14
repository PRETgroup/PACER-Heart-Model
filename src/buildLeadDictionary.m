function buildLeadDictionary(leadCfgBus,leadDictName)
proj=currentProject;
root=proj.RootFolder;
dictPath=fullfile(...
    root,...
    "Data",...
    "sldd_component",...
    leadDictName);
closeConflictingOpenDictionaries(dictPath, leadDictName);
%% Create dictionary
if isfile(dictPath)
    warning('%s exists.',dictPath)
    dd=openDictionaryWithRetry(dictPath);
else
    Simulink.data.dictionary.create(dictPath);
    dd=openDictionaryWithRetry(dictPath);
end
%% Add component dictionary references
componentFolder=fullfile(...
    root,...
    "Data",...
    "sldd_component");
addpath(componentFolder);
references=[
    "Leads_type.sldd"
];

existing = string(dd.DataSources);

for datai = 1:numel(existing)
    removeDataSource(dd,existing(datai))
end

for i = 1:numel(references)
    refName = references(i);
    addDataSource(dd, refName);
end

%% Store top-level bus
design=getSection(dd,"Design Data");
try
    addEntry(design, 'Lead_group', leadCfgBus);
catch
    warning('Lead_group already exists')
    entry = getEntry(design, 'Lead_group');
    setValue(entry, leadCfgBus);      % Replace the existing value
end
saveChanges(dd);
close(dd);
end