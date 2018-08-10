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

close all;
clear all;

% ---------------------------------- Settings -----------------------------


% -------------------------------- The Program ----------------------------

% -> Sets up GUI and Camera
figure(1);
hold on;
%   -> Slider and label text for setting the number of frame averages
UIAverageSlider = uicontrol('Style', 'slider', 'Min', 1, 'Max', 50, 'Value', 1, 'Position', [400, 20 120, 20], 'Callback', @adjustAverages);
UIAverageSliderText = uicontrol('Style', 'text', 'Position', [400, 45, 120, 20], 'String', 'Frame Averages');
hold off;

% -> Streams the latest images from the camera, allows the user to take an
%    image to save, append to the current panorama, etc.
exitProgram = false;
cameraManager = Manager_Camera_uEye(0);
cameraManager.setMasterGain(NaN);
cameraManager.setScaleRange(NaN);
figure(1);
hold on;
imageObject = imshow(zeros(cameraManager.getHeight, cameraManager.getWidth), []);
hold off;
%{
tiledManager = Manager_Tile;
figure(2);
hold on;
stitchedObject = imshow();
hold off;
%}
while(~exitProgram) % Main loop just shows camera footage
    refresh(1);
    set(imageObject, 'CData', cameraManager.acquireImage(floor(UIAverageSlider.Value)));
    drawnow;
end

% -------------------------- Functions and Callbacks ----------------------

%
% Description:
%   Callback triggered when the slider is moved.
%
function adjustAverages(source, event)
    UIAverageSliderText.String = sprintf('Averages Per Frame: %d', source.Value);
end
