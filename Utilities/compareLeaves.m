function compareLeaves(a,b,path)

if nargin < 3
    path='';
end

fields = fieldnames(a);

for i=1:length(fields)

    f=fields{i};

    p=f;
    if ~isempty(path)
        p=[path '.' f];
    end

    if isstruct(a.(f))
        compareLeaves(a.(f),b.(f),p);

    else

        if ~strcmp(class(a.(f)),class(b.(f)))
            fprintf('Class mismatch: %s\n',p)
            fprintf('  template: %s\n',class(a.(f)))
            fprintf('  m_cfg:    %s\n',class(b.(f)))
        end

        if ~isequal(size(a.(f)),size(b.(f)))
            fprintf('Size mismatch: %s\n',p)
            fprintf('  template: ')
            disp(size(a.(f)))
            fprintf('  m_cfg: ')
            disp(size(b.(f)))
        end

    end
end

end