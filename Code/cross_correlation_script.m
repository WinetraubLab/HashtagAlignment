%This is used for fine alignment of the OCT histology images.  It uses
%variables from the 'manual_feature_select' script, 'pts_hist' the marked points in the histology image and
%'point_centers', the marked points from the OCT image.
%
%
% Step #0a: Run script1.m
% Step #0b: Run manual_feature_select.m
% Step #0c: Run cross_correlation_script.m
%
% Step #1: Set Parameters
% Step #2: Create Histology Image with Gaussian Feature Points
% Step #3: Create OCT Volume Image with Gaussian Feature Points
% Step #4: Translation Registration
% Step #5: Reslice OCT Volume to Find B-Scan That Fits Histology
%% Step #1: Set Parameters
% width of the points in the z and xy directions
sigma = 2;  % z width, default 2
xy_sigma = 4; % x-y width, default 4


%% Step #2: Create Histology Image with Gaussian Feature Points
z = fspecial('gaussian', [size(histologyImage,1) size(histologyImage,2)], xy_sigma);
newImage = zeros(size(histologyImage));
for ptid = 1:size(pts_hist,1)
    newImage = newImage + imtranslate(z, [pts_hist(ptid,1)-256.5,pts_hist(ptid,2)-256.5], 'OutputView', 'Same');
end
figure; imagesc(newImage)


%Registratoin
clearvars newImage_v
newImage_ = imresize(newImage, [round(512*1.12),512]);
newImage_ = newImage_(62:end,:);
center = 15;

%% Step #3: Create OCT Volume Image with Gaussian Feature Points
OCT_newImage = zeros(size(rOCT));

for ptid = 1:size(point_centers,1)
    
    % x-y part
    %xy_sigma = 4;
    z = fspecial('gaussian', [size(histologyImage,1) size(histologyImage,2)], xy_sigma);
    z = imtranslate(z, [point_centers(ptid,1)-256.5,point_centers(ptid,2)-256.5], 'OutputView', 'Same');
    z_ = reshape(repmat(z, [1,1,30]),512,512,size(rOCT,3));
    
    % z part
    center = point_centers(ptid,3);
    %sigma = 2;
    decay = exp(-([1:size(rOCT,3)]-center).^2/(2*sigma^2));
    decay_ = reshape(repmat(decay, [512*512,1]),512,512,size(rOCT,3));
  
    OCT_newImage = z_ .* decay_ + OCT_newImage;
end


%% Step #3: Translation Registration

crosscorr = @(x) sum(sum(newImage_ .* imtranslate(OCT_newImage(:,:,x(3)), [x(1),x(2)])));
subindex = @(A, z) A(:,:,z); 

%Registering Translation
%perform crosscorrelation
clearvars cc
for z = 1:30
    for x = -200:10:200
        for y=-200:10:200
            coordinates(1) = x;
            coordinates(2) = y;
            coordinates(3) = z;
            
            cc(x+201,y+201,z) = crosscorr(coordinates);
        end
    end
end

[val,ind]= max(cc(:));
[xmax,ymax,zmax]=ind2sub(size(cc),ind);
%--------------------------------------------
%figure; imagesc(imtranslate(OCT_newImage(:,:,zmax), [xmax-200,ymax-200]))


OCT_newImage1 = imtranslate(OCT_newImage, [xmax-200,ymax-200, 15-zmax]);
figure; imagesc(imfuse(newImage_,OCT_newImage1(:,:,15)))
fprintf('x translation: %.3f[pixels], %.3f[microns]\n',xmax-200,(xmax-200)*norm(u)*1e6);
fprintf('y translation: %.3f[pixels], %.3f[microns]\n',ymax-200,(ymax-200)*norm(v)*1e6);
fprintf('z translation: %.3f[pixels], %.3f[microns]\n',15-zmax,(15-zmax)*(norm(u)+norm(v))*1e6*0.5);

%Registration via fminsearch
%x0 = [0,0,0];
%options = optimset('PlotFcns',@optimplotfval);

%[x_fmin,f_val] = fminsearch(crosscorr2,x0,options);
%registeredvol = imtranslate(OCT_newImage, [ x_fmin(1),x_fmin(2),x_fmin(3)]);
%figure; imagesc(imfuse(newImage_,registeredvol(:,:,15)))


%%  Angle Registration

RotZ = @(vol,theta) imrotate3(vol,theta,[0 0 1],'crop');
RotY = @(vol,theta) imrotate3(vol,theta,[0 1 0],'crop');
RotX = @(vol,theta) imrotate3(vol,theta,[1 0 0],'crop');
Rot = @(vol,theta) RotX(RotY(RotZ(vol,theta(1)),theta(2)),theta(3));

theta0 = [0,0,0];
options = optimset('PlotFcns',@optimplotfval);
crosscorr2 = @(theta) sum(sum(newImage_ .* subindex(Rot(OCT_newImage1,theta),15)));

%[theta_fmin,theta_val] = fminsearch(crosscorr2,theta0,options);

cc2 = [];
thetax_range =[-2:0.5:2];
thetay_range =[-2:0.5:2];
thetaz_range =[-2:0.5:2];

for thetax = thetax_range
    thetax
    for thetay = thetay_range    
        for thetaz = thetaz_range 
            theta(1) = thetax;
            theta(2) = thetay;
            theta(3) = thetaz;
            
            cc2 = [cc2 crosscorr2(theta)];
        end
    end
end

[cc2max,ind] = max(cc2(:));
arraysize = [length(thetax_range), length(thetay_range), length(thetaz_range)];
[i,j,k]=ind2sub(arraysize,ind);
theta_opt = [thetax_range(i),thetay_range(j),thetaz_range(k)];

OCT_newImage2 = Rot(OCT_newImage1,theta_opt);

% plot images - angle+translation,translation,original
figure; imagesc(imfuse(newImage_,OCT_newImage2(:,:,15)))
figure; imagesc(imfuse(newImage_,OCT_newImage1(:,:,15)))
figure; imagesc(imfuse(newImage_,OCT_newImage(:,:,15))) 

fprintf('theta x rotation: %.3f[degrees]\n',theta_opt(1));
fprintf('theta y rotation: %.3f[degrees]\n',theta_opt(2));
fprintf('theta z rotation: %.3f[degrees]\n',theta_opt(3));

%% view Final Translated and Rotated Product

newImage1 = imtranslate(rOCT, [xmax-200,ymax-200, 15-zmax]);
newImage2 = Rot(newImage1,theta_opt);
newhistology = imresize(histologyImage, [round(512*1.12),512]);
newhistology_ = newhistology(62:end,:);

figure; imagesc(imfuse(newImage1(:,:,15),1*newhistology_))