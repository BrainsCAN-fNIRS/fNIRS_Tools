function IntegersOnly(values, allow_nan)

%handle cell of numeric
if iscell(values)
    %check all numeric
    fNIRSTools.internal.verify.CellsAreNumeric(values);
    
    %convert to single array
    values = cell2mat(cellfun(@(x) x(:), values(:), 'UniformOutput', false));
end

%convert to single array
values = values(:);

%remove nan?
if exist('allow_nan', 'var') && allow_nan
    values = values(~isnan(values));
else
    allow_nan = false;
end

%is integer
is_int = (values == round(values));

%any non-integer?
if any(~is_int)
    if allow_nan
        str_add = 'or nan ';
    else
        str_add = '';
    end
    msg = sprintf('Must be integers %sonly.', str_add);
    throwAsCaller(MException('',msg))
end