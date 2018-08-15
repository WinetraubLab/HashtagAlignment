%
% File: Manager_Tile.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This class manages and compiles a tiled image.
%

classdef Manager_Tile < handle 
    % ---------------------------------- Properties -----------------------
    properties(GetAccess = 'public')
        images = struct('imageID', {}, 'imageArray',{}, 'tMatrix', {}, 'imageCornerPoints', {}, 'surfPoints', {}, 'surfBoard', {}, 'highlightColor', {}); % Array of cachedImage structs.
        % 'imageID' is a unique number corresponding to the image. These
        % are generated sequentially.
        % 'imageArray' is an nxm array of greyscale data, 'tMatrix' is 
        % the transformation matrix to align 
        % the matrix to the global coordinates. 'imageCornerPoints' is a 
        % matrix of the form [[xVal1, yVal1]; [xVal2, yVal2]; [xVal3, yVal3]; [xVal4, yVal4]] 
        % that stores the coordinates for the corners of the image once
        % translated. 'surfPoints' stores global coordinates corresponding
        % to feature descriptors in 'surfBoard'. 'highLightColor' sets the
        % shading of the image when rendered, white by default.
        %
        % Composite images are rendered from the first image forward.
        %
        compositeBounds = []; % Form is [[xMin, yMin];[xMax, yMax]]
        currentMaxID = 0;
    end
    
    
    % ------------------------------ Functions ----------------------------
    methods(Access = 'public')
        % Class constructor
        function obj = Manager_Tile()
            obj;
        end 
        
        %
        % Description:
        %   Adds the given image to the tiled image.
        %
        % Parameters:
        %   'newImage' The new image to be processed and cached
        %
        % Returns:
        %   'newImageID' The ID of the recently added image.
        %
        function newImageID = addImage(obj, newImage)
            newImageStruct = findBestFit(obj, newImage);
            latestIndex = numel(obj.images) + 1;
            obj.images(latestIndex) = newImageStruct;
            obj.updateImageBounds;
            newImageID = newImageStruct.imageID;
        end
        
        %
        % Description:
        %   Removes the image specified by imageID
        %
        % Paramters:
        %   'imageID' The ID number of the image to remove.
        %
        function removeImage(obj, imageID)
            targetIndex = obj.getImageIndexFromID(imageID);
            obj.images = [obj.images(1:targetIndex - 1), obj.images(targetIndex + 1:end)];
        end
        
        %
        % Description:
        %   Returns the ID of the topmost image at the mouse position.
        %   
        % Parameters:
        %   'mouseCoordinates' Array of the form [xVal, yVal] assumed to
        %                       correspond to coordinates from within the
        %                       image from the upper left hand corner.
        %
        % Returns:
        %   The image ID if there is an image, zero if there are no images
        %   at that location.
        %
        function imageID = getImageIDAtLocation(obj, mouseCoordinates)
            mouseCoordinates = [mouseCoordinates(1) - obj.compositeBounds(1, 1), mouseCoordinates(2) - obj.compositeBounds(1, 2)];
            imageID = 0;
            for index = 1:length(obj.images)
                if(inpolygon(mouseCoordinates(1), mouseCoordinates(2), obj.images(index).imageCornerPoints(:, 1), obj.images(index).imageCornerPoints(:, 2)))
                    imageID = obj.images(index).imageID;
                    break;
                end
            end
        end
        
        %
        % Description:
        %   Sets the color of the image specified by imageID.
        %
        % Parameters:
        %   'imageID'     The image to modify
        %   'colorMatrix' Specifies RGB in the form [R (0-1), G (0 - 1), B (0 - 1)].
        %
        function setImageHighlightColor(obj, imageID, colorMatrix)
            imageIndex = getImageIndexFromID(imageID);
            if(imageIndex ~= 0)
                obj.images(imageIndex).highlightColor = colorMatrix;
            end
        end
             
        %
        % Description:
        %   Retrieves an RGB composite image generated from the images
        %   currently cached.
        %
        % Returns:
        %   'newImage' A composite image made from all of the images
        %              currently collected.
        %
        function newImage = getCompositeImage(obj)
            obj.updateImageBounds();
            newImage = zeros((obj.compositeBounds(2, 2) - obj.compositeBounds(1, 2)), (obj.compositeBounds(2, 1) - obj.compositeBounds(1, 1)), 3);
            compositeView = imref2d(size(newImage), [obj.compositeBounds(1, 1), obj.compositeBounds(2, 1)], [obj.compositeBounds(1, 2), obj.compositeBounds(2, 2)]);
            blender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');
            for index = 1:numel(obj.images)
                % Applies coloration
                %currentImage = cat(obj.images(index).imageArray(:, :, 1).*obj.images(index).highlightColor(1), obj.images(index).imageArray(:, :, 2).*obj.images(index).highlightColor(2), obj.images(index).imageArray(:, :, 3).*obj.images(index).highlightColor(3));
                currentImage = obj.images(index).imageArray;
                % Applies transform
                warpedImage = imwarp(currentImage, obj.images(index).tMatrix, 'OutputView', compositeView); 
                warpedImage = cat(3, warpedImage, warpedImage, warpedImage);
                % Generate a binary mask.
                mask = imwarp(true(size(currentImage, 1), size(currentImage, 2)), obj.images(index).tMatrix, 'OutputView', compositeView);
                % Overlays both, only acts in non-masked region by virtue
                % of step function (see docs)
                newImage = step(blender, newImage, warpedImage, mask);
            end
        end
        
        % 
        % Description:
        %   Saves the tiled image to disk.
        %
        % Parameters:
        %   'varargin' Optional parameter, the name of the folder to save
        %              under. Otherwise uses current date and time.
        %
        function saveTiledImage(obj, varargin)
            newCompositeImage = obj.getCompositeImage();
            time = clock;
            folderName = sprintf('Acquisitions\Tiled');
            if(isempty(varargin) > 0)
                subFolderName = varargin(1);
            else
                subFolderName = sprintf('Composite_Manual_%d\%d\%d_%d:%d:%d', time(2), time(3), time(1) , time(4), time(5), time(6));
            end
            tiledName  = sprintf('Tiled.png');
            fullPath = sprintf('%s/%s/%s', folderName, subFolderName, tiledName);
            imwrite(newCompositeImage, fullPath);
            for index = 1:size(obj.images, 2)
                imageName = sprintf('Snapshot_%d',index);
                fullPath = sprintf('%s/%s/%s', folderName, subFolderName, imageName);
                imwrite(obj.images(index).imageArray, fullPath);
            end
        end
    end
    
    methods(Access = 'private')
        %
        % Description:
        %   Tries to find the best location for the image relative
        %   to the existing window. Returns NAN if no location was
        %   found with a satisfactory match level.
        %
        % Parameters:
        %   'newImage' (image handle) The image to consider for the composite
        %   
        % Returns:
        %   'newTiledBounds' New struct containing image datas
        %
        function newImageStruct = findBestFit(obj, newImage)
            newImage = mean(newImage, 3); % Surf operates on black-white image.
            newImageStruct = struct('imageID', 0, 'imageArray', 0, 'tMatrix', eye(3), 'imageCornerPoints', 0, 'surfPoints', 0, 'surfBoard', 0, 'highlightColor', [0, 0, 0]);
            % Identifies SURF features
            points = detectSURFFeatures(newImage);
            [currentFeatures, points] = extractFeatures(newImage, points);
            imTMatrix = affine2d;
            if(~isempty(obj.images))
                % Finds the best matching image
                numImages = numel(obj.images);
                results = zeros(numImages, 1);
                for index = 1:numImages
                    results(index, 1) = size(nonzeros(matchFeatures(currentFeatures, obj.images(index).surfBoard, 'Unique', true)), 1);
                end
                [~, bestImageIndex] = max(results);
                indexPairs = matchFeatures(currentFeatures, obj.images(bestImageIndex).surfBoard, 'Unique', true);

                % Finds image warp
                matchedPoints = points(indexPairs(:,1), :);
                matchedPointsPrev = obj.images(bestImageIndex).surfPoints(indexPairs(:,2), :);
                imTMatrix = estimateGeometricTransform(matchedPoints, matchedPointsPrev, 'similar', 'Confidence', 99.9, 'MaxNumTrials', 2000);
                
                % Debugging
                %{
                figure; 
                hold on;
                ax = axes;
                showMatchedFeatures(newImage,imwarp(obj.images(bestImageIndex).imageArray, obj.images(bestImageIndex).tMatrix),matchedPoints,matchedPointsPrev,'montage', 'Parent',ax);
                hold off;
                %}
            end
            
            % Finds output parameters
            % -> Stores ID
            newImageID = obj.currentMaxID;
            obj.currentMaxID = obj.currentMaxID + 1;
            newImageStruct.imageID = newImageID;
            % -> Stores image array, transformation matrix, corners, and color
            newImageStruct.imageArray = newImage;
            [X, Y] = transformPointsForward(imTMatrix, [0, 0, size(newImage, 1), size(newImage, 1)], [0, size(newImage, 2), 0 size(newImage, 2)]);
            newImageStruct.imageCornerPoints = [X', Y'];
            newImageStruct.highlightColor = [255, 255, 255];
            % -> Transforms image to find new surf landmarks
            transformedImage = imwarp(newImage, imTMatrix); % TODO may be incorrect
            [imSURFFeatures, imSURFPoints] = extractFeatures(transformedImage, detectSURFFeatures(transformedImage));
            newImageStruct.surfBoard = imSURFFeatures;
            newImageStruct.surfPoints = imSURFPoints;
            newImageStruct.tMatrix = imTMatrix;
        end
        
        %
        % Description:
        %   Returns the index of the image associated with the given 
        %   image ID. Returns 0 if no such image exists.
        %
        % Parameters:
        %   'imageID' The ID number of the target image.
        %
        % Returns:
        %   'imageNumber' The index corresponding to the image in question.
        %
        function imageNumber = getImageIndexFromID(obj, imageID)
            imageNumber = 0;
            for index = 1:length(obj.images)
                if(obj.images(index).imageID == imageID)
                    imageNumber = index;
                    break;
                end
            end
        end
        
        %
        % Description:
        %   Updates the composite boundaries of the tiled image.
        %
        function updateImageBounds(obj)
            newBounds = [[0, 0]; [0, 0]];
            for index = 1:length(obj.images)
                % xMin
                newBounds(1, 1) = ceil(min(newBounds(1, 1), min(obj.images(index).imageCornerPoints(:, 1))));
                % xMax
                newBounds(2, 1) = ceil(max(newBounds(2, 1), max(obj.images(index).imageCornerPoints(:, 1))));
                % yMin
                newBounds(1, 2) = ceil(min(newBounds(1, 2), min(obj.images(index).imageCornerPoints(:, 2))));
                % yMax
                newBounds(2, 2) = ceil(max(newBounds(2, 2), max(obj.images(index).imageCornerPoints(:, 2))));
            end
            obj.compositeBounds = newBounds;
        end
    end 
end

