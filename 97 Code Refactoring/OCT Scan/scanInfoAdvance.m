function scanInfoAdvance(subjectPath)
% This function advances scan info to the latest version written for LD
% Written at March 25, 2020.

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('02','LD');
end

isLoadConfigFromLog = true;

%% Set paths
volumeJsonPath_Operational = [subjectPath '/OCTVolumes/Volume/ScanInfo.json'];
volumeJsonPath_Log = [subjectPath 'Log/00 Depreciated Files Dont Use/Volume_ScanInfo.json'];
overviewJsonPath_Operational = [subjectPath '/OCTVolumes/Overview/ScanInfo.json'];
overviewJsonPath_Log = [subjectPath 'Log/00 Depreciated Files Dont Use/Overview_ScanInfo.json'];
scanConfigPath_Operational = [subjectPath '/OCTVolumes/ScanConfig.json'];
scanConfigPath_Log = [subjectPath 'Log/00 Depreciated Files Dont Use/ScanConfig.json'];

%% Read template
% Load Reference scan JSON from most up to date version
volumeRefJson = awsReadJSON([s3SubjectPath('01') '/OCTVolumes/Volume/ScanInfo.json']);

%% Load and advance volume json & overview
if ~isLoadConfigFromLog
    volumeJson = awsReadJSON(volumeJsonPath_Operational);
else
    volumeJson = awsReadJSON(volumeJsonPath_Log);
end
if (volumeJson.version ~= 1.0)
    disp('This code updates version 1.0 to 1.1, the version is wrong');
    return;
end
volumeJson = cleanupScanInfo(volumeJson, volumeRefJson.octProbe);

if ~isLoadConfigFromLog
    overviewJson = awsReadJSON(overviewJsonPath_Operational);
else
    overviewJson = awsReadJSON(overviewJsonPath_Log);
end
overviewJson = cleanupScanInfo(overviewJson, volumeRefJson.octProbe);

%% Scan Config
%scanConfigRef = awsReadJSON([s3SubjectPath('01') '/OCTVolumes/ScanConfig.json']);

if ~isLoadConfigFromLog
    scanConfig = awsReadJSON(scanConfigPath_Operational);
else
    scanConfig = awsReadJSON(scanConfigPath_Log);
end

% Remove parameters that are in the oct probe
scanConfig.volume = volumeJson;
scanConfig.overview = overviewJson;
scanConfig = rmfield(scanConfig,'octProbeFOV');
if isfield(scanConfig,'octProbeLensWorkingDistance')
    scanConfig = rmfield(scanConfig,'octProbeLensWorkingDistance');
end
scanConfig = rmfield(scanConfig,'offsetX');
scanConfig = rmfield(scanConfig,'offsetY');
scanConfig = rmfield(scanConfig,'scaleX');
scanConfig = rmfield(scanConfig,'scaleY');
scanConfig.gitBranchUsedToScan = [scanConfig.gitBranchUsedToScan ' updated on ' datestr(now)];
scanConfig.version = 2.1;
scanConfig.overview.range = scanConfig.volume.xRange;

%% Save 

% Backup copy
if ~isLoadConfigFromLog
awsCopyFileFolder(volumeJsonPath_Operational,volumeJsonPath_Log);
awsCopyFileFolder(overviewJsonPath_Operational,overviewJsonPath_Log);
awsCopyFileFolder(scanConfigPath_Operational,scanConfigPath_Log);
end

% Update
awsWriteJSON(volumeJson,volumeJsonPath_Operational);
awsWriteJSON(overviewJson,overviewJsonPath_Operational);
awsWriteJSON(scanConfig,scanConfigPath_Operational);

end

%% Helper function to cleanup ScanInfo
function scanInfoJson = cleanupScanInfo(scanInfoJson, octProbe)
if isfield(scanInfoJson,'lensWorkingDistance')
    scanInfoJson = rmfield(scanInfoJson,'lensWorkingDistance');
end
scanInfoJson.octProbe = octProbe;

% Offset and range should move to probe
scanInfoJson.octProbe.DynamicFactorX = scanInfoJson.xRange;
scanInfoJson.octProbe.OffsetX = scanInfoJson.xOffset;
scanInfoJson.xOffset = 0; % xOffset is moved to octProbe
scanInfoJson.xRange = 1; % xOffset is moved to octProbe

scanInfoJson.version = 1.1;
scanInfoJson.note = ['This config file was advanced to latest version on ' datestr(now)];
end
