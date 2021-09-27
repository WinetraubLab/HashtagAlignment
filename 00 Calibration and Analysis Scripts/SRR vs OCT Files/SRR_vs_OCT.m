% Place this script in the main jenkins folder and run it

%% Step #1 - Open Thorlabs and Take a Screenshot

% Open Thorlabs and scan a skin tissue. Place beam near the top of the skin
% such that you can see cells.

% Take a screenshot - save file as SRR_vs_OCT_Step1.png

%% Step #2 - .OCT Scan

% Using Thorlab's UI, follow these instructions
% 1) Change probe to 40x <- This step is IMPORTANT!
% 2) Set scan parameters: 
%       Scan along X axis (angle=0)
%       Middle of the scan should be (0,0)
%       Size 1000 pixles
%       FOV: 0.5 mm
%       Pixel Size 0.5 um
%       B-Scan / A-Scan averaging - no
%       Number of Frames: 1
% 3) Save scan as SRR_vs_OCT_Step2.oct

%% Step #3 - .SRR Scan

% Add path
currentFileFolder = [fileparts(mfilename('fullpath')) '\'];
addpath(genpath(currentFileFolder));
ThorlabsImagerNETLoadLib();
outputFolder = 'SRR_vs_OCT_Step3\';


scanParameters = yOCTScanTile (...
    outputFolder, ...
    'octProbePath', getProbeIniPath('40x'), ...
    'tissueRefractiveIndex', 1.4, ...
    'xOffset',   0, ...
    'yOffset',   0, ... 
    'xRange',    0.5, ...
    'yRange',    0.005, ...
    'nXPixels',  1000, ...
    'nYPixels',  2, ...
    'nBScanAvg', 1, ...
    'zDepths',   0, ... [mm]
	'oct2stageXYAngleDeg', -1.95, ...
    'v',true  ...
    );

%% Step #4

% Copy SRR_vs_OCT_Step1.png, SRR_vs_OCT_Step2.oct, SRR_vs_OCT_Step3 to the
% Matlab server for further processing