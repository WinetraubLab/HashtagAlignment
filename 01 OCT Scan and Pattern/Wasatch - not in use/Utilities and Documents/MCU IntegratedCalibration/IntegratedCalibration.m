%
% File: IntegratedCalibration.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This program identifies the units per mm of the given OCT system,
%   the slow axis determines the units/mm, the fast axis also has a scaling
%   and offset to be determined. It is assumed that the slow axis is
%   consistent. This is applied to both the X and Y axis of the system.
%
%   See the included tutorial presentation for how to use this file to
%   calibrate the system.
%

clear all;
close all;

% TODO pixels != system units, direct conversion is not realistic, revisit.

%% Target Settings

% Distance between lines in microns, format is [1-2, 2-3, 3-4, ..., last-1]
lineSpacing  = [100, 100, 100, 100, 100, 100, 100, 100, 200]; 

%% Scanning Settings

machineUnitsWide = 0; % The width and length of the 3d volumes and the length 
                      % of the fast scan, it is assumed  that slow scan coordinates
                      % are evenly distributed along this range % TODO

verticalSlowDataPath = ''; % TODO
verticalFastDataPath = ''; % TODO
horizontalSlowDataPath = ''; % TODO
horizontalFastDataPath = ''; % TODO
OCTSystem = 'Wasatch';
dispersionParameterA = 100; % Use Demo_DispersionCorrection to find the term

%% Analysis Settings

% Debugging
displaySlowAxisStats = false; % Displays histograms for the spacing between major lines % TODO
displayFastAxisFit   = false; % Displays polynomial fit of coordinates along the slow versus fast axis

% Find Peaks
findPks_searchRangeMultiplier = 1.5; % Multiplied by peak width for range of fitting analysis
findPks_varianceMultiplier = 1.2; % Multiplied by peak width for initial guess for variance gaussian distribution
findPks_magnitudeMultiplier = 1.5; % Multiplied by peak height to get initial guess for magnitude

%% Loads Volume Data


addPath('../../../Code/myOCT/myOCT'); % myOCT repository in main code folder

% Loads 3d data, based off of Demo_3d


verticalBirdsEyeView = zeros();   % TODO compress Z values so that the entire
                                  % file can fit in this program.
horizontalBirdsEyeView = zeros(); % TODO same as above.

% Loads 2d data, based off of Demo_2d

verticalFastSlice = 0;

horizontalFastSlice = 0;


%% Identifies slow axis coordinate conversion

% Identifies vertical 3d scan.
verticalLinesSlow = getLines(verticalBirdsEyeView, 2); % Retrieves line coordinates
verticalLinesSlow = verticalLinesSlow * (machineUnitsWide / size(verticalBirdsEyeView, 2)); % Converts to machine units
verticalLinesSlowDifs = diff(verticalLinesSlow);       % Differences to match up to pattern and convert
[verticalLinesSlowPatternOffset, verticalLinesSlowPattern] = getPatternOffset(lineSpacing, verticalLinesSlowDifs);
verticalConvertedDifferences = verticalLinesSlowDifs./verticalLinesSlowPattern; % Units of system units / micron for all of the differences.
verticalSysPerMicron = mean(verticalConvertedDifferences); % Units of system units / micron.
if(displaySlowAxisStats) 
    figure;
    hold on;
    histogram(verticalConvertedDifferences);
    title('Distribution of Calculated System Unit Conversion');
    xlable(sprintf('System Unit/\mum, Average is %f0.2', verticalSysPerMicron));
    ylable('Occurances');
    hold off;
end

% Identifies horizontal 3d scan.
% TODO once done with vertical


%% Identifies fast axis offset and scaling

% Finds scaling and offset for vertical scans
verticalLinesFast = getLines(verticalFastSlice, 2);
verticalLinesFast = verticalLinesFast * (machineUnitsWide / size(verticalBirdsEyeView, 2)); % Converts to machine units
verticalLinesFastDifs = diff(verticalLinesFast);
[verticalLinesFastOffset, ~] = getPatternOffset(lineSpacing, verticalLinesFastDifs);
[verticalLinesFastFitted, verticalLinesSlowFitted] = alignPoints(verticalLinesFast, verticalLinesSlow, verticalLinesFastOffset, verticalLinesSlowOffset);
verticalFastParameters = polyfit(verticalLinesFastFitted, verticalLinesSlowFitted, 1); % Polynomial maps fast coordinates to slow coordinates TODO
if(displayFastAxisFit)
    figure;
    hold on;
    title('Paired Coordinates Along Fast and Slow Vertical Axis');
    xlabel('Fast Axis Locations');
    ylabel('Slow Axis Locations');
    scatter(verticalLinesFastFitted, verticalLinesSlowFitted, 'displayName', 'Raw Correspondance');
    range = xlim;
    plot(polyval(verticalFastParameters, range(1):range(2), 'displayName', 'Fitted Curve, Slope = , Offset = ')); % TODO add um measurements
    hold off;
end

% Finds scaling and offset for horizontal scans
% TODO once vertical works

%% Functions

%
% Description:
%
function meanAbs = loadSlice(folderDirectory, octSystem)
    dispersionParameterA = 100; %Use Demo_DispersionCorrection to find the term
    [interf,dimensions] = yOCTLoadInterfFromFile(folderDirectory,'OCTSystem', octSystem);

    %Generate BScans
    scanCpx = yOCTInterfToScanCpx(interf,dimensions,'dispersionParameterA', dispersionParameterA);
    meanAbs = mean(mean(abs(scanCpx, 3)), 1);
end

%
% Description:
%
function meanAbs = loadTopDown(folderDirectory, octSystem)
    dispersionParameterA = 100;
    OCTVolumeFile = [folderDirectory '\scanAbs.tif'];
    if ~exist(OCTVolumeFile,'file')
        % Load OCT
        meanAbs = yOCTProcessScan(folderDirectory, 'meanAbs', 'OCTSystem', octSystem, 'dispersionParameterA', dispersionParameterA);
        % Saves for later
        yOCT2Tif(meanAbs,OCTVolumeFile); 
    else
        info = imfinfo(OCTVolumeFile);
        meanAbs = zeros(info.height, info.width, size(info,1));
        for i= 1:1:size(info,1)
            meanAbs(:, :, i) = imread(OCTVolumeFile,i);
        end
    end
    meanAbs = mean(log(meanAbs), 1);
end


%
% Description:
%   Assuming that the targetVector is a periodic function
%   whose underlying element is of the same length and 
%   relative proportions of the vector pattern.
%
% Parameters:
%   'pattern'        The pattern to match, needs to be the same length
%                    as the period of targetVector. The returned offset is the
%                    smallest positive offset to shift pattern up to match
%                    the targetVector.
%   'targetVector'   The sample to match the pattern to, assumed to be
%                    perioidic with the same period as the length of the 
%                    pattern.
%
% Returns:
%   'offsetIndex'    How far the pattern is shifted forwards.
%   'matchedPattern' Vector of pattern matched to the original.
%
function [offsetIndex, matchedPattern] = getPatternOffset(pattern, targetVector)
    matchedPattern = repmat(pattern, ceil(numel(targetVector) / numel(pattern)));
    offsetIndex = max(abs(xcorr(targetVector, matchedPattern)));
    offsetIndex = mod(offsetIndex, numel(lineSpacing));
    matchedPattern = circshift(matchedPattern, offsetIndex);
    matchedPattern = matchedPattern(1:numel(targetVector));
end

%
% Description:
%   Fits two patterns together with associated landmarks
%
% Parameters:
%   'vectorA' First array of values to match
%   'vectorB' Second array of values to match
%   'indexA'  Landmark location in A
%   'indexB'  Corresponding landmark location in B
%
% Returns:
%   'matchedA' Cropped array with corresponding points B
%   'matchedB' Cropped array with corresponding points A
%
function [matchedA, matchedB] = alignPoints(vectorA, vectorB, indexA, indexB)
    minOffset = min(indexA, indexB);
    maxOffset = min(numel(indexA)- indexA, numel(indexB) - indexB);
    matchedA = vectorA(indexA - minOffset: indexA + maxOffset);
    matchedB = vectorB(indexB - minOffset: indexB + maxOffset);
end

%
% Description:
%   Takes in an image and identifies high points along the given axis.
%
% Parameters:
%   'image'     A 2d image featuring the desired lines perpendicular to the
%               given dimension.
%   'dimension' The dimension to search for lines along.
%
%   TODO make robust for rotated images, maybe divide into multiple sections?
%
function [lineCoordinates] = getLines(image, dimension)
    crossSection = mean(image, dimension);
    crossSection; % TODO 
    [pks, locs, width, magnitude] = findpeaks(crossSection); % Add extra parameters to make more stable
    lineCoordinates = zeros(numel(pks), 1);
    for index = 1:numel(pks) % Refines coordinate locations
        approximationRange = [floor(locs(index) + (width / 2) * findPks_searchRangeMultiplier), ceil(locs(index) - (width / 2) * findPks_searchRangeMultiplier)];
        guessMagnitude = magnitude(index) * findPks_magnitudeMultiplier;
        guessVariance = width(index) * findPks_varianceMultiplier;
        initialGuess = [guessMagnitude, locs(index), guessVariance, pks(index)];
        aImproved = fminsearch(@(a) sum((crossSection(approximationRange) - gaussian(a, approximationRange)).^2), initialGuess);
        lineCoordinates(index) = aImproved(2);
    end
end

%
% Description:
%   This is a Gaussian distribution.
%
% Parameters:
%   'x' Coordinates to evaluate at
%   'a' Parameters for the gaussian, format is
%       [linFit slope, linFit offset, magnitude, center, variance, baseline]
%
function result = gaussian(a, x) 
    result = a(1).*exp(-((x-a(2)).^2)./(2.*a(3).^2))+a(4);
end