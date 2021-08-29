classdef addChannelLabels < nirs.modules.AbstractModule
    properties
        labels = table('Size',[0 3],'VariableTypes',{'single' 'single' 'string'},'VariableNames',{'source' 'detector' 'label'});
        field_name = 'CustomLabel';
    end
    
    methods
        function obj = addChannelLabels( prevJob )
           obj.name = 'Add channel labels in probe.link';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                %initialize labels
                labels = repmat({'unlabeled'}, [height(data(i).probe.link) 1]);
                
                %fill
                for j = 1:height(data(i).probe.link)
                    ind = find((obj.labels.source == data(i).probe.link.source(j)) & (obj.labels.detector == data(i).probe.link.detector(j)));
                    if isempty(ind)
                        continue
                    elseif length(ind)>1
                        error('Label table contains duplicate')
                    else
                        labels{j} = obj.labels.label{ind};
                    end
                end
                
                %apply
                data(i).probe.link = setfield(data(i).probe.link, obj.field_name, labels);
            end
        end
        
    end
end