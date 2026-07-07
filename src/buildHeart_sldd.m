
% 1. Define bus schema
heartCfgBus = buildHeartBusDefinition(G);
% 2. Create dictionary
dictPath = buildHeartDictionary("Heart.sldd", heartCfgBus);

function heartCfgBus = buildHeartBusDefinition(G)
nodeNames = string(G.Nodes.Name);
nodeTypes = upper(string(G.Nodes.Type));
numNodes = numnodes(G);
numPaths = numedges(G);
% Total number of bus elements
numElements = numNodes + numPaths + 1; % +1 for Leads
% Preallocate BusElement array
elements(1, numElements) = Simulink.BusElement;
idx = 1;
%% Node configuration buses
for i = 1:numNodes
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
%% Path configuration buses
for i = 1:numPaths
    elements(idx) = Simulink.BusElement;
    elements(idx).Name = sprintf('path_%d',i);
    elements(idx).DataType = "Bus: Config_Path";
    idx = idx + 1;
end
%% Lead group
elements(idx) = Simulink.BusElement;
elements(idx).Name = "Leads";
elements(idx).DataType = "Bus: Lead_group";

%% Create Heart configuration bus
heartCfgBus = Simulink.Bus;
heartCfgBus.Elements = elements;
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
    "Leads_group.sldd"
    "Path_dd.sldd"
];

existing = string(dd.DataSources);

for i = 1:numel(references)
    refName = references(i);
    if ~any(existing == refName)
        addDataSource(dd, refName);
    end
end

%% Store top-level bus
design=getSection(dd,"Design Data");
if ~ exist(design,"HeartCfgBus")
    addEntry(design,"HeartCfgBus",heartCfgBus);
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
