function setup

%% Check Requirements

fprintf('Checking requirements...');
[~,version_date] = version;
version_year = str2num(version_date(end-3:end));
if version_year < 2012
    error('MATLAB 2012 or later is required')
else
    fprintf('success\n');
end

%% Add to Path

fprintf('Adding directories to path...');
path_to_collection = [pwd filesep 'AddToPath' filesep];
path(path,path_to_collection);
try
    savepath
    fprintf('success\n');
catch
    warning('MATLAB Path could not be saved. Directories have been added to the path for this session only.\nThe most common solution is to run MATLAB as admin and try agian.')
end

%% Done
disp('Setup complete!')