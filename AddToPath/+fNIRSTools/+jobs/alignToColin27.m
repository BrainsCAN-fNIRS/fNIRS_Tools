classdef alignToColin27 < nirs.modules.AbstractModule
    properties
        rigid_alignment = false
    end
    
    methods
        function obj = alignToColin27( prevJob )
           obj.name = 'Add Colin27 mesh and align to fiducials';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                %add mesh
                lambda = unique(data(i).probe.link.type);
                fwdBEM = nirs.registration.Colin27.BEM_V2(lambda);
                data(i).probe = data(i).probe.register_mesh2probe(fwdBEM.mesh);
                data(i).probe = data(i).probe.SetFiducialsVisibility(false);
                
                %align with fiducials (non-rigid)
                m = data(i).probe.getmesh;
                t = nirs.registration.cp2tform(data(i).probe.optodes_registered, m(1).fiducials, obj.rigid_alignment);
                data(i).probe.optodes_registered = nirs.registration.applytform(data(i).probe.optodes_registered, t);
            end
        end
        
    end
end