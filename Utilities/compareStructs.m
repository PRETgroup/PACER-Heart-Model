function compareStructs(a,b,path)

if nargin < 3
    path = '';
end

fa = fieldnames(a);
fb = fieldnames(b);

missing = setdiff(fa,fb);
extra = setdiff(fb,fa);

if ~isempty(missing)
    fprintf('Missing at %s:\n',path)
    disp(missing)
end

if ~isempty(extra)
    fprintf('Extra at %s:\n',path)
    disp(extra)
end


common = intersect(fa,fb);

for i = 1:length(common)

    f = common{i};

    newPath = f;
    if ~isempty(path)
        newPath = [path '.' f];
    end

    if isstruct(a.(f)) && isstruct(b.(f))
        compareStructs(a.(f),b.(f),newPath)
    end
end

end