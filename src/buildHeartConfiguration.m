function buildHeartConfiguration(G,slddHeart)
numNodes = numnodes(G);
numPaths = numedges(G);
nodeNames = string(G.Nodes.Name);
nodeTypes = upper(string(G.Nodes.Type));
HeartCfg=struct;% The data for model configuration
numElements = numNodes + numPaths*2;
% Preallocate BusElement array
elements(1, numElements) = Simulink.BusElement;
idx = 1;
%% Nodes
for i=1:numNodes
    HeartCfg.(G.Nodes.Name{i})=G.Nodes.cfg{i};
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
    HeartCfg.(sprintf('path_%d',i))=G.Edges.pathCfg{i};
    elements(idx) = Simulink.BusElement;
    elements(idx).Name = sprintf('path_%d',i);
    elements(idx).DataType = "Bus: Config_Path";
    idx = idx + 1;
end
%% Dipoles
for i=1:numPaths
    HeartCfg.(sprintf('dipole_%d',i))=G.Edges.dipole{i};
    elements(idx) = Simulink.BusElement;
    elements(idx).Name = sprintf('dipole_%d',i);
    elements(idx).DataType = "Bus: Config_Dipole";
    idx = idx + 1;
end
%% Create Heart configuration bus
heartCfgBus = Simulink.Bus;
heartCfgBus.Elements=elements;
% Create dictionary
buildHeartDictionary(slddHeart, heartCfgBus, HeartCfg);
end

function buildHeartDictionary(dictName,heartCfgBus,HeartCfg)
proj=currentProject;
root=proj.RootFolder;
dictPath=fullfile(...
    root,...
    "Data",...
    "sldd_system",...
    dictName);
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
    "Sensing_dd.sldd"
    "Dipole_cfg_type.sldd"
    "Wavefront_type.sldd"
    "Path2Probe_type.sldd"
    "PM_DDD_dd.sldd"
];

existing = string(dd.DataSources);
% Clean existing references
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

try
    addEntry(design, 'HeartCfg', HeartCfg);
catch
    warning('HeartCfg already exists')
    entry = getEntry(design, 'HeartCfg');
    setValue(entry, HeartCfg);      % Replace the existing value    
end
saveChanges(dd);
close(dd);
end





