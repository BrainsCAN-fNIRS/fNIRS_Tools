function CellsAreChar(values)
if ~iscell(values) || any(~cellfun(@ischar, values))
    msg = 'Must be {char}.';
    throwAsCaller(MException('',msg))
end