classdef globalSignalRegression < nirs.modules.AbstractModule
    properties
        fields_for_exclusion = {}; %name of any logical fields to use for exclusion from global signal calculation, case-sensitive
    end
    
    methods
        function obj = globalSignalRegression( prevJob )
           obj.name = 'Apply global signal regression. Independent for each data type.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                if ~any(strcmp(fields(data(i)),'data'))
                    error('data structure does not contain "data" field')
                else
                    %identify available exclusion fields
                    link_fields = data(i).probe.link.Properties.VariableNames;
                    exclusion_fields = cell(0);
                    for f = 1:length(obj.fields_for_exclusion)
                        name = obj.fields_for_exclusion{f};
                        if any(strcmp(link_fields, name))
                            exclusion_fields{end+1} = name;
                        end
                    end
                    number_exclusions = length(exclusion_fields);
                    if number_exclusions
                        fprintf('The following exclusion fields are available and will be applied: %s\n', sprintf('%s ', exclusion_fields{:}));
                    end
                    
                    %identify signals with valid data
                    has_data = nanmax(data(i).data) > nanmin(data(i).data);
                    
                    %for each data type...
                    number_types = length(data.probe.types);
                    for type_ind = 1:number_types
                        type = data.probe.types(type_ind);
                        
                        %select signals of this type
                        if iscell(type)
                            select_type = strcmpi(data(i).probe.link.type,type);
                        else
                            select_type = (data(i).probe.link.type == type);
                        end

                        %initialize source selection as all signals of type
                        select_source = select_type;

                        %apply exclusion fields
                        for j = 1:number_exclusions
                            can_pass = ~getfield(data(i).probe.link, exclusion_fields{j});
                            select_source = select_source & can_pass;
                        end

                        %also exclude channels with no data
                        select_source = select_source & has_data;

                        %calculte global signal
                        global_signal = nanmean(data(i).data(:,select_source), 2);

                        %apply regression to all signals of type
                        for ind = find(select_type)'
                            if ~has_data(ind)
                                continue;
                            else
                                signal = data(i).data(:,ind);
                                [~,~,residual] = regress(signal, global_signal);
                                data(i).data(:,ind) = residual;
                            end
                        end

                    end
                    
                    
                end
            end
        end
        
    end
end