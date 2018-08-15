% Erick Blankenberg
% DeLaZerda Research
% Wasatch Writer
% Calibration Data

clear all;
close all;

% Iterates over all of the image files we have, does not currently consider
% connected tile edges.

% All file sets need to be listed under a folder called '#<integer>' ex.
% '#2' and you need to put metadata in the vector below to plot. Individual
% files should be of the format 'R<integer>_C<integer>' for row and column
% indexes respectively.

%% Analyzes Images

% TODO Calibration.m: Include linear fit term for the gaussian

gaussian = @(a, x) a(1).*exp(-((x-a(2)).^2)./(2.*a(3).^2))+a(4); % Format is a = [linFit slope, linFit offset, magnitude, center, variance, baseline]

roughWUnitsPerMM = 2230; % Approximate guess for number of wasatch units per mm for scaling metadata.
upscaleFactor = 1; % Linear interpolation upscaling factor

% Image set settings, format is [fileNumber, colspacing (Wasatch Units), rowspacing (Wasatch Units), imageColumnCount, imageRowCount, individualImageWidth (mm), individualImageHeight (mm), totalWidth (mm), totalHeight (mm), individualWidthPixels, individualHeightPixels]
metaData = [ 0, 8, 8, 800, 400, 1.48, 1.48, 10.49, 11.59, 512, 512;
             1, 8, 9, 200, 100, 1.48, 1.48, 11.84, 11.80, 2048, 2048;
             2, 16, 8, 100, 200, 1.48, 1.48, 11.84, 10.77, 2048, 2048];

% Add the file number to these vectors to enable:
useSplineFit = []; % If not used, uses linear interpolation from raw
plotRowPeaks = []; % Markers for peak detection
plotRowGaussFits = [1]; % The gaussian distributions found
plotColPeaks = [];
plotColGaussFits = [];

% Positions of lines
colOutput = []; % format is [xPositionGlobalPeak, xPositionGlobalGaussFittedPeak, sourceRowIndex, sourceFileIndex];...
rowOutput = []; % format is [yPositionGlobalPeak, yPositionGlobalGaussFittedPeak, sourceColumnIndex, sourceFileIndex];...
% Differences between positions
colDiffs = []; % format is [xPositionGlobal, differenceMagnitudePeak, xPositionGaussFittedPeak, differenceMagnitudeGaussFitted, sourceRowIndex, sourceFileIndex, xPositionLocal, xPositionGaussFittedLocal, sourceColumnIndex]
rowDiffs = []; % format is [yPositionGlobal, differenceMagnitudePeak, yPositionGaussFittedPeak, differenceMagnitudeGaussFitted, sourceColumnIndex, sourceFileIndex, yPositionLocal, yPositionGaussFittedLocal, sourceRowIndex]

metaDataSize = size(metaData);
for dataIndex = 1:metaDataSize(1)
    % File Settings
    % -> Basic
    fileIndex = metaData(dataIndex, 1);
    numColImages = metaData(dataIndex, 2);
    numRowImages = metaData(dataIndex, 3);
    tileWUnitsColumns = metaData(dataIndex, 4);
    tileWUnitsRows = metaData(dataIndex, 5);
    tileWidth = metaData(dataIndex, 6); % (mm) Real width of a single tile image
    tileHeight = metaData(dataIndex, 7); % (mm) Real height of a single tile image
    totalColLength = metaData(dataIndex, 8);
    totalRowLength = metaData(dataIndex, 9);
    pixelsWide = metaData(dataIndex, 10);
    pixelsTall = metaData(dataIndex, 11);
    
    % -> Peak Detection 
    expectedDistanceMinimum_Col =  (metaData(dataIndex, 4)/roughWUnitsPerMM) * 0.8; % mm (rough guess for findpeaks)
    expectedWidthMaximum_Col =  0.15; % mm (rough guess for findpeaks)
    expectedProminanceMinimum_Col = 4; % greyscale / 255 (rough guess for findpeak)
    expectedDistanceMinimum_Row = (metaData(dataIndex, 5)/roughWUnitsPerMM) * 0.8; % mm (rough guess for findpeaks)
    expectedWidthMaximum_Row = 0.15; % mm (rough guess for findpeaks)
    expectedProminanceMinimum_Row = 4; % greyscale / 255 (rough guess for findpeak)
    % -> Gaussian Approximation
    varianceFromPeakWidth = 0.5; % Percentage factor to scale initial variance from width of the peak
    amplitudeFromPeakProminance = 1; % Percentage factor to scale initial amplitude from the prominance of the peak
    rangeWidthFromPeakWidth = 1; % Percentage factor to scale fitting range from the width of the peak
    widthToleranceFactor = 1.15; % Percentage factor to scale width by when finding points for slope line intercept of base of spike
    
    % Iterates over images to find lines
    for rowIndex = 1:numRowImages
        for colIndex = 1:numColImages
            fileString = sprintf('#%d/R%d_C%d.tif', fileIndex, rowIndex, colIndex);
            if(exist(fileString, 'file'))
                image = imread(fileString);
                normedData = image; %(image)./((max(max(image)))/255); % TODO fixme
                
                % Column cross section
                % -> Determines range
                colCrossSectionAvg = (-1.*sum(normedData, 1)./size(normedData, 1)); % Inverted to turn troughs into peaks
                if(ismember(fileIndex, useSplineFit)) % Upscales
                    colCrossSectionAvg = spline(1:length(colCrossSectionAvg), colCrossSectionAvg, linspace(0, length(colCrossSectionAvg), length(colCrossSectionAvg) * upscaleFactor));
                else
                    colCrossSectionAvg = interp1(1:length(colCrossSectionAvg), colCrossSectionAvg, linspace(0, length(colCrossSectionAvg), length(colCrossSectionAvg) * upscaleFactor));
                end
                globalPositionStart = (colIndex - 1) * (totalColLength / numColImages); % TODO may be innacurate
                colRange = (linspace(0, tileWidth, length(colCrossSectionAvg)) + globalPositionStart)';
                % -> Uses findpeaks on valleys for initial guess
                [pks_col, locs_col, width_col, prominance_col] = findpeaks(colCrossSectionAvg, colRange, 'MinPeakDistance', expectedDistanceMinimum_Col, 'MaxPeakWidth', expectedWidthMaximum_Col, 'MinPeakProminence', expectedProminanceMinimum_Col);
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
                indexVector = ones(length(locs_col), 1).*rowIndex;
                colIndexVector = ones(length(locs_col), 1).*colIndex;
                fileIndexVector = ones(length(locs_col), 1).*fileIndex;
                colOutput = [colOutput; [locs_col, gaussianLocs_col, indexVector, fileIndexVector]];
                colDiffs = [colDiffs; [0.5 * (locs_col(1:end-1) + locs_col(2:end)), diff(locs_col), 0.5 * (gaussianLocs_col(1:end-1) + gaussianLocs_col(2:end)), diff(gaussianLocs_col), indexVector(1:(end - 1)), fileIndexVector(1:(end - 1)), 0.5 * (locs_col(1:end-1) + locs_col(2:end)) - globalPositionStart, 0.5 * (gaussianLocs_col(1:end-1) + gaussianLocs_col(2:end)) - globalPositionStart, colIndexVector(1:(end - 1))]];
                % -> Plots
                if(ismember(fileIndex, plotColPeaks))
                    figure;
                    hold on;
                    findpeaks(colCrossSectionAvg, colRange, 'MinPeakDistance', expectedDistanceMinimum_Col, 'MaxPeakWidth', expectedWidthMaximum_Col, 'MinPeakProminence', expectedProminanceMinimum_Col);
                    xlabel('Y Position in mm');
                    ylabel('Intensity');
                    titleText = sprintf('File %d, Column Section for R%d-C%d.tiff',fileIndex ,rowIndex, colIndex);
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
                    titleText = sprintf('File %d, Column Section for R%d-C%d.tiff', fileIndex, rowIndex, colIndex);
                    xlabel('X position in mm');
                    ylabel('Intensity');
                    title(titleText);
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
                globalPositionStart = (rowIndex - 1) * (totalRowLength / numRowImages); % TODO may be innacurate
                rowRange = (linspace(0, tileHeight, length(rowCrossSectionAvg)) + globalPositionStart)';
                % -> Uses findpeaks on valleys for initial guess
                [pks_row, locs_row, width_row, prominance_row] = findpeaks(rowCrossSectionAvg, rowRange, 'MinPeakDistance', expectedDistanceMinimum_Row, 'MaxPeakWidth', expectedWidthMaximum_Row, 'MinPeakProminence', expectedProminanceMinimum_Row);
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
                indexVector = ones(length(locs_row), 1).*colIndex;
                rowIndexVector = ones(length(locs_row), 1).*rowIndex;
                fileIndexVector = ones(length(locs_row), 1).*fileIndex;
                rowOutput = [rowOutput; [locs_row, gaussianLocs_row, indexVector, fileIndexVector]];
                rowDiffs = [rowDiffs; [0.5 * (locs_row(1:end-1) + locs_row(2:end)), diff(locs_row), 0.5 * (gaussianLocs_row(1:end-1) + gaussianLocs_row(2:end)), diff(gaussianLocs_row), indexVector(1:(end - 1)), fileIndexVector(1:(end - 1)), 0.5 * (locs_row(1:end-1) + locs_row(2:end)) - globalPositionStart, 0.5 * (gaussianLocs_row(1:end-1) + gaussianLocs_row(2:end)) - globalPositionStart, rowIndexVector(1:(end - 1))]];
                % -> Plots
                if(ismember(fileIndex, plotRowPeaks))
                    figure;
                    hold on;
                    findpeaks(rowCrossSectionAvg, rowRange, 'MinPeakDistance', expectedDistanceMinimum_Row, 'MaxPeakWidth', expectedWidthMaximum_Row, 'MinPeakProminence', expectedProminanceMinimum_Row);
                    xlabel('Y Position in mm');
                    ylabel('Intensity');
                    titleText = sprintf('Row Section for R%d-C%d.tiff',rowIndex, colIndex);
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
                    titleText = sprintf('Row Section for R%d-C%d.tiff',rowIndex, colIndex);
                    title(titleText);
                    xlabel('Y position in mm');
                    ylabel('Intensity');
                    hold off;
                end
            else 
                errorText = sprintf('Unable to find file %s\n', fileString);
                fprintf(errorText);
            end
        end
    end
end

%% Plots Data

%close all;

% Derived mm/wasatchUnits value
plotLocalWidthVariance_Fitted = [2];
plotLocalWidthVariance_Raw = [];

% Corrected Derived mm/wasatchUnits value
plotLocalWidthVariance_Fitted_Corrected = [2];
plotLocalWidthVariance_Raw_Corrected = []; % Not implemented

% Global Spatial Difference Distribution
plotSpatialDistribution_Fitted = [];
plotSpatialDistribution_Raw = [];
plotSpatialDistribution_Fitted_CenteredMicrons = [];
plotSpatialDistribution_Raw_CenteredMicrons = [];

% Local Spatial Difference Distribution
plotLocalSpatialDistribution_Fitted = []; % Not implemented
plotLocalSpatialDistribution_Raw = []; % Not implemented
plotLocalSpatialDistribution_Fitted_CenteredMicrons = [];
plotLocalSpatialDistribution_Raw_CenteredMicrons = [];

% Correction
plotLocalSpatialCorrection_Fitted = [];

% Corrected Global Spatial Difference Distribution
plotSpatialDistribution_Fitted_Corrected = [];
plotSpatialDistribution_Fitted_Corrected_CenteredMicrons = [];

% Corrected Local Spatial Difference Distribution
plotLocalSpatialDistribution_Fitted_Corrected = [];
plotLocalSpatialDistribution_Fitted_Corrected_CenteredMicrons = [];
plotLocalSpatialDistribution_Raw_Corrected_CenteredMicrons = []; % Not implemented

for dataIndex = 1:metaDataSize(1)
    % File Settings
    % -> Basic
    fileIndex = metaData(dataIndex, 1);
    numColImages = metaData(dataIndex, 2);
    numRowImages = metaData(dataIndex, 3);
    tileWUnitsColumns = metaData(dataIndex, 4);
    tileWUnitsRows = metaData(dataIndex, 5);
    tileWidth = metaData(dataIndex, 6); % (mm) Real width of a single tile image
    tileHeight = metaData(dataIndex, 7); % (mm) Real height of a single tile image
    totalColLength = metaData(dataIndex, 8);
    totalRowLength = metaData(dataIndex, 9);
    pixelsWide = metaData(dataIndex, 10);
    pixelsTall = metaData(dataIndex, 11);
    
    % Plots histogram of Wasatch Units / MM
    if(ismember(fileIndex, plotLocalWidthVariance_Raw))
        figure;
        hold on;
        colDifferencesWU = nonzeros(((ones(length(colDiffs), 1) * tileWUnitsColumns) ./ colDiffs(:,2)).*(colDiffs(:, 6) == fileIndex));
        rowDifferencesWU = nonzeros(((ones(length(rowDiffs), 1) * tileWUnitsRows) ./ rowDiffs(:,2)).*(rowDiffs(:, 6) == fileIndex));
        range = (min([colDifferencesWU; rowDifferencesWU]):1:max([colDifferencesWU; rowDifferencesWU]))';
        % -> Columns
        %{
        pd_col = fitdist(colDifferences,'Kernel','Kernel','epanechnikov');
        y_col = pdf(pd_col, range);
        plot(range, y_col, 'LineWidth', 2, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        %}
        histogram(colDifferencesWU, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        % -> Rows
        %{
        pd_row = fitdist(rowDifferences,'Kernel','Kernel','epanechnikov');
        y_row = pdf(pd_row, range);
        plot(range, y_row, 'LineWidth', 2, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        %}
        histogram(rowDifferencesWU, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        % -> Plots
        legend('show');
        xlabel('Wasatch Units');
        ylabel('Quantity');
        titleText = sprintf('File %d, Wasatch Units / MM From Line Division Data (Raw)', fileIndex);
        title(titleText);
        hold off;
    end
    
    if(ismember(fileIndex, plotLocalWidthVariance_Fitted))
        figure;
        hold on;
        colDifferencesWU = nonzeros(((ones(length(colDiffs), 3) * tileWUnitsColumns) ./ colDiffs(:,4)).*(colDiffs(:, 6) == fileIndex));
        rowDifferencesWU = nonzeros(((ones(length(rowDiffs), 3) * tileWUnitsRows) ./ rowDiffs(:,4)).*(rowDiffs(:, 6) == fileIndex));
        range = (min([colDifferencesWU; rowDifferencesWU]):1:max([colDifferencesWU; rowDifferencesWU]))';
        % -> Columns
        %{
        pd_col = fitdist(colDifferences,'Kernel','Kernel','epanechnikov');
        y_col = pdf(pd_col, range);
        plot(range, y_col, 'LineWidth', 2, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        %}
        histogram(colDifferencesWU, 20, 'displayName', 'Fitted Column Spacing (Wasatch Units / MM)');
        sprintf('File %d, Mean is %d, Standard Deviation is %d for Columns Uncorrected', fileIndex, mean(colDifferencesWU), std(colDifferencesWU))
        % -> Rows
        %{
        pd_row = fitdist(rowDifferences,'Kernel','Kernel','epanechnikov');
        y_row = pdf(pd_row, range);
        plot(range, y_row, 'LineWidth', 2, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        %}
        histogram(rowDifferencesWU, 20, 'displayName', 'Fitted Row Spacing (Wasatch Units / MM)');
        sprintf('File %d, Mean is %d, Standard Deviation is %d for Rows Uncorrected', fileIndex, mean(rowDifferencesWU), std(rowDifferencesWU))
        % -> Plots
        legend('show');
        xlabel('Wasatch Units');
        ylabel('Quantity');
        titleText = sprintf('File %d, Wasatch Units / MM From Line Division Data (Fitted)', fileIndex);
        title(titleText);
        hold off;
    end
    
    % Plots distribution of spacing between lines in mm
    if(ismember(fileIndex, plotSpatialDistribution_Fitted))
        % Plots spatial distribution of spacing
        % -> Columns (Fitted)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            curLocations = nonzeros(colDiffs(:, 3).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(colDiffs(:, 4) .* (colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            labelText = sprintf('Row %d', rIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Spacing In MM Over Column Range (Fitted)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('X Position (mm)');
        ylabel('Difference (mm)');
        hold off;
        % -> Rows (Fitted)
        figure;
        hold on;
        for cIndex = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 3) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            labelText = sprintf('Column %d', cIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Spacing In MM Over Row Range (Fitted)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('Y Position (mm)');
        ylabel('Difference (mm)');
        hold off;
    end
    if(ismember(fileIndex, plotSpatialDistribution_Raw))
        % -> Columns (Raw)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            curLocations = nonzeros(colDiffs(:, 1).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(colDiffs(:, 2).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            labelText = sprintf('Row %d', rIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Spacing In MM Over Column Range (Raw)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('X Position (mm)');
        ylabel('Difference (mm)');
        hold off;
        % -> Rows (Raw)
        figure;
        hold on;
        for cIndex = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 1).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(rowDiffs(:, 2).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            labelText = sprintf('Column %d', cIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Spacing In MM Over Row Range (Raw)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('Y Position (mm)');
        ylabel('Difference (mm)');
        hold off;
    end
    
    % Plots distribution of spacing between lines in microns w/ mean
    % subtracted
    if(ismember(fileIndex, plotSpatialDistribution_Fitted_CenteredMicrons))
        % -> Columns (Fitted)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            curLocations = nonzeros(colDiffs(:, 3).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(colDiffs(:, 4).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = (curSpaces - mean(curSpaces)) * 1000;
            labelText = sprintf('Row %d', rIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Centered Micrometers Over Column Range (Fitted)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('X Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
        % -> Rows (Fitted)
        figure;
        hold on;
        for cIndex = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 3) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = (curSpaces - mean(curSpaces)) * 1000;
            labelText = sprintf('Column %d', cIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Centered Micrometers Over Row Range (Fitted)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('Y Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
    end
    if(ismember(fileIndex, plotSpatialDistribution_Raw_CenteredMicrons))
        % -> Columns (Raw)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            curLocations = nonzeros(colDiffs(:, 1).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(colDiffs(:, 2).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = (curSpaces - mean(curSpaces)) * 1000;
            labelText = sprintf('Row %d', rIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Centered Micrometers Over Column Range (Raw)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('X Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
        % -> Rows (Raw)
        figure;
        hold on;
        for cIndex = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 1).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(rowDiffs(:, 2).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = (curSpaces - mean(curSpaces)) * 1000;
            labelText = sprintf('Column %d', cIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        titleText = sprintf('File %d, Centered Micrometers Over Row Range (Raw)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('Y Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
    end

    % Plots spacing relative to local position in microns with mean subtracted
    if(ismember(fileIndex, plotLocalSpatialDistribution_Fitted_CenteredMicrons))
        % Plots spatial distribution of spacing
        % -> Columns (Fitted)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            for cIndex = 1:numColImages
                curLocations = nonzeros(colDiffs(:, 8).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = nonzeros(colDiffs(:, 4).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = (curSpaces - mean(curSpaces)) * 1000;
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Centered Micrometers Over Local Column Range (Fitted)', fileIndex);
        title(titleText);
        %legend('show');
        xlabel('Local X Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
        % -> Rows (Fitted)
        figure;
        hold on;
        for cIndex = 1:numColImages
            for rIndex = 1:numRowImages
                curLocations = nonzeros(rowDiffs(:, 8) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = (curSpaces - mean(curSpaces)) * 1000;
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Centered Micrometers Over Local Row Range (Fitted)', fileIndex);
        title(titleText);
        %legend('show');
        xlabel('Local Y Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
    end
    
    % Plots local spatial distribution with raw data in microns centered
    if(ismember(fileIndex, plotLocalSpatialDistribution_Raw_CenteredMicrons))
        % -> Columns (Raw)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            for cIndex = 1:numColImages
                curLocations = nonzeros(colDiffs(:, 7).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = nonzeros(colDiffs(:, 2).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = (curSpaces - mean(curSpaces)) * 1000;
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Centered Micrometers Over Local Column Range (Raw)', fileIndex);
        title(titleText);
        %legend('show');
        xlabel('Local X Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
        % -> Rows (Raw)
        figure;
        hold on;
        for rIndex = 1:numRowImages
            for cIndex = 1:numColImages
                curLocations = nonzeros(rowDiffs(:, 7).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = nonzeros(rowDiffs(:, 2).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = (curSpaces - mean(curSpaces)) * 1000;
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Centered Micrometers Over Local Row Range (Raw)', fileIndex);
        title(titleText);
        %legend('show');
        xlabel('Local Y Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
    end
    
        
    % Finds median of local distortion
    resampleSize = 20;
    % -> Local Distortion Along X
    resampleRangeCol = linspace(0, tileWidth, resampleSize);
    totalDataCol = [];
    for rIndex = 1:numRowImages
        for cIndex = 1:numColImages
            curLocations = nonzeros(colDiffs(:, 8).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
            curSpaces = nonzeros(colDiffs(:, 2).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
            if(length(curLocations) > 0)
                curSpaces = [curSpaces(1); curSpaces; curSpaces(length(curSpaces))];
                curLocations = [0; curLocations; tileWidth];
                totalDataCol = [totalDataCol; interp1(curLocations, curSpaces, resampleRangeCol, 'spline')];
            end
        end
    end
    medianFunctionCol = (median(totalDataCol, 1))./mean(median(totalDataCol, 1));
    polyFunctionCoefCol = polyfit(resampleRangeCol, medianFunctionCol, 2);
    medianFunctionCol = polyval(polyFunctionCoefCol, resampleRangeCol);
    if(ismember(fileIndex, plotLocalSpatialCorrection_Fitted))
        figure;
        hold on;
        plot(resampleRangeCol, medianFunctionCol);
        titleText = sprintf('File %d, Normalized Difference Correction Along Columns', fileIndex);
        title(titleText);
        xlabel('Local X Position (mm)');
        ylabel('Normalized Value');
        hold off;
    end
    % -> Local Distortion Along Y
    resampleRangeRow = linspace(0, tileHeight, resampleSize);
    totalDataRow = [];
    for rIndex = 1:numRowImages
        for cIndex = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 8).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
            curSpaces = nonzeros(rowDiffs(:, 2).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
            if(length(curLocations) > 0)
                curLocations = [0; curLocations; tileHeight];
                curSpaces = [curSpaces(1); curSpaces; curSpaces(length(curSpaces))];
                totalDataRow = [totalDataRow; interp1(curLocations, curSpaces, resampleRangeRow, 'spline')];
            end
        end
    end
    medianFunctionRow = (median(totalDataRow, 1))./(mean(median(totalDataRow, 1)));
    polyFunctionCoefRow = polyfit(resampleRangeRow, medianFunctionRow, 2);
    medianFunctionRow = polyval(polyFunctionCoefRow, resampleRangeRow);
    if(ismember(fileIndex, plotLocalSpatialCorrection_Fitted))
        figure;
        hold on;
        plot(resampleRangeCol, medianFunctionRow);
        titleText = sprintf('File %d, Normalized Difference Correction Along Rows', fileIndex);
        title(titleText);
        xlabel('Local Y Position (mm)');
        ylabel('Normalized Value');
        hold off;
    end
    
    % Plots Corrected Local Fitted Data
    if(ismember(fileIndex, plotLocalSpatialDistribution_Fitted_Corrected))
        % -> Columns (Fitted)
        figure;
        hold on
        for cIndex = 1:numColImages
            for rIndex = 1:numRowImages
                curLocations = nonzeros(colDiffs(:, 8) .* (colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = nonzeros(colDiffs(:, 4) .* (colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = curSpaces./interp1(resampleRangeCol, medianFunctionCol, curLocations);
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Corrected Local Differences Along Column Range (Fitted)', fileIndex);
        title(titleText);
        xlabel('Local X Position (mm)');
        ylabel('Difference (mm)');
        hold off;
        % -> Rows (Fitted)
        figure;
        hold on;
        for cIndex = 1:numColImages
            for rIndex = 1:numRowImages
                curLocations = nonzeros(rowDiffs(:, 8) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = curSpaces./interp1(resampleRangeRow, medianFunctionRow, curLocations);
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Corrected Local Differences Along Row Range (Fitted)', fileIndex);
        title(titleText);
        xlabel('Local Y Position (mm)');
        ylabel('Difference (mm)');
        hold off;
    end
    
    % Plots Corrected Local Fitted Data in Microns and Centered
    if(ismember(fileIndex, plotLocalSpatialDistribution_Fitted_Corrected_CenteredMicrons))
        % -> Columns (Fitted)
        figure;
        hold on
        for cIndex = 1:numColImages
            for rIndex = 1:numRowImages
                curLocations = nonzeros(colDiffs(:, 8) .* (colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = nonzeros(colDiffs(:, 4) .* (colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex).*(colDiffs(:, 9) == cIndex));
                curSpaces = curSpaces./interp1(resampleRangeCol, medianFunctionCol, curLocations);
                curSpaces = (curSpaces - mean(curSpaces)) * 1000;
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        title(sprintf('File %d, Corrected Local Differences Along Column Range (Fitted)', fileIndex));
        xlabel('Local X Position (mm)');
        ylabel('Difference (mm)');
        hold off;
        % -> Rows (Fitted)
        figure;
        hold on;
        for cIndex = 1:numColImages
            for rIndex = 1:numRowImages
                curLocations = nonzeros(rowDiffs(:, 8) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex).*(rowDiffs(:, 9) == rIndex));
                curSpaces = curSpaces./interp1(resampleRangeRow, medianFunctionRow, curLocations);
                curSpaces = (curSpaces - mean(curSpaces)) * 1000;
                labelText = sprintf('Column %d, Row %d', cIndex, rIndex);
                plot(curLocations, curSpaces, 'displayName', labelText);
            end
        end
        titleText = sprintf('File %d, Corrected Local Differences Along Row Range (Fitted)', fileIndex);
        title(titleText);
        xlabel('Local Y Position (mm)');
        ylabel('Difference (mm)');
        hold off;
    end
    
    % Plots Corrected Global Fitted Data in Microns and Centered
    if(ismember(fileIndex, plotSpatialDistribution_Fitted_Corrected_CenteredMicrons))
        % -> Columns (Fitted)
        figure;
        hold on;
        totalColumnVals = [];
        for rIndex = 1:numRowImages
            curLocations = nonzeros(colDiffs(:, 3).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curLocations_local = nonzeros(colDiffs(:, 8).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(colDiffs(:, 4).*(colDiffs(:, 5) == rIndex).*(colDiffs(:, 6) == fileIndex));
            curSpaces = curSpaces./interp1(resampleRangeCol, medianFunctionCol, curLocations_local);
            curSpaces = (curSpaces - mean(curSpaces)) * 1000;
            totalColumnVals = [totalColumnVals; curSpaces];
            labelText = sprintf('Row %d', rIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        totalColumnSTDEV = var(totalColumnVals).^0.5
        titleText = sprintf('File %d, Corrected Centered Micrometers Over Column Range (Fitted)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('X Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
        % -> Rows (Fitted)
        figure;
        hold on;
        totalRowVals = [];
        for cIndex = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 3) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curLocations_local = nonzeros(rowDiffs(:, 8).*(rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == cIndex).*(rowDiffs(:, 6) == fileIndex));
            curSpaces = curSpaces./interp1(resampleRangeRow, medianFunctionRow, curLocations_local);
            curSpaces = (curSpaces - mean(curSpaces)) * 1000;
            totalRowVals = [totalRowVals; curSpaces];
            labelText = sprintf('Column %d', cIndex);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        totalRowSTDEV = var(totalRowVals).^0.5
        titleText = sprintf('File %d, Corrected Centered Micrometers Over Row Range (Fitted)', fileIndex);
        title(titleText);
        legend('show');
        xlabel('Y Position (mm)');
        ylabel('Difference (\mum)');
        hold off;
    end
    
    % Plots histogram of differences w/ correction
    if(ismember(fileIndex, plotLocalWidthVariance_Fitted_Corrected))
        figure;
        hold on;
        curLocationsCols_local = nonzeros(colDiffs(:, 8).*(colDiffs(:, 6) == fileIndex));
        curSpacesCols = nonzeros(colDiffs(:, 4).*(colDiffs(:, 6) == fileIndex));
        curSpacesCols = curSpacesCols./interp1(resampleRangeCol, medianFunctionCol, curLocationsCols_local);
        colDifferencesWU = (ones(length(curSpacesCols), 1)* tileWUnitsColumns)./curSpacesCols;
        colAverage = mean(colDifferencesWU)
        curLocationsRows_local = nonzeros(rowDiffs(:, 8).*(rowDiffs(:, 6) == fileIndex));
        curSpacesRows = nonzeros(rowDiffs(:, 4).*(rowDiffs(:, 6) == fileIndex));
        curSpacesRows = curSpacesRows./interp1(resampleRangeRow, medianFunctionRow, curLocationsRows_local);
        rowDifferencesWU = (ones(length(curSpacesRows), 1)* tileWUnitsRows)./curSpacesRows;
        range = (min([colDifferencesWU; rowDifferencesWU]):1:max([colDifferencesWU; rowDifferencesWU]))';
        rowAverage = mean(rowDifferencesWU)
        % -> Columns
        %{
        pd_col = fitdist(colDifferences,'Kernel','Kernel','epanechnikov');
        y_col = pdf(pd_col, range);
        plot(range, y_col, 'LineWidth', 2, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        %}
        histogram(colDifferencesWU, 20, 'displayName', 'Fitted Column Spacing (Wasatch Units / MM)');
        sprintf('File %d, Mean is %d, Standard Deviation is %d for Columns Corrected', fileIndex, mean(colDifferencesWU), std(colDifferencesWU))
        % -> Rows
        %{
        pd_row = fitdist(rowDifferences,'Kernel','Kernel','epanechnikov');
        y_row = pdf(pd_row, range);
        plot(range, y_row, 'LineWidth', 2, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        %}
        histogram(rowDifferencesWU, 20, 'displayName', 'Fitted Row Spacing (Wasatch Units / MM)');
        sprintf('File %d, Mean is %d, Standard Deviation is %d for Rows Corrected', fileIndex, mean(rowDifferencesWU), std(rowDifferencesWU))
        % -> Plots
        legend('show');
        xlabel('Wasatch Units');
        ylabel('Quantity');
        titleText = sprintf('File %d, Wasatch Units / MM From Line Division Data Corrected (Fitted)', fileIndex);
        title(titleText);
        hold off;
    end
end

% Notes, there are some issues with sub-micron resolution

% For 1.48 mm, each pixel is 2.89 microns.
% From our estimates, each wasatch units is 0.448 microns

% Old values:
% 2292.7 WU/mm, 2278.0 WU/mm

% New Values:
% 0). 2230, 2227.5