% PrepareDataWavelengths(directory_search, directory_output)
%
% Prepares data collected with the NIRScoutX 64x32 system for analysis by
% creating a copy of the dataset that contains only the specified
% wavelengths. By default, these are 785 and 850.
%
% INPUTS:
%	directory_search    Path to the starting point of the data search. This
%                       function will process any datasets found in search
%                       directory. Any directory with a _probeInfo.mat file
%                       is expected to be a dataset.
%
%   directory_output    Path to the root outout directory. The directory
%                       structure in the search path will be matched.
%
% OVERRIDES:
%   Any parameters (fields of the p structure) may be overridden either by
%   passing a structure with any number of matching fields or by passing
%   any number of field-value pairs.
%
%
% Author:   Kevin Stubbs (kmstubbs@gmail.com)
% Date:     August 2019
%
function PrepareDataWavelengths(directory_search, directory_output, varargin)

%% Parameters - Defaults

%wavelengths to use (in order)
p.WAVELENGTHS_USE = [785 850];

%allow overwrite of any existing files
p.OVERWRITE = false;

%% Parameters - Override

p = OverrideDefaults(p, varargin);

%% Parameters - Check

%at least one wavelength should be specified
if ~isnumeric(p.WAVELENGTHS_USE) || isempty(p.WAVELENGTHS_USE)
    error('At least one wavelength should be specified');
end

%wavelengths should be unique
if length(unique(p.WAVELENGTHS_USE)) ~= length(p.WAVELENGTHS_USE)
    error('Duplicate wavelength detected')
end

%warn if overwrite
if p.OVERWRITE
    warning('Overwrite mode is enabled')
end

%% Directories

%input/output must end with filesep
if directory_search(end) ~= filesep
    directory_search(end+1) = filesep;
end
if directory_output(end) ~= filesep
    directory_output(end+1) = filesep;
end

%input/output must be different
if strcmp(directory_search, directory_output)
    error('Input and output directories must be different')
end

%create output dir if needed
if ~exist(directory_output, 'dir')
    mkdir(directory_output);
end

%find dataset directories
fprintf('Searching for dataset(s)...\n')
directories = cell(0);
search = {directory_search};
while ~isempty(search)
    search_next = cell(0);
    
    for subpath = search
        subpath = subpath{1};
        
        %add subdirs to search
        list = dir(subpath);
        list = list([list.isdir] & cellfun(@(x) x(1)~='.', {list.name}));
        search_next = [search_next cellfun(@(x) [subpath x filesep], {list.name}, 'UniformOutput', false)];
        
        list = dir([subpath '*_probeInfo.mat']);
        if ~isempty(list)
            %found data directory
            ind = length(directories)+1;
            directories(ind).input = subpath;
            directories(ind).output = strrep(subpath, directory_search, directory_output);
        end
    end
    
    search = search_next;
end

number_datasets = length(directories);
fprintf('Found %d datasets\n', number_datasets);

%% Process

for i = 1:number_datasets
    fprintf('\nDataset #%d:\n', i);
    fprintf('\tInput:\t%s\n', directories(i).input);
    fprintf('\tOutput:\t%s\n', directories(i).output);
    
    ProcessDataset(p, directories(i).input, directories(i).output);
    
end

%% Complete

fprintf('\nComplete.\n');





%% Process Dataset

function ProcessDataset(p, directory_source, directory_destination)

%% Prep

%create output dir
fprintf('\tCreating output directory...');
MkDir(directory_destination);
fprintf('done\n');

%files to exclude from final copy
filename_exclude = cell(0);

%% Config File

fprintf('\t\tCopying config file with modifications:\n');

%find file
fprintf('\t\t\tFinding config file...');
file = dir([directory_source '*_config.txt']);
if isempty(file)
    error('No config file found')
elseif length(file) > 1
    error('Multiple config files found')
end
fprintf('%s\n', file.name);

%exclude from later copy
filename_exclude{end+1} = file.name;

%check overwrite
if exist([directory_destination file.name], 'file') && ~p.OVERWRITE
    error('Config file already exists but overwrite is disabled')
end

%copy/modify
fid_in = fopen([directory_source file.name], 'r');
fid_out = fopen([directory_destination file.name], 'w');

while ~feof(fid_in)
    line = fgetl(fid_in);
    
    if regexp(line,'waveLength_N=\s*')
        number_wavelengths = length(p.WAVELENGTHS_USE);
        fprintf('\t\t\tSetting number of wavelength to %d...', number_wavelengths);
        line = sprintf('waveLength_N=%d; ', number_wavelengths);
        fprintf('done\n');
        
    elseif regexp(line,'Wavelengths=\s*')
        fprintf('\t\t\tReading original order of wavelengths...');
        wavelengths_original = str2num(line(find(line=='['):find(line==']')));
        fprintf('[%d%s]\n', wavelengths_original(1), sprintf(' %d', wavelengths_original(2:end)));
        
        fprintf('\t\t\tLooking for specified wavelengths...');
        for w = 1:number_wavelengths
            ind = find(wavelengths_original == p.WAVELENGTHS_USE(w));
            if length(ind) ~= 1
                error('One or more specified wavelength is not present in the dataset')
            else
                wavelength_index(w) = ind;
            end
        end
        fprintf('using indices: [%d%s]\n', wavelength_index(1), sprintf(' %d', wavelength_index(2:end)));
        
        fprintf('\t\t\tUpdating wavelengths...');
        line = sprintf('Wavelengths=[%d%s]; ', p.WAVELENGTHS_USE(1), sprintf('\t%d', p.WAVELENGTHS_USE(2:end)));
        fprintf('done\n');
    end
    
    fprintf(fid_out, '%s\n', line);
end

fclose(fid_in);
fclose(fid_out);

%% Header File

fprintf('\t\tCopying header file with modifications:\n');

%find file
fprintf('\t\t\tFinding config file...');
file = dir([directory_source '*.hdr']);
if isempty(file)
    error('No header file found')
elseif length(file) > 1
    error('Multiple header files found')
end
fprintf('%s\n', file.name);

%exclude from later copy
filename_exclude{end+1} = file.name;

%check overwrite
if exist([directory_destination file.name], 'file') && ~p.OVERWRITE
    error('Config file already exists but overwrite is disabled')
end

%copy/modify
fid_in = fopen([directory_source file.name], 'r');
fid_out = fopen([directory_destination file.name], 'w');

multiline_mode_active = false;
multiline_mode = [];

while ~feof(fid_in)
    line = fgetl(fid_in);
    
    if multiline_mode_active
        %add line
        multilines_read{end+1} = line;
        
        switch multiline_mode
            case 'DarkNoise'
                if isempty(line)
                    %end when first empty line is reached
                    multiline_mode_active = false;
                    
                    multilines_write = {'[DarkNoise]'};
                    for w = 1:number_wavelengths
                        multilines_write{end+1} = sprintf('Wavelength%d="#', w);
                        multilines_write{end+1} = multilines_read{wavelength_index(w)*3};
                        multilines_write{end+1} = '#"';
                    end
                    multilines_write{end+1} = [];
                    
                end
            otherwise
                error('Unknown multiline mode: %s', multiline_mode);
        end
        
        if ~multiline_mode_active
            %end of multiline mode
            fprintf('multi-line result is writing...');
            multiline_mode = [];
            for line = multilines_write
                fprintf(fid_out, '%s\n', line{1});
            end
            fprintf('done\n');
        end
    else
        if regexp(line,'Wavelengths=\s*')
            fprintf('\t\t\tUpdating wavelengths...');
            line = sprintf('Wavelengths="%d%s"', p.WAVELENGTHS_USE(1), sprintf('	%d', p.WAVELENGTHS_USE(2:end)));
            fprintf('done\n');

        elseif regexp(line,'Mod Amp=\s*')
            fprintf('\t\t\tReading mod amp...');
            mod_amp = str2num(line(find(line=='"',1,'first')+1:find(line=='"',1,'last')-1));
            fprintf('"%.3f%s"\n', mod_amp(1), sprintf(' %.3f', mod_amp(2:end)));

            fprintf('\t\t\tWriting modified mod amp...');
            mod_amp = sprintf('"%.3f%s"', mod_amp(wavelength_index(1)), sprintf('	%.3f', mod_amp(wavelength_index(2:end))));
            line = ['Mod Amp=' mod_amp];
            fprintf('%s\n', mod_amp);

        elseif regexp(line,'Threshold=\s*')
            fprintf('\t\t\tReading thresholds...');
            thresh = str2num(line(find(line=='"',1,'first')+1:find(line=='"',1,'last')-1));
            fprintf('"%.3f%s"\n', thresh(1), sprintf(' %.3f', thresh(2:end)));

            fprintf('\t\t\tWriting modified thresholds...');
            thresh = sprintf('"%.3f%s"', thresh(wavelength_index(1)), sprintf('	%.3f', thresh(wavelength_index(2:end))));
            line = ['Threshold=' thresh];
            fprintf('%s\n', thresh);

        elseif strcmp(line, '[DarkNoise]')
            multiline_mode = 'DarkNoise';
            fprintf('\t\t\tSelecting wavelength DarkNoise...');
        end
        
        if isempty(multiline_mode)
            %write line
            fprintf(fid_out, '%s\n', line);
        else
            %start of multiline mode
            multiline_mode_active = true;
            multilines_read = {line};
            multilines_write = cell(0);
        end
    end
end

fclose(fid_in);
fclose(fid_out);

%% .wl# data files

fprintf('\t\tDeleting prior wl# data files in output directory:\n');
list = dir([directory_destination '*.wl*']);
number_prior_files = length(list);
if number_prior_files
    for i = 1:number_prior_files
        fprintf('\t\t\tDeleting %d of %d: %s\n', i, number_prior_files, list(i).name);
        delete([directory_destination list(i).name]);
    end
else
    fprintf('\t\t\tNo prior .wl# files were found\n');
end

fprintf('\t\tCopying (and renaming) wl# data files:\n');
for w = 1:number_wavelengths
    fprintf('\t\t\tFile %d of %d: %dnm (index %d):\n', w, number_wavelengths, p.WAVELENGTHS_USE(w), wavelength_index(w));
    
    %find source file
    fprintf('\t\t\t\tFinding file...');
    file = dir(sprintf('%s*.wl%d', directory_source, wavelength_index(w)));
    if isempty(file)
        error('No file found')
    elseif length(file) > 1
        error('Multiple files found')
    end
    fprintf('%s\n', file.name);
    
    %copy to destination
    fprintf('\t\t\t\tCopying file...');
    filename_out = [file.name(1:find(file.name=='.',1,'last')) sprintf('wl%d', w)];
    fp_source = [directory_source file.name];
    fp_dest = [directory_destination filename_out];
    if exist(fp_dest, 'file') && ~p.OVERWRITE
        error('File already exists but overwrite is disabled')
    end
    copyfile(fp_source, fp_dest, 'f');
    fprintf('%s\n', filename_out);
    
end

%% All Other Files

fprintf('\t\tCopying all remaining files:\n');

%find all files
list = dir(directory_source);
list = list(~[list.isdir]);
filenames = {list.name};

%do not copy files in filename_exclude
filenames = filenames(cellfun(@(x) ~any(strcmp(filename_exclude, x)), filenames));

%do not copy any .wl# files
filenames = filenames(cellfun(@(x) isempty(regexp(x, '\s*.wl\d+')), filenames));

%copy
number_files = length(filenames);
for i = 1:number_files
    fn = filenames{i};
    fprintf('\t\t\tFile %d of %d: %s\n', i, number_files, fn);
    
    fp_source = [directory_source fn];
    fp_dest = [directory_destination fn];
    
    if exist(fp_dest, 'file') && ~p.OVERWRITE
        error('File already exists but overwrite is disabled')
    end
    
    copyfile(fp_source, fp_dest, 'f');
    
end
