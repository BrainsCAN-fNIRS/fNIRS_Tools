function LengthMatchDim(values, target, dim, allow_length_1)

if ~exist('allow_length_1', 'var')
    allow_length_1 = false;
end

values = ones(1, size(values, dim));

fNIRSTools.internal.verify.LengthMatch(values, target, allow_length_1);