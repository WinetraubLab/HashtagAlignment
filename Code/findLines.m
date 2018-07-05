%User interface. User marks the edges of each line and the algorithm estimates the location of the  
% middle of the line using cross correlation with a Gausian function.
%USAGE:
%   [ptsPixPosition, ptsId] = findLines (img,lnNames)
%INPUTS:
%   img - Histology fluorescence image with "bar code" on it 
%   InNames- A string that contains the name of the line (for example -x)
%  
%OUTPUTs
%   ptsPixPosition - Vector containing position of lines identified (in pixels)
%   ptsId -  Vector of line identifiers
%   
%Example:
%   Let us assume 4 lines in the image:
%       n1,n2 parallel to y axis positioned in x=-50microns, x=+50 microns
%       n3,n4 parallel to x axis positioned in y=-50microns, y=+50 microns
% - The user will be asked to mark the edges of the lines (will appear as red lines)
% - The algorithm will compute the estimate of the location of the line (will appear as a green line)
%Notice:
%       1) Circle each line in a bounding polygon

% Options:
% -> Selected method for identifying line centers from user provided
%    points. Options are:
%     1: Cross Correlation with Gaussian Fit
%     2: FMinSearch with Gaussian Fit

function [ptsPixPosition, ptsId] = findLines (img,lnNames)
    % Options
    MODE_CENTERING = 2;
    AVG_SLICES = 2; % How many slices to average below and above the current value
    FINDPEAK_EXPECTEDMINDIST = 30;
    FINDPEAK_EXPECTEDNUMPEAKS = 1;
    FINDPEAK_EXPECTEDMINDEPTH = 0.4;
    gaussian = @(a, x) a(1).*exp(-((x-a(2)).^2)./(2.*a(3).^2))+a(4);

    % Reading the image
    
    mainFigure = figure();
    imagesc(img);
    colormap gray;
    resp= 'Y';
    j = 1;

    x_estimate = []; % format is [xValue (pixels), lineNumber]
    y_estimate = []; % format is [yValue (pixels), lineNumber]
    % Processes all potential lines
    while 1
        if strcmpi(resp,'N')
            break;
        end
        % Finds bounding polygon around a line
        title(['Mark ' lnNames{round(j / 2)} 'Select the region containing one line']);
        binaryImage = roipoly;
        bottomIndex = find(sum(binaryImage, 2), 1, 'first');
        topIndex = find(sum(binaryImage, 2), 1, 'last');
        % Then finds the central line
        possibleLength = topIndex - bottomIndex;
        y_estimate_local = zeros(possibleLength, 1);
        x_estimate_local = zeros(possibleLength, 1);
        writeIndex = 1;
        for rowIndex = 1:possibleLength % Takes cross section along each row
            currentRow = bottomIndex + rowIndex;
            leftIndex = find(binaryImage(currentRow, :), 1, 'first');
            rightIndex = find(binaryImage(currentRow, :), 1, 'last');
            intensity = double(mean(img(currentRow - AVG_SLICES : currentRow + AVG_SLICES, leftIndex:rightIndex), 1)).*-1; % Row cross section inverted to use minpeak
            intensity = (intensity - min(intensity)) / (max(intensity) - min(intensity)); % Normalizes the section
            intensity = smooth(intensity, 5); % Smooths the section
            switch MODE_CENTERING
                case 1 % Correlation TODO
                    %{
                    var = maxGausVar(intensity, dis);
                    gauss = -1 * gausswin([6 * dis + 1],var);
                    gauss = (gauss - min(gauss)) / (max(gauss) - min(gauss));
                    [acor,lag] = xcorr(intensity, gauss);
                    [~,I] = max(abs(acor));
                    lagDiff = lag(I);
                    x_estimate(row) = x_av(row) - lagDiff + 1;
                    %}
                case 2 % Gaussian fit TODO actually do fit
                    range = leftIndex:rightIndex;
                    if(length(range) > 5)
                        minimumDistance = min([FINDPEAK_EXPECTEDMINDIST, (length(intensity) - 2)]);
                        [peaks, locs] = findpeaks(intensity, range, 'MinPeakDistance', minimumDistance, 'NPeaks', FINDPEAK_EXPECTEDNUMPEAKS, 'MinPeakProminence', FINDPEAK_EXPECTEDMINDEPTH);
                        if(~isempty(locs))
                            if(mod(writeIndex, 5) == 1)
                                %{
                                figure;
                                hold on;
                                findpeaks(intensity, leftIndex:rightIndex, 'MinPeakDistance', minimumDistance, 'NPeaks', FINDPEAK_EXPECTEDNUMPEAKS, 'MinPeakProminence', FINDPEAK_EXPECTEDMINDEPTH);
                                hold off;
                                %}
                            end
                            locs(1)
                            x_estimate_local(writeIndex) = locs(1);
                            y_estimate_local(writeIndex) = currentRow;
                            writeIndex = writeIndex + 1;
                        end
                    end
                otherwise
                    error('findLines: error, MODE_CENTERING is invalid.');
            end
        end
        figure(mainFigure);
        hold on;
        plot(x_estimate_local, y_estimate_local, 'o');
        hold off;
        x_estimate = [x_estimate; [x_estimate_local, ones(length(x_estimate_local), 1) * j]];
        y_estimate = [y_estimate; [y_estimate_local, ones(length(y_estimate_local), 1) * j]];
        %{
        hold on;
        plot(x_estimate_local, y_estimate_local, 'Color', [0.4660, 0.6740, 0.1880]);
        p = polyfit(x_estimate_local, y_estimate_local, 1)
        plot(x_estimate_local, p(1) * x_estimate_local + p(2), 'Color', [0.8500, 0.3250, 0.0980]);
        hold off;
        %}
    end
    % REVIEW AFTER ME
    ptsPixPosition_x(:,j/2) = [x_estimate];
    ptsPixPosition_y(:,j/2) = [p(1)*x_estimate+p(2)];
    ptsId(:,j/2) = repmat([j/2],[11,1]);
    j = j + 1;
    resp = inputdlg('Do you wish to continue to mark lines? Y/N: ','s');
    clear x1; clear y1; clear x2; clear y2; clear Nx1; clear Ny1; clear Nx2; clear Ny2; 
    clear x_av; clear y_av; clear dis; clear intensity; clear gauss; clear acor; clear lag;
    clear I; clear lagDiff; clear x_estimate; clear p; 
    ptsPixPosition=[ptsPixPosition_x(:) ptsPixPosition_y(:)];
    ptsId=ptsId(:);
end

% Found at https://stackoverflow.com/questions/12987905/how-to-make-a-curve-smoothing-in-matlab
% because I do not have the curve fitting toolbox.
function yy = smooth(y, span)
    yy = y;
    l = length(y);

    for i = 1 : l
        if i < span
            d = i;
        else
            d = span;
        end

        w = d - 1;
        p2 = floor(w / 2);

        if i > (l - p2)
           p2 = l - i; 
        end

        p1 = w - p2;

        yy(i) = sum(y(i - p1 : i + p2)) / d;
    end
end
