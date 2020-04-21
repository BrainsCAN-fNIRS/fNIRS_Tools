function [value] = GetField(structure, field_name)
while any(field_name=='.')
    ind = find(field_name=='.', 1, 'first');
    subfield = field_name(1:ind-1);
    field_name = field_name(ind+1:end);
    
    structure = getfield(structure, subfield);
end
value = getfield(structure, field_name);