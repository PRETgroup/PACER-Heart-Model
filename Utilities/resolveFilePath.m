function resolvedPath = resolveFilePath(filename)
requested = string(filename);
if isfile(char(requested))
   resolvedPath = char(requested);
   return;
end

proj = currentProject;
candidate = fullfile(proj.RootFolder, char(requested));
if isfile(candidate)
   resolvedPath = candidate;
   return;
end

error('Cannot find %s',requested);
end