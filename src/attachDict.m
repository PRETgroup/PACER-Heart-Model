function attachDict(heartModel, slddHeart)
dictPath = resolveHeartDictionaryPath(slddHeart);
closeShadowingDictionariesForTarget(slddHeart);
[dictFolder, dictName, dictExt] = fileparts(dictPath);
if strlength(string(dictFolder)) > 0
    addpath(dictFolder);
end
dictRef = string(strcat(dictName, dictExt));
if ~bdIsLoaded(heartModel)
    load_system(heartModel)
end
%% Attach dictionary
set_param(...
    heartModel,...
    "DataDictionary",...
    dictRef);
set_param(heartModel, 'EnableAccessToBaseWorkspace', 'off');

dictObj = Simulink.data.dictionary.open(dictPath);
sectObj = getSection(dictObj, 'Configurations');
entries = find(sectObj);

if numel(entries) ~= 1
    error('Expected exactly one entry in the Configurations section, but found %d.', numel(entries));
else
    configName = entries.Name;
    % Remove existing SharedConfigRef if it exists
    configSets = getConfigSets(heartModel);

    if any(strcmp(configSets, "SharedConfigRef"))

        % If it is active, switch to another configuration set first
        activeName = getActiveConfigSet(heartModel).Name;

        if strcmp(activeName, "SharedConfigRef")
            % Select another existing configuration set
            otherNames = configSets(~strcmp(configSets, "SharedConfigRef"));

            if isempty(otherNames)
                error("Cannot remove SharedConfigRef because it is the only configuration set.");
            end

            setActiveConfigSet(heartModel, otherNames{1});
        end

        detachConfigSet(heartModel, "SharedConfigRef");
    end

    % Create the new Configuration Reference
    configRef = Simulink.ConfigSetRef();
    configRef.Name = "SharedConfigRef";
    configRef.SourceName = configName;

    % Attach the new reference
    attachConfigSet(heartModel, copy(configRef), true);

    % Activate it
    setActiveConfigSet(heartModel, "SharedConfigRef");
end
save_system(heartModel);
end

function resolvedPath = resolveHeartDictionaryPath(slddHeart)
requested = string(slddHeart);
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

error('Cannot find %s',requested);
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