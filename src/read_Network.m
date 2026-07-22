
function G = read_Network(xsheetfile, node_sheet, node_range, path_sheet, path_range)
%READ_NETWORK Build a heart-network graph from node/path sheets in a workbook.
%   G = READ_NETWORK(XSHEETFILE, NODE_SHEET, NODE_RANGE, PATH_SHEET, PATH_RANGE)
%   reads node and path data from the specified workbook and returns a
%   MATLAB graph object with node/edge attributes used by the PACER model.
%
%   Inputs
%   ------
%   XSHEETFILE : string | char
%       Path to the Excel workbook containing network data.
%   NODE_SHEET : string | char
%       Worksheet name (or index) for node data.
%   NODE_RANGE : string | char
%       Excel range for node data.
%   PATH_SHEET : string | char
%       Worksheet name (or index) for path data.
%   PATH_RANGE : string | char
%       Excel range for path data.
%
%   Output
%   ------
%   G : graph
%       Graph with:
%       - G.Nodes.Name, Type, x, y, z
%       - G.Nodes.cfg (node-type specific configuration struct)
%       - G.Edges.pathCfg (path configuration struct)
%       - G.Edges.dipole (per-edge struct with xi, yi, zi, xj, yj, zj, C)
%
%   Notes
%   -----
%   Supported node types are "N", "M", and "NM".
%
%   Example
%   -------
%   G = read_Network("network.xlsx", "Nodes", "A1:AZ100", ...
%                    "Paths", "A1:K200");

arguments
    xsheetfile {mustBeTextScalar}
    node_sheet
    node_range {mustBeTextScalar}
    path_sheet
    path_range {mustBeTextScalar}
end

if ~(ischar(node_sheet) || isStringScalar(node_sheet) || ...
        (isnumeric(node_sheet) && isscalar(node_sheet) && node_sheet >= 1 && mod(node_sheet,1) == 0))
    error('read_Network:InvalidNodeSheet', ...
        'NODE_SHEET must be a sheet name (text scalar) or positive integer sheet index.');
end

if ~(ischar(path_sheet) || isStringScalar(path_sheet) || ...
        (isnumeric(path_sheet) && isscalar(path_sheet) && path_sheet >= 1 && mod(path_sheet,1) == 0))
    error('read_Network:InvalidPathSheet', ...
        'PATH_SHEET must be a sheet name (text scalar) or positive integer sheet index.');
end

nodes = readtable(xsheetfile,'Sheet', node_sheet,Range = node_range);
paths = readtable(xsheetfile,'Sheet',path_sheet,Range = path_range);

requiredNodeCols = ["Node_name","Type","x","y","z"];
requiredPathCols = ["Starti","Endj","C"];

missingNodeCols = setdiff(requiredNodeCols, string(nodes.Properties.VariableNames));
if ~isempty(missingNodeCols)
    error('read_Network:MissingNodeColumns', ...
        'Node sheet is missing required columns: %s', strjoin(missingNodeCols, ', '));
end

missingPathCols = setdiff(requiredPathCols, string(paths.Properties.VariableNames));
if ~isempty(missingPathCols)
    error('read_Network:MissingPathColumns', ...
        'Path sheet is missing required columns: %s', strjoin(missingPathCols, ', '));
end

nodeCount = height(nodes);
nodeNames = string(nodes.Node_name);
if any(ismissing(nodeNames) | strlength(strtrim(nodeNames)) == 0)
    error('read_Network:InvalidNodeNames', ...
        'Node_name column contains missing or empty names.');
end

if numel(unique(nodeNames)) ~= numel(nodeNames)
    error('read_Network:DuplicateNodeNames', ...
        'Node_name values must be unique when Starti/Endj reference node names.');
end

startNames = string(paths.Starti);
endNames = string(paths.Endj);
if any(ismissing(startNames) | strlength(strtrim(startNames)) == 0 | ...
        ismissing(endNames) | strlength(strtrim(endNames)) == 0)
    error('read_Network:InvalidEdgeNodeNames', ...
        'Starti and Endj must contain non-empty node names.');
end

pathPairs = [startNames, endNames];
if size(unique(pathPairs, 'rows'), 1) ~= size(pathPairs, 1)
    error('read_Network:DuplicatePathPairs', ...
        'Path pairs (Starti, Endj) must be unique.');
end

[isStartKnown, startIdx] = ismember(startNames, nodeNames);
[isEndKnown, endIdx] = ismember(endNames, nodeNames);
if any(~isStartKnown) || any(~isEndKnown)
    unknownStart = unique(startNames(~isStartKnown));
    unknownEnd = unique(endNames(~isEndKnown));
    unknownNames = unique([unknownStart; unknownEnd]);
    error('read_Network:UnknownEdgeNodeNames', ...
        'Starti/Endj contains node names not found in Node_name: %s', strjoin(unknownNames, ', '));
end

G = graph(startIdx, endIdx, paths.C, nodeCount);

G.Nodes.Name = nodes.Node_name;
G.Nodes.Type = nodes.Type;
G.Nodes.x    = nodes.x;
G.Nodes.y    = nodes.y;
G.Nodes.z    = nodes.z;

N_cfgFields = ["BCL","SD","f1","f2","sigma1sq","sigma2sq","d2","ERP","d0",...
    "MDP","VT","VR","Vh","hr","hs","s","j","m","h","f","r"];
M_cfgFields = ["ax0","ay0","az0","ax1","ay1","az1","ax2","ay2","az2","ax3","ay3","az3",...
    "bx1","by1","bz1","VR","VT","VO","a","b","c","d","e"];
Path_cfgFields = ["CVi2j","Dij","aij","bij","cij","CVj2i","Dji","aji","bji","cji"];

nodeVarNames = string(nodes.Properties.VariableNames);

% Use explicit split headers (VT_n/VR_n and VT_m/VR_m) and map them to
% canonical cfg fields VT/VR in node cfg structs.
N_cfgSourceFields = N_cfgFields;
M_cfgSourceFields = M_cfgFields;
N_cfgSourceFields(N_cfgFields == "VT") = "VT_n";
N_cfgSourceFields(N_cfgFields == "VR") = "VR_n";
M_cfgSourceFields(M_cfgFields == "VT") = "VT_m";
M_cfgSourceFields(M_cfgFields == "VR") = "VR_m";

nodeNum = height(G.Nodes);
pathNum = height(G.Edges);
Nodes_cfg=cell(nodeNum,1);
Paths_cfg=cell(pathNum,1);
Dipoles = cell(pathNum,1);

node_type = upper(string(nodes.Type));

requiredNCfgFields = unique([setdiff(N_cfgFields, ["VT", "VR"]), "VT_n", "VR_n"]);
requiredMCfgFields = unique([setdiff(M_cfgFields, ["VT", "VR"]), "VT_m", "VR_m"]);
missingNCfg = setdiff(requiredNCfgFields, string(nodes.Properties.VariableNames));
if ~isempty(missingNCfg)
    error('read_Network:MissingNConfigColumns', ...
        'Node sheet is missing N config columns: %s', strjoin(missingNCfg, ', '));
end

missingMCfg = setdiff(requiredMCfgFields, string(nodes.Properties.VariableNames));
if ~isempty(missingMCfg)
    error('read_Network:MissingMConfigColumns', ...
        'Node sheet is missing M config columns: %s', strjoin(missingMCfg, ', '));
end

missingPathCfg = setdiff(Path_cfgFields, string(paths.Properties.VariableNames));
if ~isempty(missingPathCfg)
    error('read_Network:MissingPathConfigColumns', ...
        'Path sheet is missing path config columns: %s', strjoin(missingPathCfg, ', '));
end

validateMappedFieldsExist(nodeVarNames, N_cfgSourceFields, 'N');
validateMappedFieldsExist(nodeVarNames, M_cfgSourceFields, 'M');

% Open dictionaries and create empty, perfectly-ordered template structs
dict_N = Simulink.data.dictionary.open('N_dd.sldd');
template_N = Simulink.Bus.createMATLABStruct('Config_N', [], [1 1], dict_N);

dict_M = Simulink.data.dictionary.open('M_dd.sldd');
template_M = Simulink.Bus.createMATLABStruct('Config_M', [], [1 1], dict_M);

% NM uses buses from NM_dd.sldd
dict_NM = Simulink.data.dictionary.open('NM_dd.sldd');
template_NM_M = Simulink.Bus.createMATLABStruct('Config_M', [], [1 1], dict_NM);
template_NM_N = Simulink.Bus.createMATLABStruct('Config_N', [], [1 1], dict_NM);

parfor k = 1:nodeNum
    
    switch node_type(k)
        case "N"
            tempStruct = table2struct(nodes(k, N_cfgSourceFields));
            Nodes_cfg{k} = renameStructFields(tempStruct, N_cfgSourceFields, N_cfgFields, template_N);

        case "M"
            tempStruct = table2struct(nodes(k, M_cfgSourceFields));
            Nodes_cfg{k} = renameStructFields(tempStruct, M_cfgSourceFields, M_cfgFields, template_M);

        case "NM"
            NM_struct = struct;
            
            tempN = table2struct(nodes(k, N_cfgSourceFields));
            NM_struct.cfg_N = renameStructFields(tempN, N_cfgSourceFields, N_cfgFields, template_NM_N);
            
            tempM = table2struct(nodes(k, M_cfgSourceFields));
            NM_struct.cfg_M = renameStructFields(tempM, M_cfgSourceFields, M_cfgFields, template_NM_M);
            
            Nodes_cfg{k} = NM_struct;
        otherwise
            error('read_Network:UnsupportedNodeType', ...
                'Unsupported node type "%s" at row %d. Supported types are N, M, NM.', ...
                node_type(k), k);
    end
end

G.Nodes.cfg = Nodes_cfg;

for k = 1:pathNum

    Paths_cfg{k}=table2struct(paths(k, Path_cfgFields));

    iNode = startIdx(k);
    jNode = endIdx(k);
    Dipoles{k} = struct( ...
        'xi', G.Nodes.x(iNode), ...
        'yi', G.Nodes.y(iNode), ...
        'zi', G.Nodes.z(iNode), ...
        'xj', G.Nodes.x(jNode), ...
        'yj', G.Nodes.y(jNode), ...
        'zj', G.Nodes.z(jNode), ...
        'C',  paths.C(k));

end

G.Edges.pathCfg = Paths_cfg;
G.Edges.dipole = Dipoles;

end

function validateMappedFieldsExist(varNames, sourceFields, nodeTypeLabel)
missing = sourceFields(~ismember(sourceFields, varNames));
if ~isempty(missing)
    error('read_Network:MissingMappedConfigColumns', ...
        '%s config is missing mapped source columns: %s', ...
        nodeTypeLabel, strjoin(unique(missing), ', '));
end
end

function sOut = renameStructFields(sIn, sourceFields, targetFields, templateStruct)
    % 1. Start with the perfectly ordered template
    sOut = templateStruct;
    
    % 2. Map the data from the table into the template
    for i = 1:numel(sourceFields)
        src = char(sourceFields(i));
        dst = char(targetFields(i));
        sOut.(dst) = sIn.(src);
    end
end