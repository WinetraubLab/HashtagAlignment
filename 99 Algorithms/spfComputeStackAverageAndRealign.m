function [spfsOut,isOutlierOut,nOut,sectionDistanceToOriginOut,averagePixelSize_um] = spfComputeStackAverageAndRealign(spfs, speculatedDistanceToOrigin)
% This function takes an array of Single Plane Fits (spfs) and rectify them
% as they should all have the same alignment, as they are from the same
% stack
%
% INPUTS:
%    spfs - array of single plane fits (or cell array if they are not all identical)
%    speculatedDistanceToOrigin - array of speculated distance from origin
%        in [mm]. This is the best guess position of each plane. A good
%        guess is according to the histology instructions, where we asked to
%        cut.
% OUTPUTS:
%    spfsOut - re-aligned single plane fits
%    isOutlier - for each of spfs, was it use in the calculation or
%        considered outlier?
%    nOut - normal unit vertor to origin
%    sectionDistanceToOrigin - fitted section distance to origin [mm]
%       (positive numbers are further along nOut)
%    averagePixelSize_um - medain pixel size (average of |u| and |v|)

%% Input checks
spfsInLength = length(spfs);
if iscell(spfs)
    %Some of spfs are not identical / empty find them
    emptySPFsIndex = cellfun(@isempty,spfs);
    spfs = [spfs{~emptySPFsIndex}];
    
    speculatedDistanceToOrigin = speculatedDistanceToOrigin(~emptySPFsIndex);
    isSPFCell = true;
else
    emptySPFsIndex = boolean(zeros(size(spfs)));
    isSPFCell = false;
end

emptySPFsIndex = emptySPFsIndex(:);
spfs = spfs(:);
speculatedDistanceToOrigin = speculatedDistanceToOrigin(:)';

%% Refresh spfs if version is wrong
if ~isfield(spfs,'version') || spfs(1).version < 1.1
    spfs_ = arrayfun(@(x)(spfCreateFromUVH(x.u,x.v,x.h)),spfs);
else
    spfs_ = spfs;
end

%Check that we have data to work with
if (isempty(spfs_))
    %Nothing to do
    warning('No samples, nothing to do');
    isOutlier = boolean(ones(size(emptySPFsIndex)));
    [spfsOut,isOutlierOut] = makeOutput(spfs,isSPFCell,isOutlier,emptySPFsIndex);
    nOut=NaN;
    sectionDistanceToOriginOut = NaN;
    averagePixelSize_um = NaN;
    return;
end

%% 0th pass, weed out obvious outliers
isOk0 = ...
    [spfs_.sizeChange_precent] > -70 & [spfs_.sizeChange_precent] < 50 ... %Size change too dramatic
    ;
%% Concatinate data from all single plane fits

% Normal vectors
ns = cell2mat(...
    cellfun(@(x)(x(:)),{spfs_(:).normal},'UniformOutput',false)...
    ); 

% U and V size
unorms = cellfun(@(x)(norm(x)),{spfs_(:).u}); 
vnorms = cellfun(@(x)(norm(x)),{spfs_(:).v});

% U and V General Direction
umedian = median([spfs_(isOk0).u],2);
vmedian = median([spfs_(isOk0).v],2);

% h vectors
hs = cell2mat(...
    cellfun(@(x)(x(:)),{spfs_(:).h},'UniformOutput',false)...
    ); 

%% Perform first pass to figure out who are the outliers in the calculation

% Assuming all planes are relatively close, we can take the median, then
% renormalize
n = median(ns(:,isOk0),2); 
n = n/norm(n);

% Compute angle between each plane norm and stack norm
angs = acos(dot(repmat(n,[1 size(ns,2)]),ns))*180/pi; %[deg]

% Compute the size change for each u and v
sizeChangeUs = abs(unorms./median(unorms(isOk0))-1);
sizeChangeVs = abs(vnorms./median(vnorms(isOk0))-1);

% Compute plane positions compared to n
distancesToOrigin = dot(repmat(n,[1 size(hs,2)]),hs);

% Fit distances to speculatedDistanceToOrigin, see if they are close
% Will ignore systematic bias in this case
% Try both directions as we don't know if the way n is pointed is good
% Distance error is in mm
distanceError1 = distancesToOrigin - speculatedDistanceToOrigin;
distanceError1 = abs(distanceError1-nanmedian(distanceError1(isOk0)));
distanceError2 = -distancesToOrigin - speculatedDistanceToOrigin;
distanceError2 = abs(distanceError2-nanmedian(distanceError2(isOk0)));
if (nanmean(distanceError1)<nanmean(distanceError2))
    distanceError = distanceError1;
else
    distanceError = distanceError2;
end

% Criteria for outlier
isOutlier = ...
    (~isOk0)             | ... Didn't pass original test
	abs(angs) >  15      | ... Angle to the mean normal, above threshold [deg]
	sizeChangeUs > 0.20  | ... Pixel size change above threshold [%]
	sizeChangeVs > 0.20  | ... Pixel size change above threshold [%]
    distanceError > 0.3  | ... Plane position compared to guess above threshold [mm]
    isnan(distanceError) ...
    ;
isOk = ~isOutlier;

% Check to make sure we don't have too many outliers. If too many outliers
% are present, fit is failed.
if (sum(isOk) < length(isOk)/3 || sum(isOk)<2)
    warning('Not enugh good samples, everything seems to be an outlier');
    isOutlier = boolean(ones(size(isOutlier)));
    [spfsOut,isOutlierOut] = makeOutput(spfs,isSPFCell,isOutlier,emptySPFsIndex);
    nOut=NaN;
    sectionDistanceToOriginOut = NaN;
    averagePixelSize_um = NaN;
    return;
end

%% Second pass, compute stack-wise parameters 

% Assuming all planes are relatively close, we can take the mean, then
% renormalize
n = mean(ns(:,isOk),2); 
n = n/norm(n);

% Fit plane's distance from orign
distancesToOrigin = dot(repmat(n,[1 size(hs,2)]),hs);
isOk2 = ~isnan(distancesToOrigin) & isOk; %Spacial version of isOk, that makes sure h is not nan
p = polyfit(speculatedDistanceToOrigin(isOk2), distancesToOrigin(isOk2),1);
scale = p(1);

if (abs(scale) > 1.4 || abs(scale) < 1-0.5)
    warning('Scale fit is out of proportion %.2f, expecting value to be 1+-0.5. Correcting scale to 1',abs(scale));
    
    %Refit
    scale = 1*sign(scale);
    offset = median(distancesToOrigin(isOk2)-speculatedDistanceToOrigin(isOk2)*sign(scale));
    p = [scale offset];
end
distanceToOriginRefitted = polyval(p,speculatedDistanceToOrigin); %Fit corrected values

% Compute size
unormRefitted = mean(unorms(isOk));
vnormRefitted = mean(vnorms(isOk));

% Update median size to fit the mean
umedian = umedian/norm(umedian)*unormRefitted;
vmedian = vmedian/norm(vmedian)*vnormRefitted;

%% Calculate distance to origin for all sections, even those without alignment
sectionI = 1:spfsInLength;
pp = polyfit(sectionI(~emptySPFsIndex),distanceToOriginRefitted,1);
sectionDistanceToOriginOut = polyval(pp,sectionI);
sectionDistanceToOriginOut = sectionDistanceToOriginOut(:);

%% Update individual planes for all sections, even those without alignment
clear spfsOut;
isOutlierOut = zeros(spfsInLength,1);
project = @(vect)(vect - dot(vect,n)*n);
j=1;
for i=1:spfsInLength
    if (emptySPFsIndex(i))
        % Empty spf, start from scratch
        u = project(umedian);
        v = project(vmedian);
        
        h = n*sectionDistanceToOriginOut(i);
        isOutlierOut(i) = true; %This is an outlier as is not fit
    else
        % Some data is in single plane fit, use it!
        spf = spfs(j);

        % Project u,v to the new plane, correct them to preserve norm
        u = project(spf.u);
        v = project(spf.v);
        u = u*unormRefitted/norm(u);
        v = v*vnormRefitted/norm(v);

        % U and V are so off, just use median no point in fixing them
        if (dot(umedian/norm(umedian),u/norm(u)) < cos(45*pi/180))
            u = project(umedian);
        end
        if (dot(vmedian/norm(umedian),v/norm(v)) < cos(45*pi/180))
            v = project(vmedian);
        end

        % For h, replace the component prepandicular to the palne with the
        % corrected component
        h = project(spf.h) + n*sectionDistanceToOriginOut(i);
        
        isOutlierOut(i) = isOutlier(j);
        j = j + 1;
    end
    
    % Generate a new structure
    s = spfCreateFromUVH(u,v,h);

    % Make sure d is specified, its important
    if (isnan(s.d))
        s.d = sectionDistanceToOriginOut(i);
    end
    
    % Save to array
    if (i>1)
        spfsOut(i) = s;  %#ok<AGROW>
    else
        spfsOut = repmat(s,[spfsInLength 1]);
    end
end

%% Generate Output
[spfsOut,isOutlierOut] = makeOutput(spfsOut,isSPFCell,isOutlierOut,emptySPFsIndex*0);
nOut = n;
averagePixelSize_um = mean([unormRefitted vnormRefitted])*1e3;
function [spfsOut,isOutlierOut] = makeOutput(spfsOut,isSPFCell,isOutlier,emptySPFsIndex)
%Modify output to be compatible with input
if (isSPFCell)
    spfsOutCell = cell(size(emptySPFsIndex));
    isOutlierOut = boolean(ones(size(emptySPFsIndex)));
    
    j=1;
    for i=1:length(spfsOutCell)
        if(~emptySPFsIndex(i))
            spfsOutCell(i) = {spfsOut(j)};
            isOutlierOut(i) = isOutlier(j);
            j = j+1;
        end
    end
    
    spfsOut = spfsOutCell;
end