classdef setHeadSizeAndRecalcChannelDistances < nirs.modules.AbstractModule
    properties
		%any combination of the three measures may be used, absent measures will be estimated
        lpa_cz_rpa_mm = nan;
		Iz_cz_nas_mm = nan;
		circumference_mm = nan;
		
		skip_SDC_distances = true; %if true, SDC distances will not be scaled (probe.link.ShortSeperation must have been set, else ignored)
    end
    
    methods
        function obj = setHeadSizeAndRecalcChannelDistances( prevJob )
           obj.name = 'Adjust the headsize of the probe and recalcualte channel distances';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            %create headsize dictionary
			headsize = Dictionary();
			if ~isempty(obj.lpa_cz_rpa_mm) && ~isnan(obj.lpa_cz_rpa_mm)
				headsize('lpa-cz-rpa') = obj.lpa_cz_rpa_mm;
			end
			if ~isempty(obj.Iz_cz_nas_mm) && ~isnan(obj.Iz_cz_nas_mm)
				headsize('Iz-cz-nas') = obj.Iz_cz_nas_mm;
			end
			if ~isempty(obj.circumference_mm) && ~isnan(obj.circumference_mm)
				headsize('circumference') = obj.circumference_mm;
			end
			if isempty(headsize)
				error('At least one measurement must be set')
			end
			
			%apply to each dataset...
			for i = 1:numel(data)
				%get channel table
                [channels, has_sdc_labels] = fNIRSTools.internal.GetChannels(data(i));
                number_channels = height(channels);
                
                %will skip SDC?
				skip_sdc = obj.skip_SDC_distances && has_sdc_labels;
                
                %scale optode positions (sets optodes_registered and srcPos3D/detPos3D)
				p = nirs.util.registerprobe1020(data.probe, headsize);
				
                %fetch 3D positions once because it is slow
                s_xyz = p.srcPos3D;
                d_xyz = p.detPos3D;
                
				%recalculate channel distances
                for c = 1:number_channels
                    if skip_sdc && channels.ShortSeperation(c)
                        continue
                    else
                        new_distance = pdist([s_xyz(channels.source(c), :); d_xyz(channels.detector(c), :)]);
                        p.fixeddistances(channels.TypeIndicesInLinks{c},1) = new_distance;
                    end
                end
                
				%set new probe
				data(i).probe = p;
			end
        end
    end
end