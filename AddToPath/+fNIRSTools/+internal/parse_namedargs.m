if exist('namedargs', 'var')
    fs = fields(namedargs);
    for f = 1:length(fs)
        name = fs{f};
        eval(sprintf('%s = namedargs.%s;', name, name));
    end
    clear namedargs
end