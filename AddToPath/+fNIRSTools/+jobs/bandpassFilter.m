%Requires MATLAB Signal Processing Toolbox
classdef bandpassFilter < nirs.modules.AbstractModule
    properties
        passbandFrequencies = [0.01 0.2];
    end
    
    methods
        function obj = bandpassFilter( prevJob )
           obj.name = 'Bandpass Filter';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if length(obj.passbandFrequency)~=2 || ~isnumeric(obj.passbandFrequency) || any(isnan(obj.passbandFrequency)) || any(obj.passbandFrequency <= 0)
                error('Invalid passband')
            else
                % for each file
                for i = 1:numel(data)
                    data(i).data = bandpass(data(i).data, obj.passbandFrequency, data(i).Fs);
                end
            end
        end
        
    end
end