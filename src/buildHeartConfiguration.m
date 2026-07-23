function [dictPath,cfg] = buildHeartConfiguration(G,slddHeart,leadCfgBus,leadGroup)
numNodes = numnodes(G);
numPaths = numedges(G);
nodeNames = string(G.Nodes.Name);
nodeTypes = upper(string(G.Nodes.Type));
buildLeadDictionary(leadCfgBus);% TODO: need to improve
cfg=struct;% The data for model configuration
% Total number of bus elements
if nargin <3
    numElements = numNodes + numPaths ; % no Leads
else
    numElements = numNodes + numPaths + 1; % +1 for Leads
end
% Preallocate BusElement array
elements(1, numElements) = Simulink.BusElement;
idx = 1;
%% Nodes
for i=1:numNodes
    cfg.(G.Nodes.Name{i})=G.Nodes.cfg{i};
    elements(idx) = Simulink.BusElement;
    elements(idx).Name = nodeNames(i);
    switch nodeTypes(i)
        case "N"
            elements(idx).DataType = "Bus: Config_N";

        case "M"
            elements(idx).DataType = "Bus: Config_M";

        case "NM"
            elements(idx).DataType = "Bus: Config_NM";

        otherwise
            error(...
                'buildHeartBusDefinition:UnsupportedNodeType',...
                'Unsupported node type: %s', spec.type);

    end
    idx = idx + 1;
end
%% Paths
for i=1:numPaths
    cfg.(sprintf('path_%d',i))=G.Edges.pathCfg{i};
    elements(idx) = Simulink.BusElement;
    elements(idx).Name = sprintf('path_%d',i);
    elements(idx).DataType = "Bus: Config_Path";
    idx = idx + 1;
end
%% Create Heart configuration bus
heartCfgBus = Simulink.Bus;
% Create dictionary
if nargin >3
%% Lead group
cfg.Leads=leadGroup;
elements(idx) = Simulink.BusElement;
elements(idx).Name = "Leads";
elements(idx).DataType = "Bus: Lead_group";
heartCfgBus.Elements = elements;
dictPath = buildHeartDictionary(slddHeart, heartCfgBus);
else
heartCfgBus.Elements = elements;
dictPath = buildHeartDictionary(slddHeart, heartCfgBus);
end

end

function dictPath = buildHeartDictionary(dictName,heartCfgBus)
proj=currentProject;
root=proj.RootFolder;
dictPath=fullfile(...
    root,...
    "Data",...
    "sldd_system",...
    dictName);
closeConflictingOpenDictionaries(dictPath, dictName);
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
    "N_dd.sldd"
    "M_dd.sldd"
    "NM_dd.sldd"
    "Path_dd.sldd"
    "Electrode_dd.sldd"
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
    addEntry(design, 'HeartCfgBus', heartCfgBus);
catch
    warning('HeartCfgBus already exists')
    entry = getEntry(design, 'HeartCfgBus');
    setValue(entry, heartCfgBus);      % Replace the existing value    
end

saveChanges(dd);
close(dd);
end

function buildLeadDictionary(leadCfgBus)
dictName='Leads.sldd';
proj=currentProject;
root=proj.RootFolder;
dictPath=fullfile(...
    root,...
    "Data",...
    "sldd_component",...
    dictName);
closeConflictingOpenDictionaries(dictPath, dictName);
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

function closeConflictingOpenDictionaries(~, dictName)
dictName = string(dictName);

try
    openPaths = string(Simulink.data.dictionary.getOpenDictionaryPaths);
catch
    openPaths = strings(0, 1);
end

if isempty(openPaths)
    return;
end

hasNameConflict = false;
for i = 1:numel(openPaths)
    openPath = openPaths(i);
    [~, openBase, openExt] = fileparts(char(openPath));
    openFileName = string(strcat(openBase, openExt));

    if strcmpi(char(openFileName), char(dictName))
        hasNameConflict = true;
        break;
    end
end

if hasNameConflict
    % Simulink data dictionaries are unique by filename, not full path.
    Simulink.data.dictionary.closeAll;
end
end

function dd = openDictionaryWithRetry(dictPath)
try
    dd = Simulink.data.dictionary.open(dictPath);
catch err
    if isDictionaryNameConflict(err)
        Simulink.data.dictionary.closeAll;
        dd = Simulink.data.dictionary.open(dictPath);
    else
        rethrow(err);
    end
end
end

function tf = isDictionaryNameConflict(err)
msg = lower(string(err.message));
tf = contains(msg, "another dictionary with the same file name is already open");
end