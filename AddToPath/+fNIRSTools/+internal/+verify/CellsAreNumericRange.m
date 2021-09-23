function CellsAreNumericRange(values,value_min,value_max)
if ~iscell(values) || any(~cellfun(@isnumeric, values)) || any(cellfun(@(x) any(x(:)<value_min | x(:)>value_max) ,values))
    msg = sprintf('Must be {numeric} with values between %g and %g.', value_min, value_max);
    throwAsCaller(MException('',msg))
end