function [OCTToHistologyTransform] = fineAlignUsingSurface(rOCT, imBF, markedline, fastmode, OCTToHistologyTransformInitialGuess)
%This functions aligns a resliced OCT image with a brightfield image,
%based on their segmented surfaces.  It first segments out their respective
%surfaces and then aligns for translation in x-y [20 pixel increments] and 
%rotation [-20:1:20] degrees.It performs 3 optimizations for rotation and 
%translation. 1) fminsearch (rough alignment) 2) bruteforce 3) fminsearch 
%(refinement of bruteforce). 

%
%It expects that the brightfield and resliced OCT images are the same size
% 
%
%INPUTS:
% - rOCT - resliced OCT image, size [h,w]
% - imBF - brightfield image, size  [h,w] 
% - markedline - the markedline  of the Brightfield image as vector of size
%                 w, where the values are the heights of the surface in the
%                 brightfield image, with NaNs everywhere else.
% - fastmode - when set to true performs bruteforce alignment with coarser step size pf 100
%              pixels
% - OCTToHistologyTransformInitialGuess - Initial guess of the transform
%   (from user)
%OUTPUTS:
% - OCTToHistologyTransform - rigid transformation of imBF to rOCT, spatial transformation
%           stucture, OCTToHistologyTransform.T is a matrix of 3x3
%% Calculate  scale from initial guess
scale = sqrt(OCTToHistologyTransformInitialGuess(1,1)^2 + OCTToHistologyTransformInitialGuess(1,2)^2); 
imBF0 = imBF;

% resize BF image based on scale
imBF = imresize(imBF,scale,'bicubic');

% change markedline to appropriate length
residual = size(imBF,2) - length(1:(1/scale):length(markedline)); % extra padding if necessary to make same length as imBF
markedline = scale*interp1([1:length(markedline)],markedline,[1:(1/scale):length(markedline)+(1/scale)*residual]);

%% Make images same size
rOCT(isnan(rOCT)) = 0;

if size(imBF,1)>size(rOCT,1)
    rOCT = padarray(rOCT,[size(imBF,1)-size(rOCT,1),0],0,'post');
else
    imBF = padarray(imBF,[size(rOCT,1)-size(imBF,1),0],0,'post');
end

if size(imBF,2)>size(rOCT,2)
    rOCT = padarray(rOCT,[0,size(imBF,2)-size(rOCT,2)],0,'post');
else
    imBF = padarray(imBF,[0,size(rOCT,2)-size(imBF,2)],0,'post');
end



%% 7. Segment surface of OCT image
%%% oct_surface - surface of reslice2 
%%%
%%%% parameters %%%%
top_lines_to_skip = 100;
width = 10;
surface_threshold = 90;
medfilt_width = 70; % to get rid of gel surface if it exists in image

% parameters to remove kinks in segmented OCT surface before optimization
additional_surface_smoothing = 100;
additional_surface_smoothing2 = 400; % to get rid of regions far from median 
                                     % (regions where surface is likely not detected correctly)               
diff_thresh = 200^2; %200*0.7 = 140 um away from surface after surface_smoothing2 

%%%%%%%%%%%%%%%%%%%

     
% find new surface from OCT
oct_surface = zeros(size(rOCT,2),size(rOCT,3)); oct_surface(:) = nan;
a = rOCT;
a_flat = a(:); 
thresh = prctile(a_flat(a_flat~=0),surface_threshold);

% first run-through
for x = 1:size(a,2)
    % OCT
    a_1 = a(:,max(x-width,1):min(x+width,size(a,2)));  a_1(a_1==0) = nan;
    
    % medfilter removes gel surface in aline
    a_2 = medfilt1(nanmean(a_1,2),medfilt_width); 
    
    % skip lines at top of image
    a_2 = a_2(top_lines_to_skip:end); 

    % surface detected if greater than threshold
    if max(a_2) > thresh
        [~,oct_surface(x)] = max(a_2);
        oct_surface(x) = oct_surface(x) + top_lines_to_skip - 1;
    end
end

% indices = 1 (top of image) are clearly errors
zero_indices = oct_surface == 1;
oct_surface(zero_indices) = nan;

% remove right-side diagonal edges, this reduces errors at edge of
% surface
surface_buffer = 30;

for x = 1:size(a,2)
    % OCT 
    local_height = oct_surface(x);
    try
        if all(a(1:(local_height-surface_buffer),x)==0)
            oct_surface(x) = nan;
        end
    end
end

% further remove kinks in the OCT segmentation
oct_surface_ = medfilt1(oct_surface,additional_surface_smoothing,'omitnan','truncate');
oct_surface_smooth = medfilt1(oct_surface,additional_surface_smoothing2,'omitnan','truncate');

replacement_ind = ((oct_surface_ - oct_surface_smooth).^2 > diff_thresh);
oct_surface_(replacement_ind) = oct_surface_smooth(replacement_ind);

%h = figure; imagesc(rOCT); colormap(gray)
%hold on; plot(oct_surface,'linewidth',1.5)
%% 7.5 Calculate surface of brightfield image
%%% segments BF surface using masked BF image
%%%
%%% reverts to markedline when segmented line deviates too much from
%%% markedline
%%%% parameters %%%%
width = 20;
medwidth_initial = 100;
medwidth_final = 50;
bf_replacement_thresh = 4000;
%%%%%%%%%%%%%%%%%%%%

% create mask1 - largest connected component
img = imBF;
mask = imfill(img < mean(img(:)),'holes');
CC = bwconncomp(mask);
numPixels = cellfun(@numel,CC.PixelIdxList);
[~,idx] = max(numPixels);
iTemp = zeros(size(img,1), size(img,2));
iTemp(CC.PixelIdxList{idx})=1;
mask = iTemp;

% create mask2 - pixels less than percetile __
mask2 = img<prctile(img(:),30);

% fuse masks
mask_final = mask .* mask2;

clearvars bf_surface
for i=1:size(mask_final,2)
    line = mean(mask_final(:,max(i-round(width/2),1):min(round(width/2)+i,size(mask_final,2))),2); 
    line2 = medfilt1(line,medwidth_initial);

    thresh_bf = prctile(line2,65);
    ind_bf = find(line2>thresh_bf);

    if isempty(ind_bf)
        bf_surface(i) = nan;
    else
        bf_surface(i) = ind_bf(1);
    end
end

% replace with markedline when distance too far
bf_surface2 = bf_surface;
bf_replacement_ind = ((bf_surface-markedline).^2) > bf_replacement_thresh;
bf_surface2(bf_replacement_ind) = markedline(bf_replacement_ind);

% medfilt result 
bf_surface2 = medfilt1(bf_surface2,medwidth_final,'omitnan','truncate');

%h = figure; imagesc(img); colormap(gray)
%hold on; plot(bf_surface2,'linewidth',1.5)
%% 9. Brute Force Feature Matching %%%%%%%%%%%%%%%%%%%%%%
%%% fun - optimization function
%%% bruteforce - columns 1 to 3 contain optimized parameters, column 4
%%%              contains optimization function value
%%% xlim - (automatically defined) limits of manual x search, , making x_lim
%%%              too big leads to optimization failure.
%%% ylim - limits of manual y search
%%%
%%% images are first centered and rotated about their centers, which is
%%% same thing imrotate does
%%% 

%%%% parameters %%%%
thickness = 200;
y_lim_min = 10;  % minimum y search range
rot_lim = 20; % degrees of rotation search: [-rot_lim, rot_lim]
if fastmode
    skip_size = 100; % grid spacing of manual in plane translation search
else
    skip_size = 20; % grid spacing of manual in plane translation search   
end
%%%%%%%%%%%%%%%%%%%%
img_center = [round(size(rOCT,2)/2),round(size(rOCT,1)/2)]; %x,y

% center BF surface
bf_surface3 = bf_surface2-img_center(2);
y = (oct_surface_ - img_center(2))';
x = [1:length(oct_surface_)]- img_center(1);

validind = ~isnan(y);
y_ = y(validind); x_ = x(validind);

% define optimization function
index = @(v,indices) v(indices);

x__ = @(a) x_*cosd(a(3)) - y_*sind(a(3)) + a(1);
x___ = @(a)index(x__(a),unique_ind(x__(a)));

y__ = @(a) x_*sind(a(3)) + y_*cosd(a(3)) + a(2);  
y___ = @(a)index(y__(a),unique_ind(x__(a)));

fun = @(a) nansum((interp1(x___(a),y___(a),x) - bf_surface3).^2);

%%% fminsearch 1 optimization
x0 = [0,0,0]; %dx,dy,theta
options.MaxFunEvals = 100000; options.MaxIter = 100000;
options.TolFun =1e-10; options.TolX = 1e-10;
optimized = fminsearch(fun,x0,options);
theta = optimized(3); dx= optimized(1); dy = optimized(2);

% define limits of search
y_lim = max(round((max(bf_surface3) -min(bf_surface3))),y_lim_min);
oct_pts = find(oct_surface_>0); marked_pts = find(bf_surface2>0);
x_lim(1) = abs(marked_pts(1) - oct_pts(1)); x_lim(2) = abs(marked_pts(end) - oct_pts(end));

%%% manual search
clearvars manual_search

x_ind = 1; 
for x_shift = -x_lim(1):skip_size:x_lim(2)
   y_ind = 1;
   for y_shift = -y_lim:skip_size:y_lim
       rot_ind = 1;
       for rot_shift = -rot_lim:rot_lim
           manual_search(x_ind,y_ind,rot_ind) = fun([dx+x_shift,dy+y_shift,theta+rot_shift]);
           rot_ind = rot_ind + 1;
       end
       y_ind = y_ind + 1;
   end
   x_ind = x_ind + 1;
end

minValue = min(manual_search(:));
k = find(manual_search == minValue);
[i1,i2,i3] = ind2sub(size(manual_search),k);
x_shift_ = -x_lim(1) + (i1-1)* skip_size; y_shift_ = -y_lim +(i2 - 1) * skip_size; rot_shift = -rot_lim + (i3-1); 

%%% fminsearch 2
if minValue == 0  % if manual search has failed, skip results
    x0 = [optimized(1), optimized(2),optimized(3)];
else
    x0 = [optimized(1) + x_shift_, optimized(2) + y_shift_,optimized(3) + rot_shift];
end

optimized = fminsearch(fun,x0,options);
% brute force - indices 1:3 [dx,dy,theta], index 4, optimization cost function
brute_force(1:3) = optimized; 
brute_force(4) = fun(optimized);

%%%%% choose best out of plane index %%%%%
%oct_index = 100; % temporarily middle of plane, out of plane disabled
optimized = brute_force(1:3);

%%% Debug %%%
%h=figure; plot(x , interp1(x___(optimized),y___(optimized),x))
%hold on; plot(x,bf_surface3)

% Debug
%optimized_img = imtranslate(imrotate(rOCT, -optimized(3),'crop'),[optimized(1),optimized(2)]);
%figure; imagesc(imfuse(optimized_img,imBF))
%figure; imagesc(imfuse(rOCT,imtranslate(imrotate(imBF, optimized(3),'crop'),([cosd(-optimized(3)) -sind(-optimized(3))  ; sind(-optimized(3)) cosd(-optimized(3))]* [-optimized(1);-optimized(2)])')))

% Rigid matrix   
%fixed = imtranslate(imrotate(rOCT, -optimized(3),'crop'),[optimized(1),optimized(2)]);
%moving = rOCT;
%[optimizer, metric] = imregconfig('monomodal');
%tform_oct = imregtform(moving, fixed, 'rigid', optimizer, metric);
%tform = invert(tform_oct);

%output
angle = optimized(3);

%calculate angle and radius to center point of image
radius = sqrt((size(imBF,1)/2)^2 + (size(imBF,2)/2)^2);
angle0 = atand((size(imBF,1))/(size(imBF,2)));

%shift needed due to rotating from upper left corner instead of center
x_rotation = radius*cosd(angle0-angle) - radius*cosd(angle0);
z_rotation = radius*sind(angle0-angle) - radius*sind(angle0);
R_ = [cosd(-optimized(3)) -sind(-optimized(3))  ; sind(-optimized(3)) cosd(-optimized(3))];
optimized_rot =  -R_ * optimized(1:2)';

%rotation 
c = cosd(angle);
s = sind(angle);
R = [c -s 0; s c 0; 0 0 1];
scale_mat = [scale 0 0; 0 scale 0; 0 0 1];

% add shift due to rotating from upper left corner and shift calculated
% from brute force
xtranslation_pix = optimized_rot(1) - x_rotation;
ztranslation_pix = optimized_rot(2) - z_rotation;

%Combine Matrices
T = [1 0 0; 0 1 0; xtranslation_pix ztranslation_pix 1];
OCTToHistologyTransform = scale_mat*R*T; % order applied is right to left
OCTToHistologyTransform = affine2d(OCTToHistologyTransform);


% Debug
imHistRegistered = imwarp(imBF0,OCTToHistologyTransform,'OutputView',imref2d(size(rOCT)));
%figure; imagesc(imfuse(rOCT,imHistRegistered))
%% function declaration

function Z = unique_ind(v)
    [~,Z] = unique(v);
end

end
