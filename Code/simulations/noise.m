%Generates noise for simulation data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Inputs:
%   - img - image to apply noise to
%Returns: 
%   - actual parameters of Pixel Size, Angle in X-Y Plane and Intercept Points
%   - algorithm predicted Pixel Size, Angle in X-Y Plane and Intercept Points
%Usage:
%   -Modify 'factor' to control the amount of multiplicative noise applied
%   to the image
%

function [imgnew] = noise(img)
    img_ = img /max(max(img))*0.8*255;
    img_ = img_ + normrnd(0,20,size(img_));
    img_(img_ < 1) = 1;
    %imgnoise = zeros(size(img));
    factor =2;
    imgnoise = sqrt(img_) .* normrnd(0,1,size(img_)) * factor; 
    
    imgnew = img_ + imgnoise;
    %imgnew = imgnew + normrnd(0,3,size(img_));

    
    imgnew(imgnew>255) = 255;
    imgnew = uint8(imgnew);
    figure; imagesc(uint8(imgnew)); colormap(gray)