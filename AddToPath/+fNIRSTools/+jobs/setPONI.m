classdef setPONI < nirs.modules.AbstractModule
    properties
        conditions = {};
    end
    
    methods
        function obj = setPONI( prevJob )
           obj.name = 'Set specified conditions as PONIs';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if ~any(strcmp(fields(data),'stimulus'))
                error('data structure does not contain "stimulus" field')
            else
                ind_set = find(cellfun(@(key) any(strcmp(obj.conditions,key)), data.stimulus.keys));
                if any(ind_set)
                    values = data.stimulus.values;
                    for ind = ind_set
                        values{ind}.regressor_no_interest = 1;
                    end
                    data.stimulus.values = values;
                end
            end
        end
        
    end
end