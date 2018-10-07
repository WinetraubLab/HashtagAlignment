%
% File: Manager_Camera_uEye.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This class acts as an interface for one Thorcam camera. This class
%   uses the framework associated with the uEye SDK.
%

classdef Manager_Camera_uEye
    % This class manages camera settings and the camera connection.
    
    properties(Access = 'private')
        camera = [];
        cameraMemoryId = [];
        cameraWidth = [];
        cameraHeight = [];
        cameraBits = [];
        cameraScaleRange = NaN;
        previousImage = [];
    end
    
    methods(Access = 'public')
        %
        % Description:
        %   Camera object constructor.
        %
        % Parameters:
        %   'cameraID' The ID of the camera.
        %
        function obj = Manager_Camera_uEye(cameraID)
            % Attempts to open a camera
            NET.addAssembly('C:\Program Files\IDS\uEye\Develop\DotNet\signed\uEyeDotNet.dll');
            obj.camera = uEye.Camera;
            obj.camera.Init(cameraID);
            obj.camera.Display.Mode.Set(uEye.Defines.DisplayMode.DiB); % Bitmap mode
            obj.camera.PixelFormat.Set(uEye.Defines.ColorMode.RGBA8Packed); % 8 bit color
            obj.camera.Trigger.Set(uEye.Defines.TriggerMode.Software); % Software trigger
            [~, memoryID] = obj.camera.Memory.Allocate(true);
            obj.cameraMemoryId = memoryID;
            [~, Width, Height, Bits, ~] = obj.camera.Memory.Inquire(obj.cameraMemoryId);
            obj.cameraWidth = Width;
            obj.cameraHeight = Height;
            obj.cameraBits = Bits;
        end
        
        %
        % Description:
        %   Camera object deconstructor.
        %
        function delete(obj)
            obj.camera.Exit;
        end
        
        %
        % Description:
        %   Returns the master gain setting of the camera.
        %
        % Returns:
        %   Returns the currently set gain of the camera.
        %
        function totalGain = getMasterGain(obj)
            totalGain = obj.camera.GainFactor.GetMaster();
        end
        
        %
        % Description:
        %   Sets the master gain setting of the camera. If auto gain
        %   is enabled then it is overwritten and must be re-enabled.
        %
        % Parameters:
        %   'gainValue' The gain to set for the camera. If set to nan then
        %               automatically scales.
        %
        function setMasterGain(obj, gainValue)
            if(isnan(gainValue))
                obj.camera.AutoFeatures.Sensor.Gain.SetEnable(true)
            else
                obj.camera.GainFactor.SetMaster(gainValue);
            end
        end

        
        
        %
        % Description:
        %   Returns the highest and lowest values of the previous image.
        % 
        % Returns:
        %   Array of the form [minValue, maxValue].
        %
        function bounds = getScaleRange(obj)
            bounds = zeros(1, 2);
            bounds(1, 1) = min(min(obj.previousImage));
            bounds(1, 2) = max(max(obj.previousImage));
        end
        
        %
        % Description:
        %   Sets the scale range for images to be normalized to.
        %
        % Parameters:
        %   'bounds' Array of the form [min, max] to scale images by. If
        %            set to nan then automatically scales.
        %
        function setScaleRange(obj, bounds)
            if(isnan(bounds))
                obj.cameraScaleRange = NaN;
            else
                obj.cameraScaleRange = bounds;
            end
        end
        
        % 
        % Description:
        %   Captures several images and returns the average.
        %
        % Parameters:
        %   'numFrameAverages' The number of images to combine into one.
        %
        % Returns:
        %   'newImage' The composite image.
        %
        function newImage = acquireImage(obj, numFrameAverages)
            acquisitions = zeros(obj.cameraHeight, obj.cameraWidth, numFrameAverages);
            for index = 1:numFrameAverages
                obj.camera.Acquisition.Freeze(uEye.Defines.DeviceParameter.Wait);
                [~, tmp] = obj.camera.Memory.CopyToArray(obj.cameraMemoryId);
                Data = reshape(uint8(tmp), [obj.cameraBits/8, obj.cameraWidth, obj.cameraHeight]);
                Data = Data(1:3, 1:obj.cameraWidth, 1:obj.cameraHeight);
                Data = permute(Data, [3, 2, 1]);
                acquisitions(:, :, index) = rgb2gray(Data);
            end
            newImage = mean(acquisitions, 3)./255;
            if(isnan(obj.cameraScaleRange))
                newImage = mat2gray(newImage);
            else
                newImage = mat2gray(newImage, [obj.cameraScaleRange(1, 1), obj.cameraScaleRange(1, 2)]);
            end
            obj.previousImage = newImage;
        end
        
        %
        % Decription:
        %   Saves the most recently captured image to the disk.
        %
        % Parameters:
        %   'name' If used, the file is named this. Set to [] to use the 
        %          current date and time.
        %
        function saveImage(obj, name)
            time = clock;
            folderName = sprintf('Acquisitions\Snapshots');
            imageName = [];
            if(isempty(name))
                imageName = sprintf('Image_Manual_%d\%d\%d_%d:$d:%d', time(2), time(3), time(1) , time(4), time(5), time(6));
            else 
                imageName = sprintf('%s', name);
            end
            imageName = sprintf('%s.png', imageName);
            fullPath = sprintf('%s/%s', folderName, imageName);
            imwrite(obj.previousImage, fullPath);
        end
        
        %
        % Descripion:
        %   Simple getter for height (number of rows) of camera images.
        %
        % Returns:
        %   Returns the height of images from the camera.
        %
        function height = getHeight(obj)
            height = obj.cameraHeight;
        end
        
        %
        % Description:
        %   Simple getter for the width of an image.
        %
        % Returns:
        %   Number of columns in acquired images.
        %
        function width = getWidth(obj)
            width = obj.cameraWidth;
        end
    end
    
    methods(Access = 'private')
    end
    
end

