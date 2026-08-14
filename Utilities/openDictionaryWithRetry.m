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

function tf = isDictionaryNameConflict(err)
msg = lower(string(err.message));
tf = contains(msg, "another dictionary with the same file name is already open");
end
end

