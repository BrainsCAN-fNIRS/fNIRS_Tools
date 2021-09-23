function LengthMatch(values, target, allow_length_1, allow_empty)

lengths_allowed = length(target);

if exist('allow_length_1', 'var') && allow_length_1
    lengths_allowed = [lengths_allowed 1];
end

if exist('allow_empty', 'var') && allow_empty
    lengths_allowed = [lengths_allowed 0];
end

if ~any(length(values) == lengths_allowed)
    if length(lengths_allowed)==1
        msg = sprintf('Invalid length (expected %d).', lengths_allowed);
    else
        msg = sprintf('Invalid length (expected any of: %s).', num2str(lengths_allowed));
    end
    throwAsCaller(MException('',msg))
end