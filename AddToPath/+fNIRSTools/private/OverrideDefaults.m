function [p] = OverrideDefaults(p, overrides)

%% Stop if no overrides
if isempty(overrides)
    return
end

%% Determine Mode

count = length(overrides);
if count > 1
    %field-value pairs
    p_override = struct;
    for i = 1:2:count
        %field name
        field = overrides{i};
        
        %field name is string?
        if ~isstr(field)
            error('Override field name is not a string')
        end
        
        %set field name to caps
        field = upper(field);
        
        %contains value?
        if i >= count
            error('No value found for field: %s', field)
        end
        
        %get value
        value = overrides{i+1};
        
        %store in override struct
        p_override = SetField(p_override, field, value);
    end
    
elseif (length(overrides) == 1) && isstruct(overrides{1})
    %structure
    p_override = overrides{1};
    
else
    error('Unknown override mode')
end

%% Apply Overrides

field_names = fields(p_override);
while ~isempty(field_names)
    field_names_next = cell(0);
    
    for i = 1:length(field_names)
        field = field_names{i};
        value = GetField(p_override, field);
        
        if ~isstruct(value)
            %found value to add
            if ~HasField(p, field)
                error('Tried to override non-existent field: %s', field)
            else
                p = SetField(p, field, value);
            end
            
        else
            %found subfield to search
            field_names_next = [field_names_next cellfun(@(x) sprintf('%s.%s', field, x), fields(value), 'UniformOutput', false)];
        end
    end
    
    field_names = field_names_next;
end

