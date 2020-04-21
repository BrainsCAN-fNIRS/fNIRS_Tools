function [structure] = SetField(structure, field_name, value)
eval(sprintf('structure.%s = value;', field_name));