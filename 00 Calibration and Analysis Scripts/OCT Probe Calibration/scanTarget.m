%This script scans an OCT image of a target or flat surface for analysis
%% Inputs

% IMPORTANT: 
% Before running this script make sure target is at focus

lens = '10x';
% What are we imaging
switch(2)
    case 1
        %Imaging a flat surface target but placing it on motorized stage so
        %we can take multiple images at different depths.
        %Notice that motorized stage might not be as 'horizontal' as an
        %optic table, which may introduce errors. Make sure to focus towrds
        %the bottom of the dish
        experimentType = 'Imaging Flat Surface On Motorized Stage';
        zDepths = [0 0.25 0.5];
    case 2
        % Similar experiment as motorized stage, but on a flat optic table
        % Image a patri dish with ater in it. Focus on the water-plastic
        % interface.
        experimentType = 'Imaging Flat Surface On Optic Table';
        zDepths = 0;
    case 3
        experimentType = 'Imaging 25um Trenches On Optic Table';
        zDepths = 0;
end

%Path to probe ini
probeIniPath = yOCTGetProbeIniPath(lens);

% Reference Scan JSON - where to get default scan parameters from
subjectPaths = s3GetAllSubjectsInLib();
subjectPath = subjectPaths{end};
config = awsReadJSON([subjectPath 'OCTVolumes/ScanConfig.json']);

% Output path 
s3OutputPath = s3SubjectPath([datestr(now,'yyyy-mm-dd') ' ' experimentType],[],true);

%% Preform scan
if ~exist(probeIniPath,'file')
    error('Cannot locate probe ini at "%s"',probeIniPath);
end
ini = yOCTReadProbeIniToStruct(probeIniPath);

% Temporary output path (before uploading to the cloud)
tmpOutputPath = [pwd '\tmp\'];

% Scan itelf
fprintf('%s Scanning Target\n',datestr(datetime));
scanParameters = yOCTScanTile (...
    tmpOutputPath, ...
    'octProbePath', probeIniPath, ...
    'tissueRefractiveIndex', config.volume.tissueRefractiveIndex, ...
    'xOffset', 0, ...
    'yOffset', 0, ... 
    'xRange', ini.RangeMaxX/2, ... We don't utilize entire FOV, edges have worse issues
    'yRange', ini.RangeMaxY/2, ... We don't utilize entire FOV, edges have worse issues
    'nXPixels', config.volume.nXPixels, ...
    'nYPixels', config.volume.nYPixels, ...
    'nBScanAvg', 1, ...
    'zDepths',  zDepths, ... [mm]
    'v',true  ...
    );

%% Preprocess scan

%If you would like to process a scan that is in the cloud, uncomment:
%tmpOutputPath = s3OutputPath

scanParameters = awsReadJSON([tmpOutputPath '\ScanInfo.json']);

x = scanParameters.xRange*linspace(-0.5,0.5,scanParameters.nXPixels) + scanParameters.xOffset; %mm
y = scanParameters.yRange*linspace(-0.5,0.5,scanParameters.nYPixels) + scanParameters.yOffset; %mm

for scanI = 1:length(scanParameters.octFolders)
    octScanPath = awsModifyPathForCompetability([tmpOutputPath '\' scanParameters.octFolders{scanI} '\']);
    
    fprintf('%s Processing Scan... (%d of %d)\n',datestr(datetime),scanI,length(scanParameters.octFolders));

    [scanAbs,dim] = yOCTProcessScan(octScanPath, 'meanAbs', 'n', scanParameters.tissueRefractiveIndex, ...
        'runProcessScanInParallel', true, 'dispersionQuadraticTerm', ini.DefaultDispersionQuadraticTerm);
        
    dim.x.values = x*1e3+scanParameters.gridXcc(scanI)*1e3;
    dim.y.values = y*1e3+scanParameters.gridYcc(scanI)*1e3;
    dim.x.units = 'microns';
    dim.y.units = 'microns';
    dim.z.values = dim.z.values+scanParameters.gridZcc(scanI)*1e3;

    %Save
    tic;
    fprintf('%s Saving Processd Scan (%d of %d)\n',datestr(datetime),scanI,length(scanParameters.octFolders));
    yOCT2Tif(mag2db(scanAbs),[octScanPath '\scanAbs.tif'],'metadata',dim);
    toc;
end

%% Copy to cloud
if ~strcmp(tmpOutputPath,s3OutputPath)
    awsCopyFileFolder(tmpOutputPath,s3OutputPath);
    rmdir(tmpOutputPath,'s')
end