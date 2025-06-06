classdef setHeadSizeAndRecalcChannelDistances < nirs.modules.AbstractModule
    properties
		%any combination of the three measures may be used, absent measures will be estimated
        %valid values:
        %   NaN or []   excluded
        %   numeric     directly used for all datasets
        %   char        the name of a key in data.demographics, the corresponding value is used individually per dataset
        lpa_cz_rpa_mm = nan;
		Iz_cz_nas_mm = nan;
		circumference_mm = nan;
		
		skip_SDC_distances = true; %if true, SDC distances will not be scaled (probe.link.ShortSeperation must have been set, else ignored)
    end
    
    properties (Access = private)
        var_field_pairs = {
                            'lpa_cz_rpa_mm'     'lpa-cz-rpa'
                            'Iz_cz_nas_mm'      'Iz-cz-nas'
                            'circumference_mm'  'circumference'
                            };
    end
    
    methods
        function obj = setHeadSizeAndRecalcChannelDistances( prevJob )
           obj.name = 'Adjust the headsize of the probe and recalcualte channel distances';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
			%apply to each dataset...
			for i = 1:numel(data)
                %create headsize dictionary
                headsize = Dictionary();
                for j = 1:size(obj.var_field_pairs, 1)
                    val = obj.(obj.var_field_pairs{j,1});
                    if ischar(val)
                        val = data(i).demographics(val);
                    end
                    if ~isempty(val) && ~isnan(val)
                        headsize(obj.var_field_pairs{j,2}) = val;
                    end
                end
                if isempty(headsize)
                    error('At least one measurement must be set')
                end
                
				%get channel table
                [channels, has_sdc_labels] = fNIRSTools.internal.GetChannels(data(i));
                number_channels = height(channels);
                
                %will skip SDC?
				skip_sdc = obj.skip_SDC_distances && has_sdc_labels;
                
                %scale optode positions (sets optodes_registered and srcPos3D/detPos3D)
				p = nirs.util.registerprobe1020(data.probe, headsize);

                %confirm that resize worked
                headsize_new = p.get_headsize;
                for f = string(headsize.keys)
                    d = abs(headsize_new(f.char) - headsize(f.char));
                    if d>1
                        error("Failed to resize correctly. Likely due to issues in registerprobe1020 and applytform.")
                    end
                end
				
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