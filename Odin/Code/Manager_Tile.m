%
% File: Manager_Tile.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This class manages and compiles a tiled image.
%

classdef Manager_Tile   
    % ---------------------------------- Properties -----------------------
    properties(GetAccess = 'private', SetAccess = 'private')
      images = struct('imageArray',{},'bounds',{}, 'tMatrix', {}, 'surfPoints', {}, 'surfBoard', {}); % Array of cachedImage structs.
      cachedImage = struct('imageArray',{},'bounds',{}, 'tMatrix', {}, 'surfPoints', {}, 'surfBoard', {}); % Struct of the form [imageArray, bounds ([xMin, xMax, yMin, yMax] after rotation), tMatrix (image transformation matrix), surfPoints (Locations of surf features after transformation), surfBoard (SURF feature list after transformation)]
      cachedImageBounds = [0, 0, 0, 0]; % Format is [xMin, xMax, yMin, yMax], composite image size with the new cached image added
      compositeImage = []; % Display updated and re-displayed when a new image is added.
      compositeImageBounds = [0, 0, 0, 0]; % Format is [xMin, xMax, yMin, yMax], kept up to date as new images are added
    end
    
    
    % ------------------------------ Functions ----------------------------
    methods(Access = 'public')
        % Class constructor
        function obj = Manager_Tile()
            obj;
        end 
        
        %
        % Description:
        %   Caches the given image so that it can be previewed before 
        %   being added to the composite image.
        %
        % Parameters:
        %   'newImage' The new image to be processed and cached
        %
        function cacheImage(obj, newImage)
            [imBounds, imTMatrix, imSURFPoints, imSURFFeatures, newTiledBounds] = findBestFit(obj, newImage);
            obj.cachedImage.imageArray = newImage;
            obj.cachedImage.bounds = imBounds;
            obj.cachedImage.tMatrix = imTMatrix;
            obj.cachedImage.surfBoard = imSURFFeatures;
            obj.cachedImage.surfPoints = imSURFPoints;
            obj.cachedImageBounds = newTiledBounds;
        end
        
        %
        % Description:
        %   Preview of where the cached image will be added to the
        %   tiled panorama.
        %
        % Parameters:
        %   'drawColor' (float in form [r, g, b] (range 0-1)) A tint for
        %               the overlayed image.
        %
        function preview = previewImage(obj, newImage, drawColor)
            updateCompositeImage(newTiledBounds);
            preview = cat(3, obj.compositeImage, obj.compositeImage, obj.compositeImage); % We want to see the new image highlighted
            % Overlays a shaded preview image
            newImage = cat(3, obj.cachedImage.imageArray.*(drawColor(1)), obj.cachedImage.imageArray.*(drawColor(2)), obj.cachedImage.imageArray.*(drawColor(3)));
            warpedImage = imwarp(newImage, imTMatrix, 'OutputView', compositeView); 
            mask = imwarp(true(size(image(index),1),size(image(index),2), 3), imTMatrix, 'OutputView', panoramaView);
            preview = step(blender, preview, warpedImage, mask);
        end
        
        %
        % Description:
        %   Moves the cached image into the 
        %
        function postImage(obj)
            
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
            obj.updateComposite(obj.compositeImageBounds);
            time = clock;
            folderName = sprintf('Acquisitions\Tiled');
            if(isempty(varargin) > 0)
                subFolderName = varargin(1);
            else
                subFolderName = sprintf('Composite_Manual_%d\%d\%d_%d:$d:%d', time(2), time(3), time(1) , time(4), time(5), time(6));
            end
            tiledName  = sprintf('Tiled.png');
            fullPath = sprintf('%s/%s/%s', folderName, subFolderName, tiledName);
            imwrite(obj.compositeImage, fullPath);
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
        %   newImage (image handle) The image to consider for the composite
        %   
        % Returns:
        %   imBounds       ([[xMin, xMax], [yMin, yMax]]) Global coords of the bounding box after transformed
        %   imTMatrix      ([3, 3])                       Similarity transformation matrix   
        %   imSURFPoints   ([rows, cols])     Coordinates of surf features relative to tiled image
        %   imSURFFeatures ([coords, features])    Surf features relative to the tiled image
        %   newTiledBounds ([[xMin, xMax], [yMin, yMax]]) Required size of composite to fit newImage
        %
        function [imBounds, imTMatrix, imSURFPoints, imSURFFeatures, newTiledBounds] = findBestFit(obj, newImage)
            % Identifies SURF features
            newPoints = detectSURFFeatures(newImage);
            [newFeatures, newPoints] = extractFeatures(newImage, newPoints);
            % Finds the best matching image
            numImages = size(obj.images, 1);
            results = zeros(numImages, 1);
            for index = 1:numImages
                results(index) = length(nonzeros(matchFeatures(currentFeatures, obj.images(index).surfboard, 'Unique', true)));
            end
            [~, bestImageIndex] = max(results);
            
            % Finds image warp
            featurePairs = matchFeatures(newFeatures, obj.currentImages(bestImageIndex, 5), 'Unique', true);
            imTMatrix = estimateGeometricTransform(matchedPoints, matchedPointsPrev, 'similar', 'Confidence', 99.9, 'MaxNumTrials', 2000);
            
            % Finds output parameters
            % -> Creates mask to find boundaries of the image % TODO may be incorrect
            mask = imwarp(true(size(newImage,1),size(newImage,2)), imTMatrix);
            [rows, cols] = find(mask);
            imBounds = [[min(cols), max(cols)], [min(rows), max(rows)]];
            % -> Transforms image to find new surf landmarks
            transformedImage = imwarp(newImage, imTMatrix);
            imSURFPoints = detectSURFFeatures(transformedImage);
            [imSURFFeatures, imSURFPoints] = extractFeatures(newImage, imSURFPoints);
            % -> Calculates new tiled bounds
            newTiledBounds = [[min(obj.compositeImageBounds(1), imBounds(1)), max(obj.compositeImageBounds(2), imBounds(2))], [min(obj.compositeImageBounds(3), imBounds(3)), max(obj.compositeImageBounds(4), imBounds(4))]];
        end
        
        %
        % Description:
        %   Draws the composite image with the given bounds. All images 
        %   currently in the images list are assumed to have translations 
        %   etc. relative to the old pre-shifted coordinate system. This 
        %   function does not add the shift to the old images permanently.
        %
        % Parameters:
        %   newBounds  ([[xMin, xMax], [yMin, yMax]]) The new boundaries of
        %   the image to display with
        %
        function newImage = getCompositeImage(obj, newBounds)
            newImage = zeros(newBounds(2) - newBounds(1), newBounds(4) - newBounds(3));
            compositeView = imref2d(([newBounds(2) - newBounds(1), newBounds(4) - newBounds(3)], [newBounds(1), newBounds(2)], [newBounds(3), newBounds(4)]);
            blender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');
            for index = 1:size(obj.images, 1)
                % Applies transform
                warpedImage = imwarp(image(index).imageArray, obj.images(index).tMatrix, 'OutputView', compositeView); 
                % Generate a binary mask.
                mask = imwarp(true(size(image(index),1),size(image(index),2)), obj.images(index).tMatrix, 'OutputView', panoramaView);
                % Overlays both, only acts in non-masked region by virtue
                % of step function (see docs)
                newImage = step(blender, newImage, warpedImage, mask);
            end
        end
    end 
end

