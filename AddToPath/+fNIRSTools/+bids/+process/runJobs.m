% fNIRSTools_bids_process_runJobs(bids_info, source_type, target_type, jobs, overwrite, flags)
%
% Runs a job set on individual runs. Existing outputs will be skipped by
% default.
%
% Inputs:
%   bids_info       bids_info structure specifying datasets to use
%   source_type     naming scheme of input file (e.g., snirf)
%   target_type     naming scheme of output file (e.g., hb)
%   jobs            jobs to be performed on each run
%   overwrite       if true, redo and overwrite existing
%   flags           optional cell array of strings
%                       decon = save subset of decon output (<1mb compared to >600mb)
%                       group = combine runs and perform jobs on the set
%                       group_in = read group file and write group file
function fNIRSTools_bids_process_runJobs(bids_info, input_type, output_type, jobs, overwrite, flags)

%% Defaults

if ~exist('overwrite', 'var')
    overwrite = false;
end

if ~exist('flags', 'var')
    flags = cell(0);
else
    if ~iscell(flags)
        flags = {flags};
    end
    flags = cellfun(@lower, flags, 'UniformOutput', false);
end


%% Upper Case Types

input_type = upper(input_type);
output_type = upper(output_type);


%% Handle BIDS Info

[filepaths_input,exists_input] = fNIRSTools.bids.io.getFilepath(input_type, bids_info, true);
[filepaths_output,exists_output] = fNIRSTools.bids.io.getFilepath(output_type, bids_info, true);

%if overwriting, don't count output as existing
if strcmp(input_type,output_type)
    warning('input_type and output_type are the same, files will be processed and overwritten!')
    exists_output(:) = false;
end

%% Get Job Info To Display

fprintf('Performing [%s => %s]...\n', input_type, output_type);

job_list = [];
job = jobs;
while ~isempty(job)
    job_list{end+1} = job;
    job = job.prevJob;
end

for job = job_list(end:-1:1)
    disp(job{1})
end


%% Method 1: Indiv

tic
if ~any(cellfun(@(f) any(strcmpi(f, {'group' 'group_in'})), flags))
    for i = 1:bids_info.number_datasets
        fprintf('\tSet %03d of %03d (%s)\n', i, bids_info.number_datasets, bids_info.datasets(i).full_name);

        if exists_output(i) && ~overwrite
            fprintf('\t\tOutput already exists and overwrite is false, skipping!\n');
        else
            if ~exists_input(i)
                error('Missing input file: %s', exists_input(i));
            else
                %load
                fprintf('\t\tLoading %s: %s\n', input_type, filepaths_input{i});
                input = fNIRSTools.bids.io.readFile(bids_info, input_type, i);

                %process
                runSingleSet(input, jobs, output_type, filepaths_output{i}, flags, sprintf('\t\t'));
            end
        end
        
        %done
        fprintf('\t\tFinished at %g seconds\n', toc);
    end

%% Method 2: Group
else
    %output
    filepath_output = [bids_info.root_directory 'derivatives' filesep sprintf('Group_%s.mat', output_type)];
    if exist(filepath_output, 'file') && ~overwrite
        error('Output already exists and overwrite is false, skipping: %s', filepath_output)
    else
    
        %load all
        fprintf('Loading all input %s...\n', input_type);
        if any(strcmpi(flags, 'group_in'))
            %read group input
            inputs = fNIRSTools.bids.io.readFile(bids_info, input_type, nan, nan, true);
        else
            %read multiple indiv inputs
            inputs = fNIRSTools.bids.io.readFile(bids_info, input_type);
        end
        
        %process
        runSingleSet(inputs, jobs, output_type, filepath_output, flags, '');

        %done
        fprintf('Finished at %g seconds\n', toc);

    end
end




function runSingleSet(input, jobs, output_type, filepath_output, flags, print_prefix)

%perform
fprintf('%sRunning jobs...\n', print_prefix);
if strcmp(output_type, 'RAW') && isempty(jobs)
    %no jobs when converting raw
    data = input;
else
    text = evalc('data = jobs.run(input);'); %redirect messages
end

%if decon, save only the beta x time x cond x channel (else
%very large files)
if any(strcmpi(flags, 'decon'))
    fprintf('%sReducing data for decon save...\n', print_prefix);
    try
        data = data.HRF;
    catch
        warning('Unable to reduce decon data (might not be decon output)');
    end
end

%save
fprintf('%sSaving %s: %s\n', print_prefix, output_type, filepath_output);
try
    save(filepath_output, 'data');
catch
    warning('Standard save failed. Using v7.3 method, which supports larger files but takes longer to load.')
    save(filepath_output, 'data', '-v7.3');
end
            
            


