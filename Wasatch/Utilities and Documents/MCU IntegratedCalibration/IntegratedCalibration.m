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

%
% Materials:
%   You need to be using the silicon target fabricated by Yonatan that has
%   a skipped line every 9 lines (equally spaced). Adjust the target parameters as
%   necessary if this is not the case.
%

%
% Steps:
%   1). Determine desired scanning parameters using an oscilloscope
%       to verify that there is no overlap and that triggering is
%       consistent etc.
%
%   2). Line up the farthest left line with a vertical scan, run a quick
%       3d volume to make sure that the scanning region is entirely
%       contained within the target grid. Take and save the 3d volume
%       with the slow axis parralel to the vertical edge of the grid. Also,
%       take a single fast scan rotated 90 degrees with the same length as
%       the width of the old scan.
%
%   3). Repeat 2 but with the highest horizontal line scanning downwards.
%       You will need to rotate the target and possibly re-wire the system
%       if it does not have the ability to scan the fast axis in an
%       arbitrary direction.
%
%   4). Enter the scanning parameters into the constants at the top of this
%       file, save both of the datasets to the same location as this file.
%
%   5). In this script, set scanning settings, analysis settings, and
%       target settings.
%
%   6). Run the script.
%

%
% Note:
%   - This script assumes that the fast and slow axis will be within the
%     same period of repeating line features.
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

displaySlowAxisStats = false; % Displays histograms for the spacing between major lines % TODO
displayFastAxisFit   = false; % Displays polynomial fit of coordinates along the slow versus fast axis

%% Loads Volume Data


addPath('../../../Code/myOCT/myOCT'); % myOCT repository in main code folder

% Loads 3d data, based off of Demo_3d

verticalBirdsEyeView = zeros();   % TODO compress Z values so that the entire
                                  % file can fit in this program.
horizontalBirdsEyeView = zeros(); % TODO same as above.

% Loads 2d data, based off of Demo_2d

[interfVertical, verticalDimensions] = yOCTLoadInterfFromFile(verticalFastDataPath, 'OCTSystem', OCTSystem);
verticalFastSlice = mean(log(mean(abs(yOCTInterfToScanCpx(interfVertical, verticalDimensions, 'dispersionParameterA', dispersionParameterA), 3))), 2);

[interfHorizontal, horizontalDimensions] = yOCTLoadInterfFromFile(horizontalFastDataPath, 'OCTSystem', OCTSystem);
horizontalFastSlice = mean(log(mean(abs(yOCTInterfToScanCpx(interfHorizontal, horizontalDimensions, 'dispersionParameterA', dispersionParameterA), 3))), 2);


%% Identifies slow axis coordinate conversion

% Identifies vertical 3d scan.
verticalLinesSlow = getLines(verticalBirdsEyeView, 2); % Retrieves line coordinates
verticalLinesSlow = verticalLinesSlow * (machineUnitsWide / size(verticalBirdsEyeView, 2)); % Converts to machine units
verticalLinesSlowDifs = diff(verticalLinesSlow);       % Differences to match up to pattern and convert
verticalSlowPatternIndex = xcorr(verticalLinesSlowDifs, lineSpacing);
verticalSlowPatternIndex = mod(verticalSlowPatternIndex, numel(lineSpacing));
tempShiftedPattern = circshift(lineSpacing, verticalSlowPatternIndex);
tempShiftedPattern = repmat(tempShiftedPattern, ceil(numel(verticalLinesSlowDifs) / numel(lineSpacing)));
verticalSlowFittedPattern = tempShiftedPattern(1:numel(verticalLinesSlowDifs));
verticalConvertedDifferences = verticalSlowFittedPattern./verticalLinesSlowDifs; % Units of system units / micron for all of the differences.
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
[~, verticalFastIndexBeforeLargestGap] = max(verticalLinesFastDifs);
verticalFastIndexBeforeLargestGap = mod(verticalFastIndexBeforeLargestGap, numel(lineSpacing));

[verticalLinesFastFitted, verticalLinesSlowFitted] = alignPoints(verticalLinesFast, verticalLinesSlow, verticalFastIndexBeforeLargestGap, verticalSlowPatternIndex);
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
%   TODO make robust for rotated images, maybe multiple sections?
%
function [lineCoordinates] = getLines(image, dimension)
    crossSection = mean(image, dimension);
    [pks, locs, width, prominance] = findpeaks(crossSection);
    lineCoordinates = zeros(numel(pks), 1);
    for index = 1:numel(pks) % Refines coordinate locations
        approximationRange = [floor(locs(index) + (width / 2)), ceil(locs(index) - (width / 2))];
        initialGuess = []
        aImproved = fminsearch(@(a) sum((crossSection(approximationRange) - gaussian(a, approximationRange)).^2), initialGuess);
        lineCoordinates(index) = aImproved(1);
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