classdef addMissingDataCol < nirs.modules.AbstractModule
    properties
        fill_value = nan;
    end
    
    methods
        function obj = addMissingDataCol( prevJob )
           obj.name = 'Adds any missing columns at the end of the data matrix with a fill value. Can be used as a workaround to an issue in nirs.modules.BeerLambertLaw where it removes any number of columns at the end if there was no data there. This jobs adds back those end columns with a fill value.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                if ~any(strcmp(fields(data(i)),'data'))
                    error('data structure does not contain "data" field')
                else
                    number_col_needed = height(data(i).probe.link);
                    data(i).data(:,end+1:number_col_needed) = obj.fill_value;
                end
            end
        end
        
    end
end