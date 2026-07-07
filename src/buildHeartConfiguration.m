function cfg = buildHeartConfiguration(G)
numNodes = numnodes(G);
numPaths = numedges(G);
cfg=struct;
%% Nodes
for i=1:numNodes
    cfg.(G.Nodes.Name{i})=G.Nodes.cfg{i};
end
%% Paths
for i=1:numPaths
    cfg.(sprintf('path_%d',i))=G.Edges.pathCfg{i};
end

%% Default electrodes
cfg.Leads=createDefaultLeadGroup();
end

function leads=createDefaultLeadGroup()
pos=struct(...
    "x",0,...
    "y",0,...
    "z",0);
lead=struct(...
    "e_pos",pos,...
    "e_type",uint8(0));
names=[
    "Aring1"
    "Aring2"
    "Atip1"
    "Atip2"
    "Vring1"
    "Vring2"
    "Vtip1"
    "Vtip2"
];

leads=struct;
for i=1:numel(names)
    leads.(names(i))=lead;
end

end