function CellsAreNumeric(values)
if ~iscell(values) || any(~cellfun(@isnumeric, values))
    msg = 'Must be {numeric}.';
    throwAsCaller(MException('',msg))
end