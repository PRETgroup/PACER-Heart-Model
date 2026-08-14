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