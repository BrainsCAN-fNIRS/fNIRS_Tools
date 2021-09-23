function SizeInCells(values, size_in_cells, allow_empty)

if ~exist('allow_empty', 'var')
    allow_empty = false;
end

%can't pass nan but treat size<0 as nan
size_in_cells(size_in_cells<0) = nan;

%default
valid = true;

if ~iscell(values)
    valid = false;
else
    cell_is_invalid = cellfun(@(x) any((size(x) ~= size_in_cells) - isnan(size_in_cells)), values);
    if allow_empty
        cell_is_invalid(cellfun(@isempty, values)) = false; %empty is valid
    end
    if any(cell_is_invalid)
        valid = false;
    end
end

if ~valid
    if allow_empty
        str_add = 'empty or ';
    else
        str_add = '';
    end
    msg = sprintf('Invalid cell element size (expected %sdimensions: %s).', str_add, num2str(size_in_cells));
    throwAsCaller(MException('',msg))
end