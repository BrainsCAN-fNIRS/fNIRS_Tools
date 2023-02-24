classdef regressSDC < nirs.modules.AbstractModule
    properties
    end
    
    methods
        function obj = regressSDC( prevJob )
           obj.name = 'Regress SDC from LDC. Uses all SDC with each channel. Independent for hbo and hbr. IMPORTANT NOTE: Not intended for analysis. Use this as a quick check for what SDC regression is likely to do, but the actual regression should be during the GLM.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                
				for j = 1:height(data(i).probe.link)
					if ~data(i).probe.link.ShortSeperation(j)
						ind_sdc_dt = strcmp(data(i).probe.link.type, data(i).probe.link.type{j}) & data(i).probe.link.ShortSeperation;

						sig = data(i).data(:,j);
						sdcs = data(i).data(:,ind_sdc_dt);

						sdc_betas = pinv(sdcs)*sig;
						sig_sdcreg = sig - sdcs*sdc_betas;

						data(i).data(:,j) = sig_sdcreg;
					end
				end

				jobs = nirs.modules.RemoveShortSeperations;
				data(i) = jobs.run(data(i));
				
            end
        end
        
    end
end