%[jobs] = registerRawToTemplateBrain(jobs, template)
%
% Registers probes in a raw dataset to template brain. Must be run on raw
% data before HB calculation.
%
% Supported Templates: Colin27 (default), NIRxGeom
%
function [jobs] = registerRawToTemplateBrain(jobs, template)

%% Defaults

if ~exist('jobs', 'var') || (isnumeric(jobs) && any(isnan(jobs)))
    jobs = [];
end

if ~exist('template_name', 'var') || isempty(template_name) || (isnumeric(template_name) && any(isnan(template_name)))
    template_name = 'colin27';
end

%% Template

template_name = lower(template_name);
switch template_name
    case 'colin27'
        func = @registerRawToTemplateBrain_Colin27;
        
    case {'nirx' 'nirxgeom'}
        func = @registerRawToTemplateBrain_NIRxGeom;
        
    otherwise
        error('Unsupported template name: %s', template_name);
end

%% Make Job

jobs = nirs.modules.RunMatlabCode(jobs);
jobs.FunctionHandle = func;




%% Template-Specific Calls
function [data] = registerRawToTemplateBrain_Colin27(data)
func = @nirs.registration.Colin27.BEM_V2;
data = registerRawToTemplateBrain_DO(data, func);

function [data] = registerRawToTemplateBrain_NIRxGeom(data)
func = @nirs.registration.NIRxGeom.BEM;
data = registerRawToTemplateBrain_DO(data, func);

%% General Sub-Call
function [data] = registerRawToTemplateBrain_DO(data, func)
lambda = unique(data.probe.link.type);
fwdBEM = func(lambda);
data.probe = data.probe.register_mesh2probe(fwdBEM.mesh);
