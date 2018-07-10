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

% TODO Calibration.m: Include linear fit term for the gaussian

gaussian = @(a, x) a(1).*exp(-((x-a(2)).^2)./(2.*a(3).^2))+a(4); % Format is a = [linFit slope, linFit offset, magnitude, center, variance, baseline]

roughWUnitsPerMM = 2230; % Approximate guess for number of wasatch units per mm for scaling metadata.
upscaleFactor = 1; % Linear interpolation upscaling factor

% Image set settings, format is [fileNumber, colspacing (Wasatch Units), rowspacing (Wasatch Units), imageColumnCount, imageRowCount, individualImageWidth (mm), individualImageHeight (mm), totalWidth (mm), totalHeight (mm), individualWidthPixels, individualHeightPixels]
metaData = [ 0, 8, 8, 800, 400, 1.48, 1.48, 10.49, 11.59, 512, 512; % TODO verify metadata for #1
            ];

% Add the file number to these vectors to enable:
useSplineFit = []; % If not used, uses linear interpolation from raw
plotRowPeaks = []; % Markers for peak detection
plotRowGaussFits = []; % The gaussian distributions found
plotColPeaks = [0];
plotColGaussFits = [0];
plotLocalSpatialDistribution = [0];
plotLocalWidthVariance = [0];

% Positions of lines
colOutput = []; % format is [xPositionGlobalPeak, xPositionGlobalGaussFittedPeak, sourceRowIndex, sourceSetIndex];...
rowOutput = []; % format is [yPositionGlobalPeak, yPositionGlobalGaussFittedPeak, sourceColumnIndex, sourceSetIndex];...
% Differences between positions
colDiffs = []; % format is [xPositionGlobal, differenceMagnitudePeak, xPositionGaussFittedPeak, differenceMagnitudeGaussFitted, sourceRowIndex]
rowDiffs = []; % format is [yPositionGlobal, differenceMagnitudePeak, yPositionGaussFittedPeak, differenceMagnitudeGaussFitted, sourceColumnIndex]

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
    expectedDistanceMinimum_Col =  (metaData(dataIndex, 4)/roughWUnitsPerMM) * 0.9; % mm (rough guess for findpeaks)
    expectedWidthMaximum_Col =  0.15; % mm (rough guess for findpeaks)
    expectedProminanceMinimum_Col = 4; % greyscale / 255 (rough guess for findpeak)
    expectedDistanceMinimum_Row = (metaData(dataIndex, 5)/roughWUnitsPerMM) * 0.9; % mm (rough guess for findpeaks)
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
                for index = 1:length(locs_col)
                    % --> Range
                    startIndex = find(colRange > (locs_col(index) - (width_col(index) * rangeWidthFromPeakWidth)/2), 1);
                    stopIndex = find(colRange > (locs_col(index) + (width_col(index) * rangeWidthFromPeakWidth)/2), 1);
                    approximationRange = colRange(startIndex:stopIndex, 1);
                    % --> Magnitude
                    magnitude = prominance_col(index) * amplitudeFromPeakProminance;
                    % --> Variance
                    variance = width_col(index) * varianceFromPeakWidth;
                    % --> Calculates
                    initialGuess = [magnitude, locs_col(index), variance, pks_col(index) - magnitude];
                    result = fminsearch(@(a) sum((colCrossSectionAvg(startIndex: stopIndex)' - gaussian(a, approximationRange)).^2), initialGuess);
                    gaussianApproximations_col = [gaussianApproximations_col; result];
                    gaussianFirstGuess_col = [gaussianFirstGuess_col; initialGuess];
                end
                gaussianLocs_col = gaussianApproximations_col(:, 2);
                indexVector = ones(length(locs_col), 1).*rowIndex;
                fileIndexVector = ones(length(locs_col), 1).*fileIndex;
                colOutput = [colOutput; [locs_col, gaussianLocs_col, indexVector, fileIndexVector]];
                colDiffs = [colDiffs; [0.5 * (locs_col(1:end-1) + locs_col(2:end)), diff(locs_col), 0.5 * (gaussianLocs_col(1:end-1) + gaussianLocs_col(2:end)), diff(gaussianLocs_col), indexVector(1:(end - 1)), fileIndexVector(1:(end - 1))]];
                % -> Plots
                if(ismember(fileIndex, plotColPeaks))
                    figure;
                    hold on;
                    findpeaks(colCrossSectionAvg, colRange, 'MinPeakDistance', expectedDistanceMinimum_Col, 'MaxPeakWidth', expectedWidthMaximum_Col, 'MinPeakProminence', expectedProminanceMinimum_Col);
                    titleText = sprintf('Column Section for R%d-C%d.tiff',rowIndex, colIndex);
                    xlabel('x position in mm');
                    ylabel('Y position in mm');
                    title(titleText);
                    hold off;
                end
                
                if(ismember(fileIndex, plotColGaussFits))
                    figure;
                    hold on;
                    plot(colRange, colCrossSectionAvg);
                    for index = 1:length(locs_col)
                        range = linspace(gaussianFirstGuess_col(index, 2) - gaussianFirstGuess_col(index, 3) * 2, gaussianFirstGuess_col(index, 2) + gaussianFirstGuess_col(index, 3) * 2, 1000);
                        plot(range, gaussian(gaussianFirstGuess_col(index, :), range), 'Color', [0.4660, 0.6740, 0.1880], 'displayName', 'First Guess');
                        plot(range, gaussian(gaussianApproximations_col(index, :), range), 'Color', [0.8500, 0.3250, 0.0980], 'displayName', 'Fitted Data');
                    end
                    titleText = sprintf('Column Section for R%d-C%d.tiff',rowIndex, colIndex);
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
                globalPositionStart = (rowIndex - 1) * (totalRowLength / numRowImages); % TODO may be innacurate
                rowRange = (linspace(0, tileHeight, length(rowCrossSectionAvg)) + globalPositionStart)';
                % -> Uses findpeaks on valleys for initial guess
                [pks_row, locs_row, width_row, prominance_row] = findpeaks(rowCrossSectionAvg, rowRange, 'MinPeakDistance', expectedDistanceMinimum_Row, 'MaxPeakWidth', expectedWidthMaximum_Row, 'MinPeakProminence', expectedProminanceMinimum_Row);
                % -> Finds sub-pixel approximation by fitting gaussian to peaks
                gaussianApproximations_row = [];
                gaussianFirstGuess_row = [];
                for index = 1:length(locs_row)
                    % --> Range
                    startIndex = find(rowRange > (locs_row(index) - (width_row(index) * rangeWidthFromPeakWidth)/2), 1);
                    stopIndex = find(rowRange > (locs_row(index) + (width_row(index) * rangeWidthFromPeakWidth)/2), 1);
                    approximationRange = rowRange(startIndex:stopIndex, 1);
                    % --> Magnitude
                    magnitude = prominance_row(index) * amplitudeFromPeakProminance;
                    % --> Variance
                    variance = width_row(index) * varianceFromPeakWidth;
                    % --> Calculates
                    initialGuess = [magnitude, locs_row(index), variance, pks_row(index) - magnitude];
                    result = fminsearch(@(a) sum((rowCrossSectionAvg(startIndex: stopIndex)' - gaussian(a, approximationRange)).^2), initialGuess);
                    gaussianApproximations_row = [gaussianApproximations_row; result];
                    gaussianFirstGuess_row = [gaussianFirstGuess_row; initialGuess];
                end
                gaussianLocs_row = gaussianApproximations_row(:, 2);
                indexVector = ones(length(locs_row), 1).*colIndex;
                fileIndexVector = ones(length(locs_row), 1).*fileIndex;
                rowOutput = [rowOutput; [locs_row, gaussianLocs_row, indexVector, fileIndexVector]];
                rowDiffs = [rowDiffs; [0.5 * (locs_row(1:end-1) + locs_row(2:end)), diff(locs_row), 0.5 * (gaussianLocs_row(1:end-1) + gaussianLocs_row(2:end)), diff(gaussianLocs_row), indexVector(1:(end - 1)), fileIndexVector(1:(end - 1))]];
                % -> Plots
                if(ismember(fileIndex, plotRowPeaks))
                    figure;
                    hold on;
                    findpeaks(rowCrossSectionAvg, rowRange, 'MinPeakDistance', expectedDistanceMinimum_Row, 'MaxPeakWidth', expectedWidthMaximum_Row, 'MinPeakProminence', expectedProminanceMinimum_Row);
                    ylabel('Y Position in mm');
                    xlabel('Intensity');
                    titleText = sprintf('Row Section for R%d-C%d.tiff',rowIndex, colIndex);
                    title(titleText);
                    hold off;
                end
                if(ismember(fileIndex, plotRowGaussFits))
                    figure;
                    hold on;
                    plot(rowRange, rowCrossSectionAvg);
                    for index = 1:length(locs_row)
                        range = linspace(gaussianFirstGuess_row(index, 2) - gaussianFirstGuess_row(index, 3) * 2, gaussianFirstGuess_row(index, 2) + gaussianFirstGuess_row(index, 3) * 2, 1000);
                        plot(range, gaussian(gaussianFirstGuess_row(index, :), range), 'Color', [0.4660, 0.6740, 0.1880]);
                        plot(range, gaussian(gaussianApproximations_row(index, :), range), 'Color', [0.8500, 0.3250, 0.0980]);
                    end
                    titleText = sprintf('Row Section for R%d-C%d.tiff',rowIndex, colIndex);
                    title(titleText);
                    ylabel('x position in mm');
                    xlabel('Y position in mm');
                    hold off;
                end
            else 
                errorText = sprintf('Unable to find file %s\n', fileString);
                fprintf(errorText);
            end
        end
    end
    
    if(ismember(fileIndex, plotLocalWidthVariance))
        % Plots spacing tolerance
        figure;
        hold on;
        colDifferences = ((ones(length(colDiffs), 3) * tileWUnitsColumns) ./ colDiffs(:,4));
        rowDifferences = ((ones(length(rowDiffs), 3) * tileWUnitsRows) ./ rowDiffs(:,4));
        range = (min([colDifferences; rowDifferences]):1:max([colDifferences; rowDifferences]))';
        % -> Columns
        %{
        pd_col = fitdist(colDifferences,'Kernel','Kernel','epanechnikov');
        y_col = pdf(pd_col, range);
        plot(range, y_col, 'LineWidth', 2, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        %}
        histogram(colDifferences, 20, 'displayName', 'Fitted Column Spacing (Wasatch Units / MM)');
        % -> Rows
        %{
        pd_row = fitdist(rowDifferences,'Kernel','Kernel','epanechnikov');
        y_row = pdf(pd_row, range);
        plot(range, y_row, 'LineWidth', 2, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        %}
        histogram(rowDifferences, 20, 'displayName', 'Fitted Row Spacing (Wasatch Units / MM)');
        % -> Plots
        legend('show');
        xlabel('Wasatch Units');
        ylabel('Quantity');
        title('Wasatch Units / MM From Line Division Data (Fitted)');
        hold off;
        
        figure;
        hold on;
        colDifferences = ((ones(length(colDiffs), 1) * tileWUnitsColumns) ./ colDiffs(:,2));
        rowDifferences = ((ones(length(rowDiffs), 1) * tileWUnitsRows) ./ rowDiffs(:,2));
        range = (min([colDifferences; rowDifferences]):1:max([colDifferences; rowDifferences]))';
        % -> Columns
        %{
        pd_col = fitdist(colDifferences,'Kernel','Kernel','epanechnikov');
        y_col = pdf(pd_col, range);
        plot(range, y_col, 'LineWidth', 2, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        %}
        histogram(colDifferences, 'displayName', 'Column Spacing (Wasatch Units / MM)');
        % -> Rows
        %{
        pd_row = fitdist(rowDifferences,'Kernel','Kernel','epanechnikov');
        y_row = pdf(pd_row, range);
        plot(range, y_row, 'LineWidth', 2, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        %}
        histogram(rowDifferences, 'displayName', 'Row Spacing (Wasatch Units / MM)');
        % -> Plots
        legend('show');
        xlabel('Wasatch Units');
        ylabel('Quantity');
        title('Wasatch Units / MM From Line Division Data (Raw)');
        hold off;
    end
    
    if(ismember(fileIndex, plotLocalSpatialDistribution))
        % Plots spatial distribution of spacing
        % -> Columns
        figure;
        hold on;
        for index = 1:numRowImages
            curLocations = nonzeros(colDiffs(:, 3).*(colDiffs(:, 5) == index));
            curSpaces = nonzeros(colDiffs(:, 4).*(colDiffs(:, 5) == index));
            labelText = sprintf('Row %d', index);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        title('Spacing In MM Over Column Range (Fitted)');
        legend('show');
        xlabel('Y Position (mm)');
        ylabel('Difference (mm)');
        hold off;
        % -> Rows
        figure;
        hold on;
        for index = 1:numColImages
            curLocations = nonzeros(rowDiffs(:, 3) .* (rowDiffs(:, 5) == index));
            curSpaces = nonzeros(rowDiffs(:, 4) .* (rowDiffs(:, 5) == index));
            labelText = sprintf('Column %d', index);
            plot(curLocations, curSpaces, 'displayName', labelText);
        end
        % -> Plot Properties
        title('Spacing In MM Over Row Range (Fitted)');
        legend('show');
        xlabel('X Position (mm)');
        ylabel('Difference (mm)');
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


plot();