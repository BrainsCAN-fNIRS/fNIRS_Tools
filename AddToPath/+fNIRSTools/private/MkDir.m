function MkDir(directory_path)

ind = find(directory_path == filesep);
for i = ind
    d = directory_path(1:i);
    if ~exist(d, 'dir')
        mkdir(d);
        if ~exist(d, 'dir')
            error('Failed to make directory: %s', directory_path)
        end
    end
end