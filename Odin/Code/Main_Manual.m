%
% File: Main_Manual.m
% -------------------
% Author: Erick Blankenberg
% Date 8/1/2018
% 
% Description:
%   This program acts as an interface for the new flouroscopy microscope.
%   This version requires the user to use the manual stage while acquiring
%   a composite image.
%

% ---------------------------------- Settings -----------------------------


% -------------------------------- The Program ----------------------------

% -> Sets up GUI and Camera
figure(1);
hold on;
%   -> Slider and label text for setting the number of frame averages
UIAverageSlider = uicontrol('Style', 'slider', 'Min', 1, 'Max', 50, 'Value', 10, 'Position', [400, 20 120, 20], 'Callback', @adjustAverages);
UIAverageSliderText = uicontrol('Style', 'text', 'Position', [400, 45, 120, 20], 'String', 'Frame Averages');
UITilingButton = uicontrol('Style', 'pushbutton', 'String', 'tile');
hold off;

% -> Streams the latest images from the camera, allows the user to take an
%    image to save, append to the current panorama, etc.
exitProgram = false;
cameraManager = Manager_Camera_Thorlabs(0);
%cameraManager.setMasterGain(13);
cameraManager.setExposure(100);
cameraManager.setScaleRange([0, 25]);
figure(1);
hold on;
imageObject = imshow(zeros(cameraManager.getHeight, cameraManager.getWidth), []);
hold off;

tiledManager = Manager_Tile;
oldImage = cameraManager.acquireImage(floor(UIAverageSlider.Value));
tiledManager.addImage(oldImage);
figure(2);
hold on;
stitchedObject = imshow(tiledManager.getCompositeImage());
hold off;
while(~exitProgram) % Main loop just shows camera footage
    newImage = cameraManager.acquireImage(floor(UIAverageSlider.Value));
    refresh(1);
    set(imageObject, 'CData', newImage);
    drawnow;
    similarity = ssim(newImage, oldImage);
    if(similarity < 0.85)
        pause(5);
        newImage = cameraManager.acquireImage(floor(UIAverageSlider.Value));
        refresh(1);
        set(imageObject, 'CData', newImage);
        drawnow;
        tiledManager.addImage(newImage);
        refresh(2);
        set(stitchedObject, 'CData', (tiledManager.getCompositeImage));
        drawnow;
    end
    oldImage = newImage;
end

% -------------------------- Functions and Callbacks ----------------------

%
% Description:
%   Callback triggered when the slider is moved.
%
function adjustAverages(source, event)
    UIAverageSliderText.String = sprintf('Averages Per Frame: %d', source.Value);
end
