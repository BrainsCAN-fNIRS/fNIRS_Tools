%Requires MATLAB Signal Processing Toolbox
classdef lowpassFilter < nirs.modules.AbstractModule
    properties
        passbandFrequency = 0.2;
    end
    
    methods
        function obj = lowpassFilter( prevJob )
           obj.name = 'Lowpass Filter';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if length(obj.passbandFrequency)~=1 || ~isnumeric(obj.passbandFrequency) || isnan(obj.passbandFrequency) || (obj.passbandFrequency <= 0)
                error('Invalid passband')
            else
                % for each file
                for i = 1:numel(data)
                    data(i).data = lowpass(data(i).data, obj.passbandFrequency, data(i).Fs);
                end
            end
        end
        
    end
end