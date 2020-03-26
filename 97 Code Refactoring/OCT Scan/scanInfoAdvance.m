function scanInfoAdvance(subjectPath)
% This function advances scan info to the latest version written for LD
% Written at March 25, 2020.

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('01','LD');
end

% Load Reference scan JSON from most up to date version
volumeRefJson = awsReadJSON([s3SubjectPath('01') '/OCTVolumes/Volume/ScanInfo.json']);

%% Load and advance volume json & overview
volumeJsonPath = [subjectPath '/OCTVolumes/Volume/ScanInfo.json'];
volumeJson = awsReadJSON(volumeJsonPath);
if (volumeJson.version ~= 1.0)
    disp('This code updates version 1.0 to 1.1, the version is wrong');
    return;
end
volumeJson = cleanupScanInfo(volumeJson, volumeRefJson.octProbe);

overviewJsonPath = [subjectPath '/OCTVolumes/Overview/ScanInfo.json'];
overviewJson = awsReadJSON(overviewJsonPath);
overviewJson = cleanupScanInfo(overviewJson, volumeRefJson.octProbe);

%% Scan Config
scanConfigPath = [subjectPath '/OCTVolumes/ScanConfig.json'];
scanConfig = awsReadJSON(scanConfigPath);

% Remove parameters that are in the oct probe
scanConfig.volume = volumeJson;
scanConfig.overview = overviewJson;
scanConfig = rmfield(scanConfig,'octProbeFOV');
scanConfig = rmfield(scanConfig,'octProbeLensWorkingDistance');
scanConfig = rmfield(scanConfig,'offsetX');
scanConfig = rmfield(scanConfig,'offsetY');
scanConfig = rmfield(scanConfig,'scaleX');
scanConfig = rmfield(scanConfig,'scaleY');
scanConfig.gitBranchUsedToScan = [scanConfig.gitBranchUsedToScan ' updated on ' datestr(now)];
scanConfig.version = 2.1;

%% Save 

% Backup copy
awsCopyFileFolder(volumeJsonPath,[subjectPath 'Log/00 Depreciated Files Dont Use/Volume_ScanInfo.json']);
awsCopyFileFolder(overviewJsonPath,[subjectPath 'Log/00 Depreciated Files Dont Use/Overview_ScanInfo.json']);
awsCopyFileFolder(scanConfigPath,[subjectPath 'Log/00 Depreciated Files Dont Use/ScanConfig.json']);

% Update
awsWriteJSON(volumeJson,volumeJsonPath);
awsWriteJSON(overviewJson,overviewJsonPath);
awsWriteJSON(scanConfig,scanConfigPath);

end

%% Helper function to cleanup ScanInfo
function scanInfoJson = cleanupScanInfo(scanInfoJson, octProbe)
scanInfoJson = rmfield(scanInfoJson,'lensWorkingDistance');
scanInfoJson.xOffset = 0; % xOffset is moved to octProbe
scanInfoJson.version = 1.1;
scanInfoJson.octProbe = octProbe;
scanInfoJson.note = ['This config file was advanced to latest version on ' datestr(now)];
end
