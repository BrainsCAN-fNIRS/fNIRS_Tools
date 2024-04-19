classdef setInfToNaN < nirs.modules.AbstractModule
    properties
    end
    
    methods
        function obj = setInfToNaN( prevJob )
           obj.name = 'Set Inf values to NaN';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
			for i = 1:numel(data)
				if ~any(strcmp(fields(data(i)),'data'))
					error('data structure does not contain "data" field')
				else
					data(i).data(isinf(data(i).data)) = nan;
				end
			end
        end
        
    end
end