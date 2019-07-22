% Erick Blankenberg
% DeLaZerda Research
% Wasatch Writer
% Calibration Data

clear all;
close all;

% Looks at data obtained from a volumetric scan and creates an estimate
% of the spacing between frames as a function of frame number.

% Gel is assumed to be full of spheres that we track.

%% Loads Images

scanNumber = 1;
framesToLoad = 1:10;

frames = struct('FrameNumber', [], 'ImageArray', []);
for frameIndex = 1:numel(framesToLoad)
    currentFrameStruct = struct('FrameNumber', framesToLoad(frameIndex), 'ImageArray', []);
    path = sprintf('Scan%d/Reslice of scanAbs%8d.tif', scanNumber, currentFrameStruct.frameNumber);
    currentFrameStruct.ImageArray = rgb2grey(imload(path));
    frames(frameIndex) = currentFrameStruct;
end

%% Analyzes Data

approximationOrder = 4; % Order of polynomial approximation for velocity

positionColor = [0, 0.4470, 0.7410]; % Graphing color for position
velocityColor = [0.4940, 0.1840, 0.5560]; % Graphing color for velocity
accelerationColor = [0.6350, 0.0780, 0.1840]; % Graphing color for acceleration

sphereRadius = 6.58; % [micrometers] Radius of spheres in gel
pixelHeight = 0.968; % [micrometers] Height of a single pixel
pixelWidth  = 2;     % [micrometers] Width of a single pixel
maxBlobSize = ((pi * sphereRadius^2) / (pixelHeight * pixelWidth)) * 1.5; % [pixels] maximum surface area to consider a blob a sphere
sphereOffset = @(A) ((sphereRadius.^2 - A / pi).^0.5); % Returns offset from center of sphere in micrometers 
maxContinuityDistance = 5; % [pixels] maximum distance between centroid of subsequent blobs to be considered the same

startFrame = 1;
endFrame = 10;

% Finds and tracks all spheres between images
liveObjects = struct('Location', [], 'LifeTime', 1, 'Start', currentFrameIndex, 'LastFrame', [], 'SpherePositions', []);
dilationObject = strel('diamond', 5);
for currentIndex = numel(frames)
    currentImageStruct = frames(currentIndex);
    currentFrameIndex = currentImageStruct.FrameNumber;
    % -> Binarizes and dilates - erodes image to isolate spheres
    newImageFrame = currentImageStruct.ImageArray;
    newImageFrame = imtophat(newImageFrame);
    newImageFrame = imadjust(newImageFrame);
    newImageFrame = imbinarize(newImageFrame);
    newImageFrame = bwareaopen(newImageFrame, 50);
    newImageFrame = imdilate(newImageFrame, dilationObject);
    connectedImage =  bwconncomp(newImageFrame, 8);
    % -> Iterates over all blobs to identify potential beads
    for currentBlobIndex  = 1:5 % TODO get real bounds
        currentBlobSize = 0; % TODO
        if(currentBlobSize < maxBlobSize)
            % -> Tries to find match for object continuity if possible
            bestMatchIndex = 0;
            bestMatchDistance = maxContinuityDistance;
            for currentCheckIndex = 1:numel(liveObjects)
                currentDistance = dist(); % TODO
                if (currentDistance < bestMatchDistance)
                    bestMatchIndex = currentCheckIndex;
                    bestMatchDistance = currentDistance;
                end
            end
            % -> If there is a cross section with a decent match, links to previous 
            if(bestMatchIndex && liveObjects(bestMatchIndex).LifeTime ~= currentFrameIndex) % Links are exlusive
                liveObjects(bestMatchIndex).LifeTime = liveObjects(bestMatchIndex).LifeTime + 1;
                oldOffset = liveObjects(bestMatchIndex).SpherePositions(end);
                newOffset = sphereOffset(); % TODO
                if(newOffset > oldOffset)
                    newOffset = newOffset * -1;
                end
                liveObjects(bestMatchIndex).SpherePositions = [liveObjects(bestMatchIndex).SpherePositions, newOffset];
                liveObjects(bestMatchIndex).LastFrame = currentFrameIndex;
            else
                newObjectStruct = struct('Location', [], 'LifeTime', 1, 'Start', currentFrameIndex, 'LastFrame', [], 'SpherePositions', []);
                liveObjects(numel(liveObjects + 1)) = newObjectStruct;
            end
        end
    end
    
end

% Assigns velocity data
% -> Finds values
numPoints = 0;
for objectIndex = 1:numel(liveObjects)
    numPoints = numPoints + liveObjects(frameIndex).LifeTime;
end
velocityValues = zeros(1, (numPoints - numel(liveObjects))); % n-1 slope points per sphere
velocityFrameValues = zeros(size(velocityValues));
counter = 1;
for objectIndex = 1:numel(liveObjects)
    currentObject = liveObjects(objectIndex);
    for objectFrameIndex = 1:(currentObject.LifeTime - 1)
        velocityValues(counter) = currentObject.SpherePositions(objectFrameIndex) - currentObject.SpherePositions(objectFrameIndex + 1);
        velocityFrameValues(counter) = currentObject.Start + objectFrameIndex + 0.5;
    end
end

% -> Creates position, velocity, and acceleration profiles
velocityPolyVals = polyfit(velocityFrameValues, velocityValues, approximationOrder);
accelerationPolyVals = polyder(velocityPolyVals);
positionPolyVals = polyint(velocityPolyVals);

%% Plots Values

close all;

figure;
hold on;
title(sprintf('Velocity Versus Frame Number w/ Approximation Order %d', approximationOrder));
scatter(velocityFrameValues, velocityValues, 'DisplayName', 'Velocity Data', 'Color', velocityColor);
xrange = xlim;
xrange = linspace(xrange(1), xrange(2), 1000);
plot('DisplayName', 'Position', 'Color', positionColor);
plot('DisplayName', 'Velocity', 'Color', velocityColor);
plot('DisplayName', 'Acceleration', 'Color', accelerationColor);
xlabel('Frame Number');
ylabel('\muM/s^{2}, \muM/s, \muM');
legend('show');
hold off;

