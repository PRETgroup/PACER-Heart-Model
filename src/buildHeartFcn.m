function heart = buildHeartFcn(G,refmodules,settings)
%BUILDHEART Build a heart Simulink model from a network graph.
%   HEART = BUILDHEART(G, REFMODULES) builds a Simulink model from graph G,
%   which is typically produced by READ_NETWORK. Node, path, and electrode
%   instances are selected from REFMODULES and wired using the legacy heart
%   assembly pattern.
%
%   Inputs
%   ------
%   G : graph
%       Graph whose node table must contain Name, Type, x, y, z, and cfg.
%       Its edge table must contain pathCfg and preferably dipole.
%   REFMODULES : struct array
%       Module definitions with fields:
%       - module : source library block or referenced model name
%       - type   : "node", "path", or "electrode"
%       - mtype  : node subtype such as "N", "M", "NM", or module role
%
%   SETTINGS : struct (optional)
%       Build options. Supported fields:
%       - heartModel : generated top model name
%       - systemPath : save location
%       - standalone : add top-level I/O wrappers when true
%       - apTargetNodes : string/scalar or string array of AP target nodes
%       - vpTargetNodes : string/scalar or string array of VP target nodes
%
%   Output
%   ------
%   HEART : struct
%       Build metadata with fields model, subsystem, nodeSpecs, pathSpecs,
%       and electrodeSpecs.
%
%   Notes
%   -----
%   Simulink model mutation is performed serially because add_block,
%   add_line, and set_param are not safe to run in parallel. Independent
%   node/path/electrode specification assembly is parallelized when the
%   Parallel Computing Toolbox is available.
%
%   The graph G is treated as the source of truth for per-node cfg,
%   per-path pathCfg, and per-edge dipole data. The generated subsystem
%   exposes cfg, Leads, and Pace inputs.
%
%   Example
%   -------
%   % Step 1: Load the pre-built network graph
%   load('Data/heart_G.mat', 'G');
%
%   % Step 2: Define the reference model modules from /Lib
%   refmodules(1) = struct('module', 'Node_N', ...
%                          'type', 'node', 'mtype', 'N');
%   refmodules(2) = struct('module', 'Node_M', ...
%                          'type', 'node', 'mtype', 'M');
%   refmodules(3) = struct('module', 'Node_NM', ...
%                          'type', 'node', 'mtype', 'NM');
%   refmodules(4) = struct('module', 'Path_model', ...
%                          'type', 'path', 'mtype', 'straightLine');
%   refmodules(5) = struct('module', 'Electrode', ...
%                          'type', 'electrode', 'mtype', 'straightLine');
%
%   % Step 3: Build settings (optional)
%   settings = struct( ...
%      'heartModel', "test_build", ...
%      'apTargetNodes', ["RA"], ...
%      'vpTargetNodes', ["RVA"]);
%
%   % Step 4: Build the heart Simulink model
%   heart = buildHeartFcn(G, refmodules, settings);
%
%   % Step 5: Inspect the results
%   fprintf('Generated model: %s\n', heart.model);
%   fprintf('Subsystem path: %s\n', heart.subsystem);
%   fprintf('Network: %d nodes, %d paths\n', ...
%           numel(heart.nodeSpecs), numel(heart.pathSpecs));

if nargin < 3 || isempty(settings)
    settings = getBuildSettings();
else
    settings = normalizeBuildSettings(settings);
end

validateBuildInputs(G, refmodules);
moduleRefs = normalizeModules(refmodules);
loadModuleSources(moduleRefs);
heartModel = char(settings.modelName);
if bdIsLoaded(heartModel)
    close_system(heartModel, 0);
end
new_system(heartModel);

if settings.openModel
    open_system(heartModel);
end
configHeartModel(heartModel);
layout = getLayout();
%% Prepare the specs
nodeCount = numnodes(G);
pathCount = numedges(G);
nodeNames = string(G.Nodes.Name);
nodeTypes = upper(string(G.Nodes.Type));
nodeCoordinates = [G.Nodes.x, G.Nodes.y, G.Nodes.z];
validatePacingTargetNodes(settings, nodeNames);
[startIdx, endIdx] = findedge(G);
dipoles = getDipoles(G, startIdx, endIdx);
useParallel = canUseParallel(nodeCount, pathCount);

nodeSpecs = cell(nodeCount, 1);
if useParallel
    parfor nodeIdx = 1:nodeCount
        nodeSpecs{nodeIdx} = makeNodeSpec(nodeIdx, nodeNames(nodeIdx), ...
            nodeTypes(nodeIdx), moduleRefs, layout);
    end
else
    for nodeIdx = 1:nodeCount
        nodeSpecs{nodeIdx} = makeNodeSpec(nodeIdx, nodeNames(nodeIdx), ...
            nodeTypes(nodeIdx), moduleRefs, layout);
    end
end

pathSpecs = cell(pathCount, 1);
if useParallel
    parfor pathIdx = 1:pathCount
        pathSpecs{pathIdx} = makePathSpec(pathIdx, startIdx(pathIdx), ...
            endIdx(pathIdx), nodeNames, nodeCoordinates,  ...
            moduleRefs, layout);
    end
else
    for pathIdx = 1:pathCount
        pathSpecs{pathIdx} = makePathSpec(pathIdx, startIdx(pathIdx), ...
            endIdx(pathIdx), nodeNames, nodeCoordinates,  ...
            moduleRefs, layout);
    end
end

electrodeSpecs = cell(pathCount, 1);
if useParallel
    parfor pathIdx = 1:pathCount
        electrodeSpecs{pathIdx} = makeElectrodeSpec(pathIdx, pathSpecs{pathIdx}, ...
            dipoles{pathIdx}, moduleRefs, layout);
    end
else
    for pathIdx = 1:pathCount
        electrodeSpecs{pathIdx} = makeElectrodeSpec(pathIdx, pathSpecs{pathIdx}, ...
            dipoles{pathIdx}, moduleRefs, layout);
    end
end

jointTags = buildJointTags(pathSpecs, nodeCount);
parameterSpecs=[
    pathSpecs
    electrodeSpecs
    ];
%% assemble the models
heartSubsystem = createHeartContainer(heartModel, layout);
addNodeAssembly(heartSubsystem, nodeSpecs);
addPathAssembly(heartSubsystem, pathSpecs);
addElectrodeAssembly(heartSubsystem, electrodeSpecs);
addJointAssembly(heartSubsystem, nodeNames, jointTags, layout, settings);
addControlInputs(heartSubsystem, layout);
addOutputs(heartSubsystem, nodeSpecs, electrodeSpecs, nodeCount, pathCount, layout);
%%  link the dictionary to the model
attachDict(heartModel, settings.dictPath)
%%save parameters to the model workspace;
mdlWks=get_param(heartModel,"ModelWorkspace");
assignParameters(mdlWks,parameterSpecs)

if settings.standalone
    addStandaloneIo(heartModel, heartSubsystem, layout);
    assignin(mdlWks,"cfg",settings.cfg);
end

if strlength(settings.systemPath) > 0
    save_system(heartModel, fullfile(char(settings.systemPath), heartModel));
else
    save_system(heartModel);
end

heart = struct( ...
    'model', string(heartModel), ...
    'subsystem', string(heartSubsystem), ...
    'nodeSpecs', {nodeSpecs}, ...
    'pathSpecs', {pathSpecs}, ...
    'electrodeSpecs', {electrodeSpecs});
end
%----------------------------------------- helper functions -----


function validateBuildInputs(G, refmodules)
if ~isa(G, 'graph')
    error('buildHeart:InvalidGraph', 'G must be a MATLAB graph object.');
end

if ~isstruct(refmodules) || isempty(refmodules)
    error('buildHeart:InvalidModules', ...
        'REFMODULES must be a non-empty struct array.');
end

requiredRefFields = ["module", "type", "mtype"];
missingFields = setdiff(requiredRefFields, string(fieldnames(refmodules)));
if ~isempty(missingFields)
    error('buildHeart:MissingModuleFields', ...
        'REFMODULES is missing required fields: %s', strjoin(missingFields, ', '));
end

requiredNodeVars = ["Name", "Type", "cfg", "x", "y", "z"];
missingNodeVars = setdiff(requiredNodeVars, string(G.Nodes.Properties.VariableNames));
if ~isempty(missingNodeVars)
    error('buildHeart:MissingNodeVariables', ...
        'G.Nodes is missing required variables: %s', strjoin(missingNodeVars, ', '));
end

requiredEdgeVars = "pathCfg";
missingEdgeVars = setdiff(requiredEdgeVars, string(G.Edges.Properties.VariableNames));
if ~isempty(missingEdgeVars)
    error('buildHeart:MissingEdgeVariables', ...
        'G.Edges is missing required variables: %s', strjoin(missingEdgeVars, ', '));
end
end

function validatePacingTargetNodes(settings, nodeNames)
available = upper(string(nodeNames(:)));

apTargets = upper(string(settings.apTargetNodes(:)));
apTargets = apTargets(strlength(apTargets) > 0);
missingAp = setdiff(unique(apTargets), unique(available));
if ~isempty(missingAp)
    warning('buildHeart:MissingApTargetNodes', ...
        'AP target node(s) not found in G.Nodes.Name: %s', strjoin(cellstr(missingAp), ', '));
end

vpTargets = upper(string(settings.vpTargetNodes(:)));
vpTargets = vpTargets(strlength(vpTargets) > 0);
missingVp = setdiff(unique(vpTargets), unique(available));
if ~isempty(missingVp)
    warning('buildHeart:MissingVpTargetNodes', ...
        'VP target node(s) not found in G.Nodes.Name: %s', strjoin(cellstr(missingVp), ', '));
end
end

function moduleRefs = normalizeModules(refmodules)
moduleRefs = refmodules;
for idx = 1:numel(moduleRefs)
    moduleRefs(idx).module = string(moduleRefs(idx).module);
    moduleRefs(idx).type = lower(string(moduleRefs(idx).type));
    moduleRefs(idx).mtype = upper(string(moduleRefs(idx).mtype));
end
end

function loadModuleSources(moduleRefs)
sources = unique([string({moduleRefs.module})]);
roots = strings(size(sources));
for k = 1:numel(sources)
    if contains(sources(k), "/")
        roots(k) = extractBefore(sources(k), "/");
    else
        roots(k) = stripFileExtension(sources(k));
    end
end
roots = unique(roots);
for k = 1:numel(roots)
    load_system(char(roots(k)));
end
end

function dipoles = getDipoles(G, startIdx, endIdx)
edgeVars = string(G.Edges.Properties.VariableNames);
pathCount = numedges(G);
dipoles = cell(pathCount, 1);

if ismember("dipole", edgeVars)
    dipoles = G.Edges.dipole;
    return
end

for pathIdx = 1:pathCount
    dipoles{pathIdx} = struct( ...
        'xi', G.Nodes.x(startIdx(pathIdx)), ...
        'yi', G.Nodes.y(startIdx(pathIdx)), ...
        'zi', G.Nodes.z(startIdx(pathIdx)), ...
        'xj', G.Nodes.x(endIdx(pathIdx)), ...
        'yj', G.Nodes.y(endIdx(pathIdx)), ...
        'zj', G.Nodes.z(endIdx(pathIdx)), ...
        'C', G.Edges.Weight(pathIdx));
end
end

function layout = getLayout()
layout = struct( ...
    'topMargin', 30, ...
    'leftMargin', 110, ...
    'nodeSpacing', 125, ...
    'pathSpacing', 130, ...
    'tagSpacing', 26, ...
    'tagLength', 110, ...
    'tagWidth', 24, ...
    'containerSize', [260, 420], ...
    'nodeSize', [100, 72], ...
    'pathSize', [190, 96], ...
    'electrodeSize', [190, 96], ...
    'pathColumnOffset', 390, ...
    'electrodeColumnOffset', 900, ...
    'jointColumnOffset', 1380, ...
    'configColumnOffset', 1780, ...
    'outputColumnOffset', 2200);
end

function tf = canUseParallel(nodeCount, pathCount)
if nargin < 2
    nodeCount = 0;
    pathCount = 0;
end

% Avoid parfor startup overhead for small builds.
minWorkItems = 120;
workItems = nodeCount + 2 * pathCount;
tf = workItems >= minWorkItems && ...
    license('test', 'Distrib_Computing_Toolbox') && ...
    ~isempty(ver('parallel'));
end

function spec = makeNodeSpec(nodeIdx, nodeName, nodeType, moduleRefs, layout)
spec = struct;
spec.index = nodeIdx;
spec.name = char(nodeName);
spec.blockName = makeValidBlockName(nodeName);
spec.type = char(nodeType);
spec.module = resolveModule(moduleRefs, "node", nodeType);
spec.position = blockPosition(layout.leftMargin, layout.topMargin + ...
    (nodeIdx - 1) * layout.nodeSpacing, layout.nodeSize);
spec.cellTag = sprintf('c_%s', spec.name);
spec.pathTag = sprintf('gv_%s', spec.name);
spec.cfgBusBlockName = sprintf('cfg_%s', spec.name);
spec.cfgBusElement = spec.name;
end

function spec = makePathSpec(pathIdx, startNodeIdx, endNodeIdx, nodeNames, nodeCoordinates, moduleRefs, layout)
spec = struct;
spec.index = pathIdx;
spec.startNodeIdx = startNodeIdx;
spec.endNodeIdx = endNodeIdx;
spec.startNodeName = char(nodeNames(startNodeIdx));
spec.endNodeName = char(nodeNames(endNodeIdx));
spec.name = sprintf('%s_%s', spec.startNodeName, spec.endNodeName);
spec.blockName = makeValidBlockName(spec.name);
spec.module = resolveModule(moduleRefs, "path", "straightLine");
spec.position = blockPosition(layout.leftMargin + layout.pathColumnOffset, ...
    layout.topMargin + (pathIdx - 1) * layout.pathSpacing, layout.pathSize);
pathVector = nodeCoordinates(startNodeIdx, :) - nodeCoordinates(endNodeIdx, :);
pathLength = sqrt(sum(pathVector .^ 2));
spec.pathLength = pathLength;
spec.forwardTag = sprintf('%s_J_%s_%d', spec.startNodeName, spec.endNodeName,pathIdx);
spec.reverseTag = sprintf('%s_J_%s_%d', spec.endNodeName,spec.startNodeName,pathIdx);
spec.probeTag = sprintf('P_%d', pathIdx);
spec.cellITagName = sprintf('c_%s', spec.startNodeName);
spec.cellJTagName = sprintf('c_%s',spec.endNodeName);
spec.cellITagName_block = sprintf('c_%s_%d', spec.startNodeName,pathIdx);
spec.cellJTagName_block = sprintf('c_%s_%d',spec.endNodeName,pathIdx);
spec.cfgBusBlockName = sprintf('cfgPath_%d_%d', startNodeIdx, endNodeIdx);
spec.cfgBusElement = sprintf('path_%d', pathIdx);
spec.parameterBindings = pathParameterBindings(pathIdx, pathLength);
end

function spec = makeElectrodeSpec(pathIdx, pathSpec, dipole, moduleRefs, layout)
spec = struct;
spec.index = pathIdx;
spec.name = sprintf('%s_probe', pathSpec.name);
spec.blockName = makeValidBlockName(spec.name);
spec.module = resolveModule(moduleRefs, "electrode", "straightLine");
spec.position = blockPosition(layout.leftMargin + layout.electrodeColumnOffset, ...
    layout.topMargin + (pathIdx - 1) * layout.pathSpacing, layout.electrodeSize);
spec.pathTag = pathSpec.probeTag;
spec.egmTag = sprintf('EGM_%d', pathIdx);
spec.waveTag = sprintf('w_%d', pathIdx);
spec.dipole = dipole;
spec.parameterBindings = electrodeParameterBindings(pathIdx, dipole);
end

function bindings = pathParameterBindings(pathIdx, pathLength)
bindings(1)= makeParameterBinding('l',sprintf('l_%d',pathIdx),pathLength);
end

function bindings = electrodeParameterBindings(pathIdx, dipole)

fn = fieldnames(dipole);
n = numel(fn);

bindings(n) = makeParameterBinding("", "", []);

for i = 1:n
    bindings(i) = makeParameterBinding( ...
        fn{i}, ...
        sprintf('%s_%d', fn{i}, pathIdx), ...
        dipole.(fn{i}));
end

end

function binding = makeParameterBinding(parameterName, variableName, value)
binding = struct( ...
    'parameterName', char(parameterName), ...
    'variableName', char(variableName), ...
    'value', value);
end

function jointTags = buildJointTags(pathSpecs, nodeCount)
jointTags = cell(nodeCount, 1);
for pathIdx = 1:numel(pathSpecs)
    spec = pathSpecs{pathIdx};
    jointTags{spec.startNodeIdx} = [jointTags{spec.startNodeIdx}; {spec.reverseTag}];
    jointTags{spec.endNodeIdx} = [jointTags{spec.endNodeIdx}; {spec.forwardTag}];
end
end

function configHeartModel(heartModel)
%  Create the Configuration Reference
configRef = Simulink.ConfigSetRef();
configRef.Name = 'SharedConfigRef';
configRef.WSVarName = 'MasterConfig';

%  Attach the reference to the top-level model
attachConfigSet(heartModel, copy(configRef), true);
setActiveConfigSet(heartModel, 'SharedConfigRef');

end

function heartSubsystem = createHeartContainer(heartModel, layout)
blockName = sprintf('%s/Heart', heartModel);
add_block('simulink/Ports & Subsystems/Subsystem', blockName);
set_param(blockName, 'Position', blockPosition(layout.leftMargin, ...
    layout.topMargin, layout.containerSize));

heartSubsystem = sprintf('%s/Heart', heartModel);
delete_line(heartSubsystem, 'In1/1', 'Out1/1');
delete_block(sprintf('%s/In1', heartSubsystem));
delete_block(sprintf('%s/Out1', heartSubsystem));
end

function addNodeAssembly(heartSubsystem, nodeSpecs)
for idx = 1:numel(nodeSpecs)
    spec = nodeSpecs{idx};
    blockPath = sprintf('%s/%s', heartSubsystem, spec.blockName);
    addModuleBlock(spec.module, blockPath);
    set_param(blockPath, 'Position', spec.position);
    addConfigBusElementBlock(heartSubsystem, spec.cfgBusBlockName, spec.cfgBusElement, spec.position, 2, 1, ...
        spec.blockName, 1);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cfgBusBlockName), sprintf('%s/1', spec.blockName));

    addGotoBlock(heartSubsystem, spec.cellTag, spec.cellTag, spec.position, 1, 1, true);

    cellGotoPath = sprintf('%s/%s', heartSubsystem, spec.cellTag);
    gotoPos = get_param(cellGotoPath, 'Position');
    gotoShift = 45;
    set_param(cellGotoPath, 'Position', [gotoPos(1) + gotoShift, gotoPos(2), ...
        gotoPos(3) + gotoShift, gotoPos(4)]);

    delayName = sprintf('CellDelay_%s', spec.blockName);
    delayPath = sprintf('%s/%s', heartSubsystem, delayName);
    add_block('simulink/Discrete/Unit Delay', delayPath);
    set_param(delayPath, 'Position', [gotoPos(1), gotoPos(2), gotoPos(1) + 30, gotoPos(4)], ...
        'ShowName', 'off');

    addLineSafe(heartSubsystem, sprintf('%s/1', spec.blockName), sprintf('%s/1', delayName));
    addLineSafe(heartSubsystem, sprintf('%s/1', delayName), sprintf('%s/1', spec.cellTag));
    addFromBlock(heartSubsystem, spec.pathTag, spec.pathTag, spec.position, 2, 2, 2, ...
        spec.blockName, 2);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.pathTag), sprintf('%s/2', spec.blockName));
end
end

function addPathAssembly(heartSubsystem, pathSpecs)
for idx = 1:numel(pathSpecs)
    spec = pathSpecs{idx};
    blockPath = sprintf('%s/%s', heartSubsystem, spec.blockName);
    addModuleBlock(spec.module, blockPath);
    set_param(blockPath, 'Position', spec.position);
    applyParameterBindingsToBlock(blockPath, spec.parameterBindings);

    addConfigBusElementBlock(heartSubsystem, spec.cfgBusBlockName, spec.cfgBusElement, spec.position, 3, 1, ...
        spec.blockName, 1);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cfgBusBlockName), sprintf('%s/1', spec.blockName));

    addGotoBlock(heartSubsystem, spec.reverseTag, spec.reverseTag, spec.position, 3, 1, true);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.blockName), sprintf('%s/1', spec.reverseTag));

    addGotoBlock(heartSubsystem, spec.forwardTag, spec.forwardTag, spec.position, 3, 2, true);
    addLineSafe(heartSubsystem, sprintf('%s/2', spec.blockName), sprintf('%s/1', spec.forwardTag));

    addGotoBlock(heartSubsystem, spec.probeTag, spec.probeTag, spec.position, 3, 3, true);
    addLineSafe(heartSubsystem, sprintf('%s/3', spec.blockName), sprintf('%s/1', spec.probeTag));

    addFromBlock(heartSubsystem, spec.cellITagName_block, spec.cellITagName, ...
        spec.position, 3, 2, 2, spec.blockName, 2);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cellITagName_block), sprintf('%s/2', spec.blockName));

    addFromBlock(heartSubsystem, spec.cellJTagName_block, spec.cellJTagName,...
        spec.position, 3, 3, 3, spec.blockName, 3);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cellJTagName_block), sprintf('%s/3', spec.blockName));
end
end

function addElectrodeAssembly(heartSubsystem, electrodeSpecs)
for idx = 1:numel(electrodeSpecs)
    spec = electrodeSpecs{idx};
    blockPath = sprintf('%s/%s', heartSubsystem, spec.blockName);
    addModuleBlock(spec.module, blockPath);
    set_param(blockPath, 'Position', spec.position);
    applyParameterBindingsToBlock(blockPath, spec.parameterBindings); 
    addFromBlock(heartSubsystem, sprintf('FromPath_%d', spec.index), spec.pathTag, ...
        spec.position, 2, 1, 1, spec.blockName, 1);
    addLineSafe(heartSubsystem, sprintf('FromPath_%d/1', spec.index), sprintf('%s/1', spec.blockName));

    addFromBlock(heartSubsystem, sprintf('Leads_%d', spec.index), 'Leads', ...
        spec.position, 2, 2, 2, spec.blockName, 2);
    addLineSafe(heartSubsystem, sprintf('Leads_%d/1', spec.index), sprintf('%s/2', spec.blockName));
end
end

function addJointAssembly(heartSubsystem, nodeNames, jointTags, layout, settings)
orTop = 0;
for nodeIdx = 1:numel(jointTags)
    nodeTagList = jointTags{nodeIdx};
    nodeName = string(nodeNames(nodeIdx));
    isApNode = ismember(upper(nodeName), upper(settings.apTargetNodes));
    isVpNode = ismember(upper(nodeName), upper(settings.vpTargetNodes));
    extraInputs = double(isApNode) + double(isVpNode);
    totalInputs = numel(nodeTagList) + extraInputs;

    left = layout.leftMargin + layout.jointColumnOffset;
    top = layout.topMargin + orTop;
    orTop = orTop + layout.tagSpacing * max(totalInputs, 1) + 15;

    pathGotoName = sprintf('Path%d', nodeIdx);
    pathGotoPath = sprintf('%s/%s', heartSubsystem, pathGotoName);
    add_block('simulink/Signal Routing/Goto', pathGotoPath);

    sumBlockName = sprintf('Node%d_OR', nodeIdx);
    sumBlockPath = sprintf('%s/%s', heartSubsystem, sumBlockName);
    sumLeft = left + layout.tagLength + 20;
    pathGotoLeft = sumLeft + layout.tagWidth + 25;

    if totalInputs > 1
        centerY = top + (layout.tagSpacing * totalInputs / 2) - 10;
        add_block('simulink/Math Operations/Sum', sumBlockPath);
        set_param(sumBlockPath, 'Inputs', num2str(totalInputs), ...
            'Position', [sumLeft, centerY, sumLeft + layout.tagWidth, centerY + layout.tagWidth]);
        nodeGotoTag = sprintf('gv_%s', makeValidBlockName(nodeName));
        set_param(pathGotoPath, 'Position', [pathGotoLeft, centerY, pathGotoLeft + layout.tagLength, centerY + layout.tagWidth], ...
            'GotoTag', nodeGotoTag, 'ShowName', 'off');
    else
        centerY = top;
        nodeGotoTag = sprintf('gv_%s', makeValidBlockName(nodeName));
        set_param(pathGotoPath, 'Position', [pathGotoLeft, centerY, pathGotoLeft + layout.tagLength, centerY + layout.tagWidth], ...
            'GotoTag', nodeGotoTag, 'ShowName', 'off');
    end

    inputPort = 1;
    directSource = "";
    for tagIdx = 1:numel(nodeTagList)
        fromName = sprintf('Cell%d_%d', nodeIdx, tagIdx);
        fromPath = sprintf('%s/%s', heartSubsystem, fromName);
        add_block('simulink/Signal Routing/From', fromPath);
        set_param(fromPath, 'GotoTag', nodeTagList{tagIdx}, 'ShowName', 'off', ...
            'Position', [left, top + (tagIdx - 1) * layout.tagSpacing, ...
            left + layout.tagLength, top + (tagIdx - 1) * layout.tagSpacing + layout.tagWidth]);

        if totalInputs > 1
            addLineSafe(heartSubsystem, sprintf('%s/1', fromName), sprintf('%s/%d', sumBlockName, inputPort));
        else
            directSource = sprintf('%s/1', fromName);
        end
        inputPort = inputPort + 1;
    end

    pacingOffset = numel(nodeTagList);
    if isApNode
        [directSource, inputPort] = addPacingSource(heartSubsystem, 'AP', nodeIdx, left, top, ...
            pacingOffset, layout, totalInputs, sumBlockName, inputPort, directSource);
        pacingOffset = pacingOffset + 1;
    end
    if isVpNode
        if totalInputs > 1
            addPacingSource(heartSubsystem, 'VP', nodeIdx, left, top, ...
                pacingOffset, layout, totalInputs, sumBlockName, inputPort, directSource);
        else
            [directSource, ~] = addPacingSource(heartSubsystem, 'VP', nodeIdx, left, top, ...
                pacingOffset, layout, totalInputs, sumBlockName, inputPort, directSource);
        end
    end

    if totalInputs > 1
        addLineSafe(heartSubsystem, sprintf('%s/1', sumBlockName), sprintf('%s/1', pathGotoName));
    elseif totalInputs == 1
        addLineSafe(heartSubsystem, char(directSource), sprintf('%s/1', pathGotoName));
    else
        zeroName = sprintf('PathZero_%d', nodeIdx);
        zeroPath = sprintf('%s/%s', heartSubsystem, zeroName);
        add_block('simulink/Sources/Constant', zeroPath);
        set_param(zeroPath, 'Value', '0', 'ShowName', 'off', ...
            'Position', [left, top, left + 20, top + layout.tagWidth]);
        addLineSafe(heartSubsystem, sprintf('%s/1', zeroName), sprintf('%s/1', pathGotoName));
    end
end
end

function [directSource, inputPort] = addPacingSource(heartSubsystem, pacingTag, nodeIdx, left, top, ...
    baseInputCount, layout, totalInputs, sumBlockName, inputPort, directSource)
fromName = sprintf('%s_%d', pacingTag, nodeIdx);
fromPath = sprintf('%s/%s', heartSubsystem, fromName);
add_block('simulink/Signal Routing/From', fromPath);
set_param(fromPath, 'GotoTag', pacingTag, 'ShowName', 'off', ...
    'Position', [left, top + baseInputCount * layout.tagSpacing, ...
    left + layout.tagLength, top + baseInputCount * layout.tagSpacing + layout.tagWidth]);

if totalInputs > 1
    addLineSafe(heartSubsystem, sprintf('%s/1', fromName), sprintf('%s/%d', sumBlockName, inputPort));
else
    directSource = sprintf('%s/1', fromName);
end
inputPort = inputPort + 1;
end

function addControlInputs(heartSubsystem, layout)
left = layout.leftMargin + layout.configColumnOffset;

leadsGoto = sprintf('%s/Leads', heartSubsystem);
add_block('simulink/Signal Routing/Goto', leadsGoto);
set_param(leadsGoto, 'Position', [left + 20, layout.topMargin + 20, left + 20 + layout.tagLength, layout.topMargin + 20 + layout.tagWidth], ...
    'GotoTag', 'Leads', 'ShowName', 'off');

cfgLeads = sprintf('%s/cfgLeads', heartSubsystem);
existingCfgBlocks = find_system(heartSubsystem, 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^cfg_');
if isempty(existingCfgBlocks)
    add_block('simulink/Ports & Subsystems/In Bus Element', cfgLeads, ...
        'PortName', 'cfg', 'Element', 'Leads');
else
    add_block(existingCfgBlocks{1}, cfgLeads, 'MakeNameUnique', 'off');
    set_param(cfgLeads, 'Element', 'Leads');
end
set_param(cfgLeads, 'Position', [left - 65, layout.topMargin + 20, left - 15, layout.topMargin + 20 + layout.tagWidth], ...
    'ShowName', 'off');
addLineSafe(heartSubsystem, 'cfgLeads/1', 'Leads/1');

paceIn = sprintf('%s/Pace', heartSubsystem);
add_block('simulink/Sources/In1', paceIn);
set_param(paceIn, 'Position', [left - 65, layout.topMargin + 80, left - 15, layout.topMargin + 80 + layout.tagWidth]);

paceBlock = sprintf('%s/Pacing', heartSubsystem);
add_block('simulink/Signal Routing/Demux', paceBlock);
set_param(paceBlock, 'Position', [left, layout.topMargin + 65, left + 5, layout.topMargin + 125], 'Outputs', '2');
addLineSafe(heartSubsystem, 'Pace/1', 'Pacing/1');

apGoto = sprintf('%s/APin', heartSubsystem);
add_block('simulink/Signal Routing/Goto', apGoto);
set_param(apGoto, 'Position', [left + 20, layout.topMargin + 70, left + 20 + layout.tagLength, layout.topMargin + 70 + layout.tagWidth], ...
    'GotoTag', 'AP', 'ShowName', 'off');
addLineSafe(heartSubsystem, 'Pacing/1', 'APin/1');

vpGoto = sprintf('%s/VPin', heartSubsystem);
add_block('simulink/Signal Routing/Goto', vpGoto);
set_param(vpGoto, 'Position', [left + 20, layout.topMargin + 100, left + 20 + layout.tagLength, layout.topMargin + 100 + layout.tagWidth], ...
    'GotoTag', 'VP', 'ShowName', 'off');
addLineSafe(heartSubsystem, 'Pacing/2', 'VPin/1');
end

function addOutputs(heartSubsystem, nodeSpecs, electrodeSpecs, nodeCount, pathCount, layout)
left = layout.leftMargin + layout.outputColumnOffset;
cellsTemplateBlock = "";
wavesTemplateBlock = "";

for nodeIdx = 1:nodeCount
    nodeSpec = nodeSpecs{nodeIdx};
    cellTagBlockPath = sprintf('%s/%s', heartSubsystem, nodeSpec.cellTag);
    cellTagPos = get_param(cellTagBlockPath, 'Position');
    cellTagX = cellTagPos(1);
    cellTagY = cellTagPos(4) + 5;

    outBusName = sprintf('Cells_%s', nodeSpec.cellTag);
    cellsTemplateBlock = addCellsOutputBusElement(heartSubsystem, outBusName, nodeSpec.cellTag, ...
        cellTagX, cellTagY, cellsTemplateBlock);
    addLineSafe(heartSubsystem, sprintf('%s/1', nodeSpec.blockName), sprintf('%s/1', outBusName));
end

for pathIdx = 1:pathCount
    electrodeSpec = electrodeSpecs{pathIdx};
    y0 = electrodeSpec.position(2) + layout.tagWidth;

    % Add Goto label for EGM_i (placed right of electrode block)
    addGotoBlock(heartSubsystem, electrodeSpec.egmTag, electrodeSpec.egmTag, ...
        electrodeSpec.position, 2, 1, true);
    addLineSafe(heartSubsystem, sprintf('%s/1', electrodeSpec.blockName), ...
        sprintf('%s/1', electrodeSpec.egmTag));

    outBusName = sprintf('waves_%s', electrodeSpec.waveTag);
    wavesTemplateBlock = addOutputBusElementBlock(heartSubsystem, outBusName, 'waves', ...
        electrodeSpec.waveTag, electrodeSpec.blockName, 2, left, y0, wavesTemplateBlock);
    addLineSafe(heartSubsystem, sprintf('%s/2', electrodeSpec.blockName), sprintf('%s/1', outBusName));
end

% Sum all EGM_i via From labels and output as a single EGMs outport (port 2)
if pathCount > 0
    egmYPositions = zeros(pathCount, 1);
    for pathIdx = 1:pathCount
        egmYPositions(pathIdx) = electrodeSpecs{pathIdx}.position(2) + layout.tagWidth - layout.tagSpacing;
    end
    sumY = round(mean(egmYPositions));
    sumH = max(30, 14 * pathCount);
    sumBlockName = 'EGMs_Sum';
    sumBlockPath = sprintf('%s/%s', heartSubsystem, sumBlockName);
    inputsStr = repmat('+', 1, pathCount);
    sumPosition = [left, sumY - round(sumH/2), left + 30, sumY + round(sumH/2)];
    add_block('simulink/Math Operations/Add', sumBlockPath, ...
        'Inputs', inputsStr, ...
        'Position', sumPosition, ...
        'ShowName', 'off');
    for pathIdx = 1:pathCount
        electrodeSpec = electrodeSpecs{pathIdx};
        fromBlockName = sprintf('FromEGM_%d', pathIdx);
        addFromBlock(heartSubsystem, fromBlockName, electrodeSpec.egmTag, ...
            sumPosition, pathCount, pathIdx, pathIdx, sumBlockName, pathIdx);
        addLineSafe(heartSubsystem, sprintf('%s/1', fromBlockName), ...
            sprintf('%s/%d', sumBlockName, pathIdx));
    end
    egmsOutportPath = sprintf('%s/EGMs', heartSubsystem);
    outX = left + 50;
    add_block('simulink/Ports & Subsystems/Out1', egmsOutportPath, ...
        'Port', '2', ...
        'Position', [outX, sumY - 7, outX + 30, sumY + 7], ...
        'ShowName', 'on');
    addLineSafe(heartSubsystem, sprintf('%s/1', sumBlockName), 'EGMs/1');
end
end

function templateBlockPath = addCellsOutputBusElement(heartSubsystem, blockName, elementName, ...
    tagX, tagY, templateBlockPath)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);
if strlength(templateBlockPath) == 0
    existingOutBusBlocks = find_system(heartSubsystem, 'SearchDepth', 1, ...
        'Regexp', 'on', 'Name', '^Cells_');
else
    existingOutBusBlocks = {char(templateBlockPath)};
end

if isempty(existingOutBusBlocks)
    add_block('simulink/Ports & Subsystems/Out Bus Element', blockPath, ...
        'PortName', 'Cells', 'Element', elementName);
else
    add_block(existingOutBusBlocks{1}, blockPath, 'MakeNameUnique', 'off');
    set_param(blockPath, 'Element', elementName);
end
templateBlockPath = string(blockPath);

tagLength = computeTagLength(sprintf('Cells.%s', elementName));
left = tagX;
y0 = tagY;
%y0 = y0 + busElementVerticalNudge('Cells', elementName);

set_param(blockPath, 'Position', [left, y0, left + tagLength, y0 + 20], 'ShowName', 'off');
end

function templateBlockPath = addOutputBusElementBlock(heartSubsystem, blockName, ...
    portName, elementName, sourceBlockName, sourcePortIndex, fallbackLeft, ...
    fallbackY, templateBlockPath)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);
if strlength(templateBlockPath) == 0
    existingOutBusBlocks = find_system(heartSubsystem, 'SearchDepth', 1, ...
        'Regexp', 'on', 'Name', sprintf('^%s_', portName));
else
    existingOutBusBlocks = {char(templateBlockPath)};
end

if isempty(existingOutBusBlocks)
    add_block('simulink/Ports & Subsystems/Out Bus Element', blockPath, ...
        'PortName', portName, 'Element', elementName);
else
    add_block(existingOutBusBlocks{1}, blockPath, 'MakeNameUnique', 'off');
    set_param(blockPath, 'Element', elementName);
end
templateBlockPath = string(blockPath);

tagLength = computeTagLength(sprintf('%s.%s', portName, elementName));
[left, y0] = alignNearSourceOutport(heartSubsystem, sourceBlockName, sourcePortIndex, ...
    fallbackLeft, fallbackY, 20);
[left, y0] = shiftRightToAvoidOverlap(heartSubsystem, blockPath, left, y0, tagLength, 20);
%y0 = y0 + busElementVerticalNudge(portName, elementName);
set_param(blockPath, 'Position', [left, y0, left + tagLength, y0 + 20], 'ShowName', 'off');
end

function dy = busElementVerticalNudge(portName, elementName)
key = sprintf('%s.%s', char(portName), char(elementName));
switch key
    case {'cfg.SA', 'cfg.path_1', 'Cells.c_SA', 'waves.w_1'}
        dy = 5;
    otherwise
        dy = 0;
end
end

function dy = tagVerticalNudge(tagName)
switch string(tagName)
    case ["c_SA", "SA_a_J_SA_1"]
        dy = 5;
    otherwise
        dy = 0;
end
end

function addStandaloneIo(heartModel, heartSubsystem, layout)
containerPos = [layout.leftMargin, layout.topMargin, ...
    layout.leftMargin + layout.containerSize(1), layout.topMargin + layout.containerSize(2)];
heartPorts = get_param(heartSubsystem, 'PortHandles');

cfgInport = [];
paceInport = [];
cellsOutport = [];
egmsOutport = [];
wavesOutport = [];

if isfield(heartPorts, 'Inport') && numel(heartPorts.Inport) >= 1
    cfgInport = heartPorts.Inport(1);
end
if isfield(heartPorts, 'Inport') && numel(heartPorts.Inport) >= 2
    paceInport = heartPorts.Inport(2);
end
if isfield(heartPorts, 'Outport') && numel(heartPorts.Outport) >= 1
    cellsOutport = heartPorts.Outport(1);
end
if isfield(heartPorts, 'Outport') && numel(heartPorts.Outport) >= 2
    egmsOutport = heartPorts.Outport(2);
end
if isfield(heartPorts, 'Outport') && numel(heartPorts.Outport) >= 3
    wavesOutport = heartPorts.Outport(3);
end

addTopLevelTerminator(heartModel, 'TerminatorCells', cellsOutport, containerPos(3), layout.tagWidth);
addTopLevelTerminator(heartModel, 'TerminatorEGMs', egmsOutport, containerPos(3), layout.tagWidth);
addTopLevelTerminator(heartModel, 'TerminatorWaves', wavesOutport, containerPos(3), layout.tagWidth);

cfgIn = sprintf('%s/cfg', heartModel);
add_block('simulink/Sources/Constant', cfgIn);
set_param(cfgIn, 'Position', [layout.leftMargin - 100, containerPos(2) + layout.containerSize(2) / 4, ...
    layout.leftMargin - 50, containerPos(2) + layout.containerSize(2) / 4 + layout.tagWidth], ...
    'Value', 'cfg',  'OutDataTypeStr', 'Bus: HeartCfgBus','ShowName', 'off');

paceZero = sprintf('%s/PaceZero', heartModel);
add_block('simulink/Sources/Constant', paceZero);
set_param(paceZero, 'Position', [layout.leftMargin - 100, containerPos(2) + 3 * layout.containerSize(2) / 4, ...
    layout.leftMargin - 50, containerPos(2) + 3 * layout.containerSize(2) / 4 + layout.tagWidth], ...
    'Value', '[0 0]', 'ShowName', 'off');
pacePorts = get_param(paceZero, 'PortHandles');

if ~isempty(cfgInport)
    cfgPorts = get_param(cfgIn, 'PortHandles');
    add_line(heartModel, cfgPorts.Outport(1), cfgInport);
end

if ~isempty(paceInport)
    add_line(heartModel, pacePorts.Outport(1), paceInport);
end
end

function addTopLevelTerminator(heartModel, blockName, sourceOutportHandle, containerRight, tagWidth)
if isempty(sourceOutportHandle)
    return;
end

outportPos = get_param(sourceOutportHandle, 'Position');
y0 = outportPos(2) - tagWidth / 2;

termPath = sprintf('%s/%s', heartModel, blockName);
add_block('simulink/Sinks/Terminator', termPath);
set_param(termPath, 'Position', [containerRight + 50, y0, containerRight + 90, y0 + tagWidth]);

termPorts = get_param(termPath, 'PortHandles');
add_line(heartModel, sourceOutportHandle, termPorts.Inport(1));
end

function addModuleBlock(moduleSource, destinationBlock)
moduleSource = string(moduleSource);
modelName = modelNameFromSource(moduleSource);

if strlength(modelName) == 0 && contains(moduleSource, "/")
    add_block(char(moduleSource), destinationBlock);
    return;
end

if strlength(modelName) == 0
    modelName = stripFileExtension(moduleSource);
end

 refreshModelReferenceInterface(modelName);

try
    add_block('built-in/ModelReference', destinationBlock, ...
        'ModelName', char(modelName));
catch err
    if strcmp(err.identifier, 'Simulink:Commands:MalformedPortInterface') || ...
            contains(lower(err.message), 'port interface information is malformed')
        try
            Simulink.BlockDiagram.updateModelReferenceInterface(char(modelName));
            add_block('built-in/ModelReference', destinationBlock, ...
                'ModelName', char(modelName));
        catch
            addSubsystemFromModel(destinationBlock, modelName);
        end
    else
        rethrow(err);
    end
end
end

function refreshModelReferenceInterface(modelName)
if strlength(modelName) == 0
    return;
end

try
    load_system(char(modelName));
catch
    % If the model cannot be loaded here, let add_block throw a clearer error later.
    return;
end

try
    Simulink.BlockDiagram.updateModelReferenceInterface(char(modelName));
catch
    % Best effort only; addModuleBlock already has fallback paths.
end
end

function addSubsystemFromModel(destinationBlock, modelName)
add_block('simulink/Ports & Subsystems/Subsystem', destinationBlock);

defaultIn = sprintf('%s/In1', destinationBlock);
defaultOut = sprintf('%s/Out1', destinationBlock);

if exist_block(destinationBlock, 'In1') && exist_block(destinationBlock, 'Out1')
    delete_line(destinationBlock, 'In1/1', 'Out1/1');
    delete_block(defaultIn);
    delete_block(defaultOut);
end

Simulink.BlockDiagram.copyContentsToSubSystem(char(modelName), destinationBlock);
clearCopiedBusElementTypes(destinationBlock);
end

function clearCopiedBusElementTypes(destinationBlock)
candidateBlocks = find_system(destinationBlock, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'Regexp', 'on', 'Name', '^In Bus Element\d*$|^Out Bus Element\d*$');

for idx = 1:numel(candidateBlocks)
    clearBusElementTypeAttribute(candidateBlocks{idx});
end
end

function clearBusElementTypeAttribute(blockPath)
try
    currentType = string(get_param(blockPath, 'OutDataTypeStr'));
    if startsWith(currentType, "Bus:")
        set_param(blockPath, 'OutDataTypeStr', 'Inherit: auto');
    end
catch
end
end

function tf = exist_block(parentBlock, childBlock)
tf = ~isempty(find_system(parentBlock, 'SearchDepth', 1, 'Name', childBlock));
end

function modelName = modelNameFromSource(moduleSource)
moduleSource = string(moduleSource);
modelName = "";

if contains(moduleSource, "/")
    parts = split(moduleSource, "/");
    parts = parts(strlength(parts) > 0);
    if isempty(parts)
        return;
    end

    parent = "";
    if numel(parts) > 1
        parent = lower(parts(end - 1));
    end

    if parent == "lib"
        modelName = stripFileExtension(parts(end));
    end
end
end

function applyBlockConfiguration(blockPath, parameterName, parameterValue)
blockData = struct('parameterName', parameterName, 'parameterValue', parameterValue);
set_param(blockPath, 'UserData', blockData, 'UserDataPersistent', 'on');

parameterValueText = encodeParameterValue(parameterValue);

blockType = string(get_param(blockPath, 'BlockType'));
if any(blockType == ["ModelReference", "Model"])
    instanceParameters = get_param(blockPath, 'InstanceParameters');
    if isstruct(instanceParameters)
        parameterIndex = find(strcmp({instanceParameters.Name}, parameterName), 1, 'first');
        if ~isempty(parameterIndex)
            instanceParameters(parameterIndex).Value = parameterValueText;
            set_param(blockPath, 'InstanceParameters', instanceParameters);
            return;
        end
    end
end

dialogParameters = get_param(blockPath, 'DialogParameters');
if isstruct(dialogParameters) && isfield(dialogParameters, parameterName)
    set_param(blockPath, parameterName, parameterValueText);
end
end

function applyParameterBindingsToBlock(blockPath, bindings)
for idx = 1:numel(bindings)
    applyBlockConfiguration(blockPath, bindings(idx).parameterName, bindings(idx).variableName);
end
end


function addGotoBlock(heartSubsystem, blockName, gotoTag, referencePos, portCount, portIndex, placeRight)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);
add_block('simulink/Signal Routing/Goto', blockPath);

tagLength = computeTagLength(gotoTag);
[x0, y0] = tagPosition(referencePos, portCount, portIndex, placeRight, tagLength);
% y0 = y0 + tagVerticalNudge(gotoTag);
set_param(blockPath, 'Position', [x0, y0, x0 + tagLength, y0 + 20], ...
    'GotoTag', gotoTag, 'ShowName', 'off');
end

function addFromBlock(heartSubsystem, blockName, gotoTag, referencePos, portCount, portIndex, inputPort, varargin)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);
add_block('simulink/Signal Routing/From', blockPath);

tagLength = computeTagLength(gotoTag);
[x0, y0] = tagPosition(referencePos, portCount, portIndex, false, tagLength);
if inputPort > 1
    y0 = y0 + (portIndex - 1) * (referencePos(4) - referencePos(2)) / portCount;
end

targetBlockName = "";
targetPortIndex = inputPort;
if ~isempty(varargin)
    targetBlockName = string(varargin{1});
end
if numel(varargin) >= 2
    targetPortIndex = varargin{2};
end
y0 = alignToBlockInportY(heartSubsystem, targetBlockName, targetPortIndex, y0, 20);

set_param(blockPath, 'Position', [x0, y0, x0 + tagLength, y0 + 20], ...
    'GotoTag', gotoTag, 'ShowName', 'off');
end

function addConfigBusElementBlock(heartSubsystem, blockName, elementName, referencePos, portCount, portIndex, varargin)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);
existingCfgBlocks = find_system(heartSubsystem, 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^cfg_');

if isempty(existingCfgBlocks)
    add_block('simulink/Ports & Subsystems/In Bus Element', blockPath, ...
        'PortName', 'cfg', 'Element', char(elementName));
else
    add_block(existingCfgBlocks{1}, blockPath, 'MakeNameUnique', 'off');
    set_param(blockPath, 'Element', char(elementName));
end

tagLength = computeTagLength(sprintf('cfg.%s', char(elementName)));
[x0, y0] = tagPosition(referencePos, portCount, portIndex, false, tagLength);

targetBlockName = "";
targetPortIndex = portIndex;
if ~isempty(varargin)
    targetBlockName = string(varargin{1});
end
if numel(varargin) >= 2
    targetPortIndex = varargin{2};
end
y0 = alignToBlockInportY(heartSubsystem, targetBlockName, targetPortIndex, y0, 20);
%y0 = y0 + busElementVerticalNudge('cfg', elementName);

clearBusElementTypeAttribute(blockPath);
set_param(blockPath, 'Position', [x0, y0, x0 + tagLength, y0 + 20], 'ShowName', 'off');
end

function [x0, y0] = tagPosition(referencePos, portCount, portIndex, placeRight, tagLength)
blockWidth = referencePos(3) - referencePos(1);
blockHeight = referencePos(4) - referencePos(2);
initYOffset = (blockHeight / portCount) / 2 - 10;
tagGap = 15;
if placeRight
    x0 = referencePos(1) + blockWidth + tagGap;
else
    x0 = referencePos(1) - tagLength - tagGap;
end
y0 = referencePos(2) + initYOffset + (portIndex - 1) * (blockHeight / portCount);
end

function tagLength = computeTagLength(tagText)
tagText = string(tagText);
tagLength = max(75, double(16 + 7 * strlength(tagText)));
end

function y0 = alignToBlockInportY(heartSubsystem, blockName, portIndex, yFallback, blockHeight)
y0 = yFallback;
if strlength(blockName) == 0
    return;
end

targetBlockPath = sprintf('%s/%s', heartSubsystem, char(blockName));
try
    targetPorts = get_param(targetBlockPath, 'PortHandles');
    if isfield(targetPorts, 'Inport') && numel(targetPorts.Inport) >= portIndex
        inportPosition = get_param(targetPorts.Inport(portIndex), 'Position');
        if isnumeric(inportPosition) && numel(inportPosition) >= 2
            y0 = inportPosition(2) - blockHeight / 2;
        end
    end
catch
    y0 = yFallback;
end
end

function addLineSafe(systemName, src, dst)
try
    add_line(systemName, src, dst, 'autorouting', 'on');
catch err
    error('buildHeart:AddLineFailed', ...
        'Failed to connect %s to %s in %s: %s', src, dst, systemName, err.message);
end
end

function moduleSource = resolveModule(moduleRefs, moduleType, moduleSubtype)
% Normalize inputs once
targetType = lower(string(moduleType));
targetSubtype = upper(string(moduleSubtype));

% Extract fields as string arrays (vectorized)
types   = lower(string({moduleRefs.type}));
mtypes  = upper(string({moduleRefs.mtype}));

% Strict match only (NO fallback logic)
match = (types == targetType) & (mtypes == targetSubtype);
% Error if no match found
if ~any(match)
    error('buildHeart:MissingModule', ...
        'No module found for type %s and mtype %s.', ...
        moduleType, moduleSubtype);
end
% Deterministic selection (first match)
moduleSource = moduleRefs(find(match, 1, 'first')).module;
end

function valueText = encodeParameterValue(value)
if ischar(value)
    valueText = value;
elseif isstring(value) && isscalar(value)
    valueText = char(value);
else
    valueText = serializeToExpression(value);
end
end

function expr = serializeToExpression(value)
if isnumeric(value)
    expr = mat2str(value, 15);
    return;
end

if islogical(value)
    expr = sprintf('logical(%s)', mat2str(double(value), 15));
    return;
end

if ischar(value)
    expr = sprintf('''%s''', strrep(value, '''', ''''''));
    return;
end

if isstring(value)
    if isscalar(value)
        expr = sprintf('''%s''', strrep(char(value), '''', ''''''));
    else
        expr = sprintf('string(%s)', serializeToExpression(cellstr(value)));
    end
    return;
end

if iscell(value)
    if isempty(value)
        expr = '{}';
        return;
    end
    rowExpr = cell(size(value, 1), 1);
    for rowIdx = 1:size(value, 1)
        elemExpr = cell(1, size(value, 2));
        for colIdx = 1:size(value, 2)
            elemExpr{colIdx} = serializeToExpression(value{rowIdx, colIdx});
        end
        rowExpr{rowIdx} = strjoin(elemExpr, ', ');
    end
    expr = sprintf('{%s}', strjoin(rowExpr, '; '));
    return;
end

if isstruct(value)
    if isempty(value)
        expr = 'struct([])';
        return;
    end
    if ~isscalar(value)
        elemExpr = arrayfun(@serializeToExpression, value, 'UniformOutput', false);
        expr = sprintf('[%s]', strjoin(elemExpr, ', '));
        return;
    end

    fields = fieldnames(value);
    pairs = cell(1, 2 * numel(fields));
    for idx = 1:numel(fields)
        fieldName = fields{idx};
        pairs{2 * idx - 1} = sprintf('''%s''', fieldName);
        pairs{2 * idx} = serializeToExpression(value.(fieldName));
    end
    expr = sprintf('struct(%s)', strjoin(pairs, ', '));
    return;
end

error('buildHeart:UnsupportedParameterType', ...
    'Unsupported parameter type %s for expression encoding.', class(value));
end

function settings = getBuildSettings()
settings = struct( ...
    'modelName', defaultHeartModelName(), ...
    'dictPath',"",...
    'cfg',struct,...
    'systemPath', "", ...
    'standalone', true, ...
    'openModel', false, ...
    'apTargetNodes', "", ...
    'vpTargetNodes', "");
end

function settings = normalizeBuildSettings(userSettings)
settings = getBuildSettings();
optionNames = fieldnames(settings);
for idx = 1:numel(optionNames)
    optionName = optionNames{idx};
    if isfield(userSettings, optionName)
        settings.(optionName) = castBuildSetting(optionName, userSettings.(optionName));
    end
end

end

function value = castBuildSetting(optionName, value)
switch optionName
    case {'heartModel', 'systemPath'}
        value = string(value);
    case 'standalone'
        value = logical(value);
end
end

function modelName = defaultHeartModelName()
%This function generates a default Simulink model name that is guaranteed
% not to conflict with any existing model in the current MATLAB project.
proj = currentProject;
slxFiles = dir(fullfile(proj.RootFolder, "**", "*.slx"));
mdlFiles = dir(fullfile(proj.RootFolder, "**", "*.mdl"));
files = [slxFiles; mdlFiles];
modelNames = erase(string({files.name}), [".slx" ".mdl"]);
modelName = matlab.lang.makeUniqueStrings("Heart_default", modelNames);
end

function stripped = stripFileExtension(value)
[~, name, ext] = fileparts(char(value));
if isempty(ext)
    stripped = string(value);
else
    stripped = string(name);
end
end

function blockName = makeValidBlockName(value)
blockName = char(matlab.lang.makeValidName(string(value)));
end

function pos = blockPosition(left, top, sizeVec)
pos = [left, top, left + sizeVec(1), top + sizeVec(2)];
end

function [x0, y0] = alignNearSourceOutport(heartSubsystem, sourceBlockName, portIndex, ...
    xFallback, yFallback, blockHeight)
x0 = xFallback;
y0 = yFallback;

if strlength(sourceBlockName) == 0
    return;
end

sourceBlockPath = sprintf('%s/%s', heartSubsystem, char(sourceBlockName));
try
    sourcePos = get_param(sourceBlockPath, 'Position');
    if isnumeric(sourcePos) && numel(sourcePos) >= 4
        x0 = sourcePos(3) + 25;
    end

    sourcePorts = get_param(sourceBlockPath, 'PortHandles');
    if isfield(sourcePorts, 'Outport') && numel(sourcePorts.Outport) >= portIndex
        outportPosition = get_param(sourcePorts.Outport(portIndex), 'Position');
        if isnumeric(outportPosition) && numel(outportPosition) >= 2
            y0 = outportPosition(2) - blockHeight / 2;
        end
    end
catch
    x0 = xFallback;
    y0 = yFallback;
end
end

function [x0, y0] = shiftRightToAvoidOverlap(heartSubsystem, blockPath, x0, y0, blockWidth, blockHeight)
margin = 15;
maxIterations = 30;

for iter = 1:maxIterations
    changed = false;
    candidateRect = [x0, y0, x0 + blockWidth, y0 + blockHeight];
    blockList = find_system(heartSubsystem, 'SearchDepth', 1, 'Type', 'Block');

    for idx = 1:numel(blockList)
        otherBlockPath = blockList{idx};
        if strcmp(otherBlockPath, blockPath)
            continue;
        end

        otherPos = get_param(otherBlockPath, 'Position');
        if rectanglesOverlap(candidateRect, otherPos)
            x0 = otherPos(3) + margin;
            changed = true;
        end
    end

    if ~changed
        break;
    end
end
end

function tf = rectanglesOverlap(a, b)
tf = a(1) < b(3) && a(3) > b(1) && a(2) < b(4) && a(4) > b(2);
end

function attachDict(heartModel, dictPath)
dictPath = resolveHeartDictionaryPath(dictPath);
closeShadowingDictionariesForTarget(dictPath);
[dictFolder, dictName, dictExt] = fileparts(dictPath);
if strlength(string(dictFolder)) > 0
    addpath(dictFolder);
end
dictRef = string(strcat(dictName, dictExt));
%% Attach dictionary
set_param(...
    heartModel,...
    "DataDictionary",...
    dictRef);
set_param(heartModel, 'EnableAccessToBaseWorkspace', 'off');
end

function assignParameters(mdlWks,parameterSpecs)
%% Assign parameters
for i=1:numel(parameterSpecs)
    assignParameterBindings(...
        mdlWks,...
        parameterSpecs{i}.parameterBindings);
end

end
function assignParameterBindings(mdlWks,bindings)

for i=1:numel(bindings)
    name=bindings(i).variableName;
    if ~isvarname(name)
        error(...
            "Invalid variable name %s",...
            name);
    end

    assignin(...
        mdlWks,...
        name,...
        bindings(i).value);

end
end

function resolvedPath = resolveHeartDictionaryPath(dictPath)
requested = string(dictPath);
if isfile(char(requested))
   resolvedPath = char(requested);
   return;
end

proj = currentProject;
candidate = fullfile(proj.RootFolder, 'Data', 'sldd_system', char(requested));
if isfile(candidate)
   resolvedPath = candidate;
   return;
end

resolvedPath = char(requested);
end

function closeShadowingDictionariesForTarget(targetPath)
if ~isfile(targetPath)
   return;
end

[~, targetName, targetExt] = fileparts(targetPath);
targetFileName = lower(string(strcat(targetName, targetExt)));
targetPathNorm = lower(string(targetPath));

try
   openPaths = string(Simulink.data.dictionary.getOpenDictionaryPaths);
catch
   openPaths = strings(0, 1);
end

for idx = 1:numel(openPaths)
   openPath = string(openPaths(idx));
   [~, openName, openExt] = fileparts(char(openPath));
   openFileName = lower(string(strcat(openName, openExt)));

   if openFileName == targetFileName && lower(openPath) ~= targetPathNorm
      try
         openDd = Simulink.data.dictionary.open(char(openPath));
         close(openDd);
      catch
         % Best-effort close; if this fails, caller behavior remains unchanged.
      end
   end
end
end


