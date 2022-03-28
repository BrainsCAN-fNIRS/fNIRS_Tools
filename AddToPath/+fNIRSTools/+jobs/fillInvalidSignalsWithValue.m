classdef fillInvalidSignalsWithValue < nirs.modules.AbstractModule
    properties
        fill_value = 1; %value to fill 
    end
    
    methods
        function obj = fillInvalidSignalsWithValue( prevJob )
           obj.name = 'Fill channels that have no range with specified value';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
				if ~any(strcmp(fields(data(i)),'data'))
                    error('data structure does not contain "data" field')
                else
					signal_ranges = range(data(i).data);
					signal_ranges_invalid = isnan(signal_ranges) | (signal_ranges == 0);
                    data(i).data(:,signal_ranges_invalid) = obj.fill_value;
					data(i).probe.link.Excluded = signal_ranges_invalid';
				end
			end
        end
        
    end
end