classdef removeExtraDataCol < nirs.modules.AbstractModule
    properties
    end
    
    methods
        function obj = removeExtraDataCol( prevJob )
           obj.name = 'Removes any extra columns at the end of the data matrix. Can be used as a workaround to an issue in nirs.modules.BeerLambertLaw where it adds any number of columns at the end.';
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

                    %check that it's just NaNs
                    if any(any(~isnan(data(i).data(:,(number_col_needed+1):end))))
                        error('Found non-NaN values in the extra columns!')
                    end

                    %reduce
                    data(i).data = data(i).data(:,1:number_col_needed);
                end
            end
        end
        
    end
end