% Erick Blankenberg
% DeLaZerda Research
% Wasatch Writer
% Calibration Data

clear all;
close all;

% Image set settings, format is [fileNumber, numCols, numRows, colSpacingMms, rowSpacingMms, individualImageWidth (mm), individualImageHeight (mm), individualWidthPixels, individualHeightPixels]
metaData = [ 1, 40, 20, 0.025, 0.05, 1.48, 1.48, 512, 512; 
             2, 2,  10, 0.5,  0.1,   1.48, 1.48, 4096, 4096
            ];
 
gaussian = @(a, x) a(1).*exp(-((x-a(2)).^2)./(2.*a(3).^2))+a(4); % Format is a = [linFit slope, linFit offset, magnitude, center, variance, baseline]
        
% Add the file number to these vectors to enable:
useSplineFit = []; % If not used, uses linear interpolation from raw
plotRowPeaks = [1, 2]; % Markers for peak detection
plotRowGaussFits = [1, 2]; % The gaussian distributions found
plotColPeaks = [1, 2];
plotColGaussFits = [1, 2];
upscaleFactor = 1;
   
% Positions of lines
colOutput = []; % format is [xPositionGlobalPeak, xPositionGlobalGaussFittedPeak, sourceRowIndex, sourceFileIndex];...
rowOutput = []; % format is [yPositionGlobalPeak, yPositionGlobalGaussFittedPeak, sourceColumnIndex, sourceFileIndex];...
% Differences between positions
colDiffs = []; % format is [xPositionGlobal, differenceMagnitudePeak, xPositionGaussFittedPeak, differenceMagnitudeGaussFitted, sourceRowIndex, sourceFileIndex, xPositionLocal, xPositionGaussFittedLocal, sourceColumnIndex]
rowDiffs = []; % format is [yPositionGlobal, differenceMagnitudePeak, yPositionGaussFittedPeak, differenceMagnitudeGaussFitted, sourceColumnIndex, sourceFileIndex, yPositionLocal, yPositionGaussFittedLocal, sourceRowIndex]

% Corrects for spatial distortion, polynomial values taken from calibration
% script

normCorrectionCoeffCol = [-0.0400854680549345,0.0529592929412983,0.990848063222331];
normCorrectionCoeffRow = [-0.0347684084524213,0.0426847571067572,0.994466895119010];

% Just loads a single image to quickly look for peaks and show distances
for dataIndex = 1:size(metaData, 1)
    % -> Basic
    fileIndex = metaData(dataIndex, 1);
    numCols = metaData(dataIndex, 2); % Number of columns in the image
    numRows = metaData(dataIndex, 3); % Number of rows in the image
    colSpacing = metaData(dataIndex, 4); % (mm) Real ideal distance between columns in the image
    rowSpacing = metaData(dataIndex, 5); % (mm) Real ideal distance between rows in the image
    tileWidth = metaData(dataIndex, 6); % (mm) Real width of a single tile image
    tileHeight = metaData(dataIndex, 7); % (mm) Real height of a single tile image
    pixelsWide = metaData(dataIndex, 8);
    pixelsTall = metaData(dataIndex, 9);
    
    % -> Peak Detection 
    expectedPeaks_Col = numCols;
    expectedDistanceMinimum_Col =  colSpacing * 0.45; % mm (rough guess for findpeaks)
    expectedWidthMaximum_Col =  0.05; % mm (rough guess for findpeaks)
    expectedProminanceMinimum_Col = 15; % greyscale / 255 (rough guess for findpeak)
    expectedPeaks_Row = numRows;
    expectedDistanceMinimum_Row = rowSpacing * 0.65; % mm (rough guess for findpeaks)
    expectedWidthMaximum_Row = 0.05; % mm (rough guess for findpeaks)
    expectedProminanceMinimum_Row = 15; % greyscale / 255 (rough guess for findpeak)
    % -> Gaussian Approximation
    varianceFromPeakWidth = 0.5; % Percentage factor to scale initial variance from width of the peak
    amplitudeFromPeakProminance = 1; % Percentage factor to scale initial amplitude from the prominance of the peak
    rangeWidthFromPeakWidth = 1; % Percentage factor to scale fitting range from the width of the peak
    widthToleranceFactor = 1.15; % Percentage factor to scale width by when finding points for slope line intercept of base of spike
    
    % -> Analyzes cross section of the image
    fileString = sprintf('Verification_%d/Data.tif', fileIndex);
    if(exist(fileString, 'file'))
        image = imread(fileString);
        normedData = (image)./((max(max(image)))/255); % TODO fixme

        % Column cross section
        % -> Determines range
        colCrossSectionAvg = (-1.*sum(normedData, 1)./size(normedData, 1)); % Inverted to turn troughs into peaks
        if(ismember(fileIndex, useSplineFit)) % Upscales
            colCrossSectionAvg = spline(1:length(colCrossSectionAvg), colCrossSectionAvg, linspace(0, length(colCrossSectionAvg), length(colCrossSectionAvg) * upscaleFactor));
        else
            colCrossSectionAvg = interp1(1:length(colCrossSectionAvg), colCrossSectionAvg, linspace(0, length(colCrossSectionAvg), length(colCrossSectionAvg) * upscaleFactor));
        end
        colRange = (linspace(0, tileWidth, length(colCrossSectionAvg)))';
        % -> Uses findpeaks on valleys for initial guess
        [pks_col, locs_col, width_col, prominance_col] = findpeaks(colCrossSectionAvg, colRange, 'MinPeakDistance', expectedDistanceMinimum_Col, 'MaxPeakWidth', expectedWidthMaximum_Col, 'MinPeakProminence', expectedProminanceMinimum_Col, 'NPeaks', expectedPeaks_Col);
        % -> Finds sub-pixel approximation by fitting gaussian to peaks
        gaussianApproximations_col = [];
        gaussianFirstGuess_col = [];
        for rIndex = 1:length(locs_col)
            % --> Range
            startIndex = find(colRange > (locs_col(rIndex) - (width_col(rIndex) * rangeWidthFromPeakWidth)/2), 1);
            stopIndex = find(colRange > (locs_col(rIndex) + (width_col(rIndex) * rangeWidthFromPeakWidth)/2), 1);
            approximationRange = colRange(startIndex:stopIndex, 1);
            % --> Magnitude
            magnitude = prominance_col(rIndex) * amplitudeFromPeakProminance;
            % --> Variance
            variance = width_col(rIndex) * varianceFromPeakWidth;
            % --> Calculates
            initialGuess = [magnitude, locs_col(rIndex), variance, pks_col(rIndex) - magnitude];
            result = fminsearch(@(a) sum((colCrossSectionAvg(startIndex: stopIndex)' - gaussian(a, approximationRange)).^2), initialGuess);
            gaussianApproximations_col = [gaussianApproximations_col; result];
            gaussianFirstGuess_col = [gaussianFirstGuess_col; initialGuess];
        end
        gaussianLocs_col = gaussianApproximations_col(:, 2);
        fileIndexVector = ones(length(locs_col), 1).*fileIndex;
        colOutput = [colOutput; [locs_col, gaussianLocs_col, fileIndexVector]];
        colDiffs = [colDiffs; [0.5 * (locs_col(1:end-1) + locs_col(2:end)), diff(locs_col), 0.5 * (gaussianLocs_col(1:end-1) + gaussianLocs_col(2:end)), diff(gaussianLocs_col), fileIndexVector(1:(end - 1))]];
        % -> Plots
        if(ismember(fileIndex, plotColPeaks))
            figure;
            hold on;
            findpeaks(colCrossSectionAvg, colRange, 'MinPeakDistance', expectedDistanceMinimum_Col, 'MaxPeakWidth', expectedWidthMaximum_Col, 'MinPeakProminence', expectedProminanceMinimum_Col, 'NPeaks', expectedPeaks_Col);
            titleText = sprintf('Column Section for File %d', fileIndex);
            xlabel('X Position in mm');
            ylabel('Intensity');
            title(titleText);
            hold off;
        end

        if(ismember(fileIndex, plotColGaussFits))
            figure;
            hold on;
            plot(colRange, colCrossSectionAvg);
            for rIndex = 1:length(locs_col)
                range = linspace(gaussianFirstGuess_col(rIndex, 2) - gaussianFirstGuess_col(rIndex, 3) * 2, gaussianFirstGuess_col(rIndex, 2) + gaussianFirstGuess_col(rIndex, 3) * 2, 1000);
                plot(range, gaussian(gaussianFirstGuess_col(rIndex, :), range), 'Color', [0.4660, 0.6740, 0.1880], 'displayName', 'First Guess');
                plot(range, gaussian(gaussianApproximations_col(rIndex, :), range), 'Color', [0.8500, 0.3250, 0.0980], 'displayName', 'Fitted Data');
            end
            titleText = sprintf('Column Section for File %d', fileIndex);
            title(titleText);
            xlabel('X position in mm');
            ylabel('Intensity');
            hold off;
        end

        % Row cross section
        % -> Determines range
        rowCrossSectionAvg = -1.*sum(normedData, 2)./size(normedData, 2); % Inverted to turn troughs into peaks
        if(ismember(fileIndex, useSplineFit)) % Upscales
            rowCrossSectionAvg = spline(1:length(rowCrossSectionAvg), rowCrossSectionAvg, linspace(0, length(rowCrossSectionAvg), length(rowCrossSectionAvg) * upscaleFactor));
        else
            rowCrossSectionAvg = interp1(1:length(rowCrossSectionAvg), rowCrossSectionAvg, linspace(0, length(rowCrossSectionAvg), length(rowCrossSectionAvg) * upscaleFactor));
        end
        rowRange = (linspace(0, tileHeight, length(rowCrossSectionAvg)))';
        % -> Uses findpeaks on valleys for initial guess
        [pks_row, locs_row, width_row, prominance_row] = findpeaks(rowCrossSectionAvg, rowRange, 'MinPeakDistance', expectedDistanceMinimum_Row, 'MaxPeakWidth', expectedWidthMaximum_Row, 'MinPeakProminence', expectedProminanceMinimum_Row, 'NPeaks', expectedPeaks_Row);
        % -> Finds sub-pixel approximation by fitting gaussian to peaks
        gaussianApproximations_row = [];
        gaussianFirstGuess_row = [];
        for rIndex = 1:length(locs_row)
            % --> Range
            startIndex = find(rowRange > (locs_row(rIndex) - (width_row(rIndex) * rangeWidthFromPeakWidth)/2), 1);
            stopIndex = find(rowRange > (locs_row(rIndex) + (width_row(rIndex) * rangeWidthFromPeakWidth)/2), 1);
            approximationRange = rowRange(startIndex:stopIndex, 1);
            % --> Magnitude
            magnitude = prominance_row(rIndex) * amplitudeFromPeakProminance;
            % --> Variance
            variance = width_row(rIndex) * varianceFromPeakWidth;
            % --> Calculates
            initialGuess = [magnitude, locs_row(rIndex), variance, pks_row(rIndex) - magnitude];
            result = fminsearch(@(a) sum((rowCrossSectionAvg(startIndex: stopIndex)' - gaussian(a, approximationRange)).^2), initialGuess);
            gaussianApproximations_row = [gaussianApproximations_row; result];
            gaussianFirstGuess_row = [gaussianFirstGuess_row; initialGuess];
        end
        gaussianLocs_row = gaussianApproximations_row(:, 2);
        fileIndexVector = ones(length(locs_row), 1).*fileIndex;
        rowOutput = [rowOutput; [locs_row, gaussianLocs_row, fileIndexVector]];
        rowDiffs = [rowDiffs; [0.5 * (locs_row(1:end-1) + locs_row(2:end)), diff(locs_row), 0.5 * (gaussianLocs_row(1:end-1) + gaussianLocs_row(2:end)), diff(gaussianLocs_row), fileIndexVector(1:(end - 1))]];
        % -> Plots
        if(ismember(fileIndex, plotRowPeaks))
            figure;
            hold on;
            findpeaks(rowCrossSectionAvg, rowRange, 'MinPeakDistance', expectedDistanceMinimum_Row, 'MaxPeakWidth', expectedWidthMaximum_Row, 'MinPeakProminence', expectedProminanceMinimum_Row, 'NPeaks', expectedPeaks_Row);
            ylabel('Intensity');
            xlabel('Y Position in mm');
            titleText = sprintf('Row Section for File %d', fileIndex);
            title(titleText);
            hold off;
        end
        if(ismember(fileIndex, plotRowGaussFits))
            figure;
            hold on;
            plot(rowRange, rowCrossSectionAvg);
            for rIndex = 1:length(locs_row)
                range = linspace(gaussianFirstGuess_row(rIndex, 2) - gaussianFirstGuess_row(rIndex, 3) * 2, gaussianFirstGuess_row(rIndex, 2) + gaussianFirstGuess_row(rIndex, 3) * 2, 1000);
                plot(range, gaussian(gaussianFirstGuess_row(rIndex, :), range), 'Color', [0.4660, 0.6740, 0.1880]);
                plot(range, gaussian(gaussianApproximations_row(rIndex, :), range), 'Color', [0.8500, 0.3250, 0.0980]);
            end
            titleText = sprintf('Row Section for File %d', fileIndex);
            title(titleText);
            ylabel('Intensity');
            xlabel('Y position in mm');
            hold off;
        end
    else 
        errorText = sprintf('Unable to find file %s\n', fileString);
        fprintf(errorText);
    end
end

% Reads out results
for dataIndex = 1:size(metaData, 1)
    fileIndex = metaData(dataIndex, 1);
    colSpacing = metaData(dataIndex, 4); % (mm) Real ideal distance between columns in the image
    rowSpacing = metaData(dataIndex, 5); % (mm) Real ideal distance between rows in the image
    % -> Columns
    currentColDiffs = nonzeros(colDiffs(:, 4).*(colDiffs(:, 5) == fileIndex));
    currentColDiffLocations = nonzeros(colDiffs(:, 3).*(colDiffs(:, 5) == fileIndex));
    figure
    hold on;
    currentColDiffsUncorrected = (currentColDiffs - colSpacing).* (10^3);
    displayText = sprintf('Uncorrected, avg. %f (\mum)', mean(currentColDiffsUncorrected));
    plot(currentColDiffLocations, currentColDiffsUncorrected, 'displayName', displayText);
    currentColDiffs = currentColDiffs./polyval(normCorrectionCoeffCol, currentColDiffLocations); % Corrects values
    currentColDiffsCorrected = (currentColDiffs - colSpacing).* (10^3);
    displayText = sprintf('Corrected, avg. %f (\mum)', mean(currentColDiffsCorrected));
    plot(currentColDiffLocations, currentColDiffsCorrected, 'displayName', displayText);
    legend('show');
    titleText = sprintf('File %d, Column Differences Over Column Range', fileIndex);
    title(titleText);
    xlabel('X Position (mm)');
    ylabel('Centered Difference (\mum)');
    sprintf('Column Mean Distance is %f Standard Deviation %f for File %d, Ratio is %f', mean(currentColDiffsCorrected(2:end)), std(currentColDiffsCorrected(2:end)), fileIndex, mean(currentColDiffs) / colSpacing)
    hold off;
    
    % -> Rows 
    currentRowDiffs = nonzeros(rowDiffs(:, 4).*(rowDiffs(:, 5) == fileIndex));
    currentRowDiffLocations = nonzeros(rowDiffs(:, 3).*(rowDiffs(:, 5) == fileIndex));
    figure
    hold on;
    currentRowDiffsUncorrected = (currentRowDiffs - rowSpacing).* (10^3);
    displayText = sprintf('Uncorrected, avg. %f (\mum)', mean(currentRowDiffsUncorrected));
    plot(currentRowDiffLocations, currentRowDiffsUncorrected, 'displayName', displayText);
    currentRowDiffs = currentRowDiffs./polyval(normCorrectionCoeffRow, currentRowDiffLocations); % Corrects values
    currentRowDiffsCorrected = (currentRowDiffs - rowSpacing).* (10^3);
    displayText = sprintf('Corrected, avg. %f (\mum)', mean(currentRowDiffsCorrected));
    plot(currentRowDiffLocations, currentRowDiffsCorrected, 'displayName', displayText);
    legend('show');
    titleText = sprintf('File %d, Row Differences Over Row Range', fileIndex);
    title(titleText);
    xlabel('Y Position (mm)');
    ylabel('Centered Difference (\mum)');
    sprintf('Row Mean Distance is %f Standard Deviation is %f for File %d, Ratio is %f', mean(currentRowDiffsCorrected), std(currentRowDiffsCorrected), fileIndex,  mean(currentRowDiffs) / rowSpacing)
    
    hold off;
end