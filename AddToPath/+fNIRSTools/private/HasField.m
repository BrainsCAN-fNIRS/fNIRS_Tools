function [result] = HasField(structure, field_name)
try
    GetField(structure, field_name);
    result = true;
catch
    result = false;
end