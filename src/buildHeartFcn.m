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
%       - modelPath : save location
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
layout = getLayout();
heartSubsystem = createHeartContainer(heartModel, layout);
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
pathSpecs = cell(pathCount, 1);
electrodeSpecs = cell(pathCount, 1);
if useParallel
    parfor nodeIdx = 1:nodeCount
        nodeSpecs{nodeIdx} = makeNodeSpec(nodeIdx, nodeNames(nodeIdx), ...
            nodeTypes(nodeIdx), moduleRefs, layout);
    end
    parfor pathIdx = 1:pathCount
        pathSpecs{pathIdx} = makePathSpec(pathIdx, startIdx(pathIdx), ...
            endIdx(pathIdx), nodeNames, nodeCoordinates,  ...
            moduleRefs, layout);
        electrodeSpecs{pathIdx} = makeElectrodeSpec(pathIdx, pathSpecs{pathIdx}, ...
            dipoles{pathIdx}, moduleRefs, layout);
    end
else
    for nodeIdx = 1:nodeCount
        nodeSpecs{nodeIdx} = makeNodeSpec(nodeIdx, nodeNames(nodeIdx), ...
            nodeTypes(nodeIdx), moduleRefs, layout);
    end
    for pathIdx = 1:pathCount
        pathSpecs{pathIdx} = makePathSpec(pathIdx, startIdx(pathIdx), ...
            endIdx(pathIdx), nodeNames, nodeCoordinates,  ...
            moduleRefs, layout);
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
addNodeAssembly(heartSubsystem, nodeSpecs);
addPathAssembly(heartSubsystem, pathSpecs);
addElectrodeAssembly(heartSubsystem, electrodeSpecs);
addJointAssembly(heartSubsystem, nodeNames, jointTags, layout, settings);
addControlInputs(heartSubsystem, layout);
addOutputs(heartSubsystem, nodeSpecs, electrodeSpecs, nodeCount, pathCount, layout);
%%save parameters to the model workspace;
mdlWks=get_param(heartModel,"ModelWorkspace");
assignParameters(mdlWks,parameterSpecs)

if settings.standalone
    addStandaloneIo(heartModel, heartSubsystem, layout);
end

if strlength(settings.modelPath) > 0
    save_system(heartModel, fullfile(currentProject().RootFolder,char(settings.modelPath), heartModel));
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
% Initialize the template tracker to bypass find_system inside the loop
cfgTemplate = "";
for idx = 1:numel(nodeSpecs)
    spec = nodeSpecs{idx};
    blockName = spec.blockName;
    cellTag = spec.cellTag;
    pathTag = spec.pathTag;

    blockPath = sprintf('%s/%s', heartSubsystem, blockName);
    delayName = sprintf('CellDelay_%s', blockName);
    delayPath = sprintf('%s/%s', heartSubsystem, delayName);
    cellGotoPath = sprintf('%s/%s', heartSubsystem, cellTag);

    addModuleBlock(spec.module, blockPath);
    set_param(blockPath, 'Position', spec.position);

    % Capture the template and pass it into the next iteration
    cfgTemplate = addConfigBusElementBlock(heartSubsystem, spec.cfgBusBlockName, ...
        spec.cfgBusElement, spec.position, 2, 1, cfgTemplate, spec.blockName, 1);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cfgBusBlockName), sprintf('%s/1', blockName));

    % --- OPTIMIZED LAYOUT SECTION ---

    % 1. Add Goto Block and capture its starting position immediately
    basePos = addGotoBlock(heartSubsystem, cellTag, cellTag, spec.position, 1, 1, true);

    % 2. Calculate the shifted position for the Goto block and position for the Delay
    gotoShift = 45;
    finalGotoPos = [basePos(1) + gotoShift, basePos(2), basePos(3) + gotoShift, basePos(4)];
    delayPos = [basePos(1), basePos(2), basePos(1) + 30, basePos(4)];

    % 3. Shift the Goto Block
    set_param(cellGotoPath, 'Position', finalGotoPos);

    % 4. Create the Unit Delay in its final spot instantly
    add_block('simulink/Discrete/Unit Delay', delayPath, ...
        'Position', delayPos, ...
        'ShowName', 'off');

    % --------------------------------

    addLineSafe(heartSubsystem, sprintf('%s/1', blockName), sprintf('%s/1', delayName));
    addLineSafe(heartSubsystem, sprintf('%s/1', delayName), sprintf('%s/1', cellTag));

    addFromBlock(heartSubsystem, pathTag, pathTag, spec.position, 2, 2, 2, blockName, 2);
    addLineSafe(heartSubsystem, sprintf('%s/1', pathTag), sprintf('%s/2', blockName));
end
end

function addPathAssembly(heartSubsystem, pathSpecs)
% Initialize the template tracker to bypass find_system inside the loop
cfgTemplate = "";
for idx = 1:numel(pathSpecs)
    spec = pathSpecs{idx};

    % Cache common properties to reduce struct lookups and memory overhead
    blockName = spec.blockName;
    pos = spec.position;
    blockPath = sprintf('%s/%s', heartSubsystem, blockName);

    % 1. Add the main module block
    addModuleBlock(spec.module, blockPath);
    set_param(blockPath, 'Position', pos);
    applyParameterBindingsToBlock(blockPath, spec.parameterBindings);

    % 2. Add Config Bus Element using the FAST template method
    % (Make sure addConfigBusElementBlock takes and returns cfgTemplate!)
    cfgTemplate = addConfigBusElementBlock(heartSubsystem, ...
        spec.cfgBusBlockName, spec.cfgBusElement, pos, 3, 1, ...
        cfgTemplate, blockName, 1);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cfgBusBlockName), sprintf('%s/1', blockName));

    % 3. Add Goto Blocks (Outputs)
    addGotoBlock(heartSubsystem, spec.reverseTag, spec.reverseTag, pos, 3, 1, true);
    addLineSafe(heartSubsystem, sprintf('%s/1', blockName), sprintf('%s/1', spec.reverseTag));

    addGotoBlock(heartSubsystem, spec.forwardTag, spec.forwardTag, pos, 3, 2, true);
    addLineSafe(heartSubsystem, sprintf('%s/2', blockName), sprintf('%s/1', spec.forwardTag));

    addGotoBlock(heartSubsystem, spec.probeTag, spec.probeTag, pos, 3, 3, true);
    addLineSafe(heartSubsystem, sprintf('%s/3', blockName), sprintf('%s/1', spec.probeTag));

    % 4. Add From Blocks (Inputs)
    addFromBlock(heartSubsystem, spec.cellITagName_block, spec.cellITagName, pos, 3, 2, 2, blockName, 2);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cellITagName_block), sprintf('%s/2', blockName));

    addFromBlock(heartSubsystem, spec.cellJTagName_block, spec.cellJTagName, pos, 3, 3, 3, blockName, 3);
    addLineSafe(heartSubsystem, sprintf('%s/1', spec.cellJTagName_block), sprintf('%s/3', blockName));
end
end

function addElectrodeAssembly(heartSubsystem, electrodeSpecs)
% Cache constant tags outside the loop
leadsTag = 'Leads';

for idx = 1:numel(electrodeSpecs)
    spec = electrodeSpecs{idx};

    % 1. Cache properties to avoid repeated MATLAB struct dereferencing
    blockName = spec.blockName;
    pos = spec.position;
    idxNum = spec.index;

    blockPath = sprintf('%s/%s', heartSubsystem, blockName);

    % 2. Create and configure the main module
    addModuleBlock(spec.module, blockPath);
    set_param(blockPath, 'Position', pos);
    applyParameterBindingsToBlock(blockPath, spec.parameterBindings);

    % 3. Pre-format names to eliminate duplicate sprintf calls
    fromPathName = sprintf('FromPath_%d', idxNum);
    leadsName = sprintf('Leads_%d', idxNum);

    % 4. Add From blocks and route lines using cached strings
    addFromBlock(heartSubsystem, fromPathName, spec.pathTag, pos, 2, 1, 1, blockName, 1);
    addLineSafe(heartSubsystem, sprintf('%s/1', fromPathName), sprintf('%s/1', blockName));

    addFromBlock(heartSubsystem, leadsName, leadsTag, pos, 2, 2, 2, blockName, 2);
    addLineSafe(heartSubsystem, sprintf('%s/1', leadsName), sprintf('%s/2', blockName));
end
end

function addJointAssembly(heartSubsystem, nodeNames, jointTags, layout, settings)
orTop = 0;

% 1. MASSIVE OPTIMIZATION: Convert arrays to uppercase ONCE outside the loop
apTargets = upper(string(settings.apTargetNodes));
vpTargets = upper(string(settings.vpTargetNodes));

% 2. Cache layout struct values to prevent repeated memory lookups
lLeft       = layout.leftMargin;
lTop        = layout.topMargin;
lColOffset  = layout.jointColumnOffset;
lTagSpacing = layout.tagSpacing;
lTagWidth   = layout.tagWidth;
lTagLength  = layout.tagLength;

for nodeIdx = 1:numel(jointTags)
    nodeTagList = jointTags{nodeIdx};
    nodeName = string(nodeNames(nodeIdx));

    % Fast string comparison
    upperNodeName = upper(nodeName);
    isApNode = ismember(upperNodeName, apTargets);
    isVpNode = ismember(upperNodeName, vpTargets);

    extraInputs = double(isApNode) + double(isVpNode);
    totalInputs = numel(nodeTagList) + extraInputs;

    left = lLeft + lColOffset;
    top = lTop + orTop;
    orTop = orTop + lTagSpacing * max(totalInputs, 1) + 15;

    pathGotoName = sprintf('Path%d', nodeIdx);
    pathGotoPath = sprintf('%s/%s', heartSubsystem, pathGotoName);

    sumLeft = left + lTagLength + 20;
    pathGotoLeft = sumLeft + lTagWidth + 25;
    nodeGotoTag = sprintf('gv_%s', makeValidBlockName(nodeName));

    % 3. Create Sum and Goto Blocks in a SINGLE step (No set_param)
    if totalInputs > 1
        centerY = top + (lTagSpacing * totalInputs / 2) - 10;
        sumBlockName = sprintf('Node%d_OR', nodeIdx);
        sumBlockPath = sprintf('%s/%s', heartSubsystem, sumBlockName);

        add_block('simulink/Math Operations/Sum', sumBlockPath, ...
            'Inputs', num2str(totalInputs), ...
            'Position', [sumLeft, centerY, sumLeft + lTagWidth, centerY + lTagWidth]);
    else
        centerY = top;
        sumBlockName = ""; % Initialize to prevent reference errors later
    end

    add_block('simulink/Signal Routing/Goto', pathGotoPath, ...
        'Position', [pathGotoLeft, centerY, pathGotoLeft + lTagLength, centerY + lTagWidth], ...
        'GotoTag', nodeGotoTag, ...
        'ShowName', 'off');

    inputPort = 1;
    directSource = "";

    % 4. Create From blocks in a SINGLE step
    for tagIdx = 1:numel(nodeTagList)
        fromName = sprintf('Cell%d_%d', nodeIdx, tagIdx);
        fromPath = sprintf('%s/%s', heartSubsystem, fromName);
        fromTop = top + (tagIdx - 1) * lTagSpacing;

        add_block('simulink/Signal Routing/From', fromPath, ...
            'GotoTag', nodeTagList{tagIdx}, ...
            'Position', [left, fromTop, left + lTagLength, fromTop + lTagWidth], ...
            'ShowName', 'off');

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

    % Route final output or Handle Zero-Input Edge Case seamlessly
    if totalInputs > 1
        addLineSafe(heartSubsystem, sprintf('%s/1', sumBlockName), sprintf('%s/1', pathGotoName));
    elseif totalInputs == 1
        addLineSafe(heartSubsystem, char(directSource), sprintf('%s/1', pathGotoName));
    else
        zeroName = sprintf('PathZero_%d', nodeIdx);
        zeroPath = sprintf('%s/%s', heartSubsystem, zeroName);

        add_block('simulink/Sources/Constant', zeroPath, ...
            'Value', '0', ...
            'Position', [left, top, left + 20, top + lTagWidth], ...
            'ShowName', 'off');

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

leadsGoto = sprintf('%s/LeadsGoto', heartSubsystem);
add_block('simulink/Signal Routing/Goto', leadsGoto);
set_param(leadsGoto, 'Position', [left + 20, layout.topMargin + 20, left + 20 + layout.tagLength, layout.topMargin + 20 + layout.tagWidth], ...
    'GotoTag', 'Leads', 'ShowName', 'off');

add_block('simulink/Sources/In1', sprintf('%s/Leads', heartSubsystem), ...
    'Port', '2', ...
    'Position', [left - 65, layout.topMargin + 20, left - 15, layout.topMargin + 20 + layout.tagWidth]);
addLineSafe(heartSubsystem, 'Leads/1', 'LeadsGoto/1');

paceIn = sprintf('%s/Pace', heartSubsystem);
add_block('simulink/Sources/In1', paceIn, ...
    'Port', '3', ...
    'Position', [left - 65, layout.topMargin + 80, left - 15, layout.topMargin + 80 + layout.tagWidth]);

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

% --- Optimization: Pre-check or create template block sources once ---
cellsTemplateBlock = "";
existingCells = find_system(heartSubsystem, 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^Cells_');
if ~isempty(existingCells)
    cellsTemplateBlock = string(existingCells{1});
end

wavesTemplateBlock = "";
existingWaves = find_system(heartSubsystem, 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^waves_');
if ~isempty(existingWaves)
    wavesTemplateBlock = string(existingWaves{1});
end

for nodeIdx = 1:nodeCount
    nodeSpec = nodeSpecs{nodeIdx};
    cellTagBlockPath = sprintf('%s/%s', heartSubsystem, nodeSpec.cellTag);
    cellTagPos = get_param(cellTagBlockPath, 'Position');
    cellTagX = cellTagPos(1);
    cellTagY = cellTagPos(4) + 5;

    outBusName = sprintf('Cells_%s', nodeSpec.cellTag);
    [cellsTemplateBlock, ~] = addCellsOutputBusElement(heartSubsystem, outBusName, nodeSpec.cellTag, ...
        cellTagX, cellTagY, cellsTemplateBlock);
    addLineSafe(heartSubsystem, sprintf('%s/1', nodeSpec.blockName), sprintf('%s/1', outBusName));
end

for pathIdx = 1:pathCount
    electrodeSpec = electrodeSpecs{pathIdx};
    y0 = electrodeSpec.position(2) + layout.tagWidth;

    % Add Goto label for EGM_i
    addGotoBlock(heartSubsystem, electrodeSpec.egmTag, electrodeSpec.egmTag, ...
        electrodeSpec.position, 2, 1, true);
    addLineSafe(heartSubsystem, sprintf('%s/1', electrodeSpec.blockName), ...
        sprintf('%s/1', electrodeSpec.egmTag));

    outBusName = sprintf('waves_%s', electrodeSpec.waveTag);
    [wavesTemplateBlock, ~] = addOutputBusElementBlock(heartSubsystem, outBusName, 'waves', ...
        electrodeSpec.waveTag, electrodeSpec.blockName, 2, left, y0, wavesTemplateBlock);
    addLineSafe(heartSubsystem, sprintf('%s/2', electrodeSpec.blockName), sprintf('%s/1', outBusName));
end

% Summation logic remains unchanged...
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

function [templateBlockPath, blockPath] = addCellsOutputBusElement(heartSubsystem, blockName, elementName, ...
    tagX, tagY, templateBlockPath)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);

if strlength(templateBlockPath) == 0 || ~bdIsLoaded(extractBefore(templateBlockPath, '/'))
    add_block('simulink/Ports & Subsystems/Out Bus Element', blockPath, ...
        'PortName', 'Cells', 'Element', elementName);
    templateBlockPath = string(blockPath);
else
    add_block(char(templateBlockPath), blockPath, 'MakeNameUnique', 'off');
    set_param(blockPath, 'Element', elementName);
end

tagLength = computeTagLength(sprintf('Cells.%s', elementName));
set_param(blockPath, 'Position', [tagX, tagY, tagX + tagLength, tagY + 20], 'ShowName', 'off');
end

function [templateBlockPath, blockPath] = addOutputBusElementBlock(heartSubsystem, blockName, ...
    portName, elementName, sourceBlockName, sourcePortIndex, fallbackLeft, ...
    fallbackY, templateBlockPath)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);

if strlength(templateBlockPath) == 0 || ~bdIsLoaded(extractBefore(templateBlockPath, '/'))
    add_block('simulink/Ports & Subsystems/Out Bus Element', blockPath, ...
        'PortName', portName, 'Element', elementName);
    templateBlockPath = string(blockPath);
else
    add_block(char(templateBlockPath), blockPath, 'MakeNameUnique', 'off');
    set_param(blockPath, 'Element', elementName);
end

tagLength = computeTagLength(sprintf('%s.%s', portName, elementName));
[left, y0] = alignNearSourceOutport(heartSubsystem, sourceBlockName, sourcePortIndex, ...
    fallbackLeft, fallbackY, 20);
[left, y0] = shiftRightToAvoidOverlap(heartSubsystem, blockPath, left, y0, tagLength, 20);
set_param(blockPath, 'Position', [left, y0, left + tagLength, y0 + 20], 'ShowName', 'off');
end

function addStandaloneIo(heartModel, heartSubsystem, layout)
containerPos = [layout.leftMargin, layout.topMargin, ...
    layout.leftMargin + layout.containerSize(1), layout.topMargin + layout.containerSize(2)];
heartPorts = get_param(heartSubsystem, 'PortHandles');

cfgInport = [];
leadsInport = [];
paceInport = [];
cellsOutport = [];
egmsOutport = [];
wavesOutport = [];

if isfield(heartPorts, 'Inport') && numel(heartPorts.Inport) >= 1
    cfgInport = heartPorts.Inport(1);
end
if isfield(heartPorts, 'Inport') && numel(heartPorts.Inport) >= 2
    leadsInport = heartPorts.Inport(2);
end
if isfield(heartPorts, 'Inport') && numel(heartPorts.Inport) >= 3
    paceInport = heartPorts.Inport(3);
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
    'Value', 'HeartCfg',  'OutDataTypeStr', 'Bus: HeartCfgBus','ShowName', 'off');

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

leadsIn = sprintf('%s/Leads', heartModel);
add_block('simulink/Sources/Constant', leadsIn);
set_param(leadsIn, 'Position', [layout.leftMargin - 100, containerPos(2) + layout.containerSize(2) / 2, ...
    layout.leftMargin - 50, containerPos(2) + layout.containerSize(2) / 2 + layout.tagWidth], ...
    'Value', 'Leads', 'OutDataTypeStr', 'Bus: Lead_group', 'ShowName', 'off');
if ~isempty(leadsInport)
    leadsPorts = get_param(leadsIn, 'PortHandles');
    add_line(heartModel, leadsPorts.Outport(1), leadsInport);
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
moduleSourceStr = string(moduleSource);

% Fast-path for standard library blocks or subsystems (e.g., 'simulink/Sources/In1')
if contains(moduleSourceStr, "/")
    add_block(char(moduleSourceStr), destinationBlock);
    return;
end

% Process as a Model Reference
modelName = modelNameFromSource(moduleSourceStr);
if strlength(modelName) == 0
    modelName = stripFileExtension(moduleSourceStr);
end

% Add the model reference block directly.
% (We trust the interface was updated during the initial load phase).
add_block('built-in/ModelReference', destinationBlock, ...
    'ModelName', char(modelName));
end

function loadModuleSources(moduleRefs)
sources = unique([string({moduleRefs.module})]);

for k = 1:numel(sources)
    % Only process Model References (skip library paths with '/')
    if ~contains(sources(k), "/")
        modelName = stripFileExtension(sources(k));

        % Load the model and update its interface ONCE
        load_system(char(modelName));
        Simulink.BlockDiagram.refreshBlocks(char(modelName));
    else
        % Just load the library
        load_system(char(extractBefore(sources(k), "/")));
    end
end
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

function applyParameterBindingsToBlock(blockPath, bindings)
if isempty(bindings)
    return;
end

% 1. Get block metadata ONCE
blockType = get_param(blockPath, 'BlockType');
isModelRef = strcmp(blockType, 'ModelReference') || strcmp(blockType, 'Model');

% Prepare memory structures for batch updates
nvPairs = {}; % For batching standard Dialog parameters
userDataArray = struct('parameterName', cell(1, numel(bindings)), 'parameterValue', cell(1, numel(bindings)));

% Fetch Instance and Dialog parameters exactly ONCE
instParams = [];
instNames = {};
if isModelRef
    instParams = get_param(blockPath, 'InstanceParameters');
    if isstruct(instParams)
        instNames = {instParams.Name}; % Cache names for blazing fast lookups
    end
end

dlgParams = get_param(blockPath, 'DialogParameters');
isDlgStruct = isstruct(dlgParams);

instParamsChanged = false;

% 2. Process all bindings in memory (No Simulink API calls here!)
for idx = 1:numel(bindings)
    pName = bindings(idx).parameterName;
    pVal  = bindings(idx).variableName; % Note: original mapped variableName to parameterValue

    pValText = encodeParameterValue(pVal);

    % Fix the UserData bug: save ALL bindings in an array
    userDataArray(idx).parameterName = pName;
    userDataArray(idx).parameterValue = pVal;

    appliedToInstance = false;

    % Check and update Instance Parameters in memory
    if ~isempty(instNames)
        matchIdx = find(strcmp(instNames, pName), 1, 'first');
        if ~isempty(matchIdx)
            instParams(matchIdx).Value = pValText;
            instParamsChanged = true;
            appliedToInstance = true;
        end
    end

    % If not an Instance Parameter, prep it for a batched set_param
    if ~appliedToInstance && isDlgStruct && isfield(dlgParams, pName)
        nvPairs{end+1} = pName;
        nvPairs{end+1} = pValText;
    end
end

% 3. Push updates to Simulink in the minimum possible API calls

% Write InstanceParameters back (1 call instead of N)
if instParamsChanged
    set_param(blockPath, 'InstanceParameters', instParams);
end

% Write ALL standard DialogParameters simultaneously (1 call instead of N)
if ~isempty(nvPairs)
    set_param(blockPath, nvPairs{:});
end

% Write the fixed, complete UserData array (1 call instead of N)
set_param(blockPath, 'UserData', userDataArray, 'UserDataPersistent', 'on');
end

function pos = addGotoBlock(heartSubsystem, blockName, gotoTag, referencePos, portCount, portIndex, placeRight)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);

% 1. Calculate position BEFORE creating the block
tagLength = computeTagLength(gotoTag);
[x0, y0] = tagPosition(referencePos, portCount, portIndex, placeRight, tagLength);
pos = [x0, y0, x0 + tagLength, y0 + 20];

% 2. Create the block and set ALL properties in one API call
add_block('simulink/Signal Routing/Goto', blockPath, ...
    'Position', pos, ...
    'GotoTag', gotoTag, ...
    'ShowName', 'off');
end

function addFromBlock(heartSubsystem, blockName, gotoTag, referencePos, portCount, portIndex, inputPort, varargin)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);
% 1. Calculate layout and alignment BEFORE touching the Simulink API
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
finalPos = [x0, y0, x0 + tagLength, y0 + 20];
% 2. Create the block and set ALL properties in one step
add_block('simulink/Signal Routing/From', blockPath, ...
    'Position', finalPos, ...
    'GotoTag', gotoTag, ...
    'ShowName', 'off');
end

function templateBlockPath = addConfigBusElementBlock(heartSubsystem, blockName, elementName, referencePos, portCount, portIndex, templateBlockPath, varargin)
blockPath = sprintf('%s/%s', heartSubsystem, blockName);

% (Layout math remains the exact same as above)
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
finalPos = [x0, y0, x0 + tagLength, y0 + 20];

% --- THE FIX ---
    % If the template is empty (e.g., at the start of addPathAssembly), 
    % check the model ONCE to see if addNodeAssembly already created one.
    if strlength(templateBlockPath) == 0
        existingCfgBlocks = find_system(heartSubsystem, 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^cfg_');
        if ~isempty(existingCfgBlocks)
            templateBlockPath = string(existingCfgBlocks{1});
        end
    end
% NO MORE FIND_SYSTEM! Check the cached string instead.
if strlength(templateBlockPath) == 0
    add_block('simulink/Ports & Subsystems/In Bus Element', blockPath, ...
        'PortName', 'cfg', 'Element', char(elementName), ...
        'Position', finalPos, 'ShowName', 'off', ...
        'OutDataTypeStr', 'Inherit: auto');
    templateBlockPath = string(blockPath); % Save the first one we make
else
    add_block(char(templateBlockPath), blockPath, ...
        'MakeNameUnique', 'off', 'Element', char(elementName), ...
        'Position', finalPos, 'ShowName', 'off', ...
        'OutDataTypeStr', 'Inherit: auto');
end

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
% 1. Fast exit for empty block names (using native string comparison)
if isempty(blockName) || blockName == ""
    return;
end
targetBlockPath = sprintf('%s/%s', heartSubsystem, blockName);
try
    % 2. Get port handles (Simulink always includes the 'Inport' field)
    targetPorts = get_param(targetBlockPath, 'PortHandles');
    inports = targetPorts.Inport;
    % 3. Verify the requested port index actually exists on the block
    if portIndex <= numel(inports)
        % 4. Retrieve position directly (Simulink always returns [x, y])
        inportPos = get_param(inports(portIndex), 'Position');
        % Calculate aligned Y position
        y0 = inportPos(2) - (blockHeight / 2);
    end
catch
    % Silently fall back to yFallback if the block doesn't exist yet
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
    'modelPath', "models", ...
    'standalone', true, ...
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
    case {'heartModel', 'modelPath'}
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




