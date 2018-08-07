% Erick Blankenberg
% DeLaZerda Research
% Fluoroscope
% Pixel Size Calibration

% Quick script to determine the size of a pixel from the thorcam
% we are using on the optical microscope.

clear all;
close all;

% Options

plotPeaks = false;
lineSizes = [3.91, 3.48, 3.1, 2.76, 2.46, 2.19];

amplitudeFromPeakProminance = 1.5;
varianceFromPeakWidth = 1;
rangeWidthFromPeakWidth = 2.5;

% The Program

image = rgb2gray(imread('Calibration.png'));
figure(1);
hold on;
imshow(image);
hold off;
gaussian = @(a, x) a(1).*exp(-((x-a(2)).^2)./(2.*a(3).^2))+a(4); % Format is a = [linFit slope, linFit offset, magnitude, center, variance, baseline]
totalResults = []; % Format is [um/pixel, (0 if horizontal or 1 if vertical), groupNumber]

for index = length(lineSizes):-1:1
    % Asks user to select current group
    figure(1);
    hold on;
    title(sprintf('Crop The Region Around Vertical Lines in Group 7 - %d', index));
    verticalLines = imcrop();
    verticalAverage = mean(verticalLines, 1);
    title(sprintf('Crop The Region Around Horizontal Lines in Group 7 - %d', index));
    horizontalLines = imcrop();
    horizontalAverage = mean(horizontalLines, 2)';
    hold off;
    
    % Identifies lines
    
    % -> Vertical Lines
    [verticalPks, verticalLocs, verticalWidth, verticalHeight] = findpeaks(verticalAverage, 'NPeaks', 3, 'MinPeakProminence', 100);
    localVerticalResults = []; % Format is [location]
    if(plotPeaks)
        figure(2 * index)
        hold on;
        findpeaks(verticalAverage, 'NPeaks', 3, 'MinPeakProminence', 100);
        hold off;
    end
    for verticalCalculationIndex = 1:length(verticalPks)
        % --> Range
        range = (verticalLocs(verticalCalculationIndex) - ceil(verticalWidth(verticalCalculationIndex) / 2)):(verticalLocs(verticalCalculationIndex) + ceil(verticalWidth(verticalCalculationIndex) / 2));
        % --> Magnitude
        magnitude = verticalHeight(verticalCalculationIndex) * amplitudeFromPeakProminance;
        % --> Variance
        variance = verticalWidth(verticalCalculationIndex) * varianceFromPeakWidth;
        % -> Calculates
        initialGuess = [magnitude, verticalLocs(verticalCalculationIndex), variance, verticalPks(verticalCalculationIndex) - magnitude];
        result = fminsearch(@(a) sum((verticalAverage(range) - gaussian(a, range)).^2), initialGuess);
        localVerticalResults = [localVerticalResults; result(1)];
        % -> Plots
        if(plotPeaks)
            figure(2 * index);
            hold on;
            plot(range, gaussian(result, range), 'displayName', sprintf('Column %d', verticalCalculationIndex));
            title(sprintf('Peak Detection for Vertical Lines in Group 7 - %d', index));
            legend('show');
            hold off;
        end
    end
    totalResults = [totalResults; [(ones(length(localVerticalResults) - 1, 1) .* lineSizes(index)) ./ diff(localVerticalResults), ones(length(localVerticalResults) - 1, 1) .* 1, ones(length(localVerticalResults) - 1, 1) .* index]];
    
    % -> Horizontal Lines
    [horizontalPks, horizontalLocs, horizontalWidth, horizontalHeight] = findpeaks(horizontalAverage, 'NPeaks', 3, 'MinPeakProminence', 100);
    localHorizontalResults = []; % Format is [location]
    if(plotPeaks)
        figure(2 * index + 1);
        findpeaks(horizontalAverage, 'NPeaks', 3, 'MinPeakProminence', 100);
        hold on;
        
    end
    for horizontalCalculationIndex = 1:length(horizontalPks)
        % --> Range
        range = (horizontalLocs(horizontalCalculationIndex) - ceil(horizontalWidth(horizontalCalculationIndex) / 2)):(horizontalLocs(horizontalCalculationIndex) + ceil(horizontalWidth(horizontalCalculationIndex) / 2));
        % --> Magnitude
        magnitude = horizontalHeight(horizontalCalculationIndex) * amplitudeFromPeakProminance;
        % --> Variance
        variance = horizontalWidth(horizontalCalculationIndex) * varianceFromPeakWidth;
        % -> Calculates
        initialGuess = [magnitude, horizontalLocs(horizontalCalculationIndex), variance, horizontalPks(horizontalCalculationIndex) - magnitude];
        result = fminsearch(@(a) sum((horizontalAverage(range) - gaussian(a, range)).^2), initialGuess);
        localHorizontalResults = [localHorizontalResults; result(1)];
        % -> Plots
        if(plotPeaks)
            figure(2 * index + 1);
            hold on;
            plot(range, gaussian(result, range), 'displayName', sprintf('Column %d', horizontalCalculationIndex));
            title(sprintf('Peak Detection for Horizontal Lines in Group 7 - %d', index));
            legend('show');
            hold off;
        end
    end
    totalResults = [totalResults; [(ones(length(localHorizontalResults) - 1, 1) .* lineSizes(index)) ./ diff(localHorizontalResults), ones(length(localHorizontalResults) - 1, 1) .* 0, ones(length(localHorizontalResults) - 1, 1) .* index]];
end