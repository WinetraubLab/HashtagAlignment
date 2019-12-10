function [spfsOut,isOutlier] = spfRealignByStack(spfs, speculatedDistanceToOrigin)
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

%% Input checks
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

%% Concatinate data from all single plane fits

% Normal vectors
ns = cell2mat(...
    cellfun(@(x)(x(:)),{spfs_(:).normal},'UniformOutput',false)...
    ); 

% U and V size
unorms = cellfun(@(x)(norm(x)),{spfs_(:).u}); 
vnorms = cellfun(@(x)(norm(x)),{spfs_(:).v});

% U and V General Direction
umedian = median([spfs_(:).u],2);
vmedian = median([spfs_(:).v],2);

% h vectors
hs = cell2mat(...
    cellfun(@(x)(x(:)),{spfs_(:).h},'UniformOutput',false)...
    ); 

%% Perform first pass to figure out who are the outliers in the calculation

% Assuming all planes are relatively close, we can take the median, then
% renormalize
n = median(ns,2); 
n = n/norm(n);

% Compute angle between each plane and n
ang = acos(dot(repmat(n,[1 size(ns,2)]),ns))*180/pi; %[deg]

% Compute the size change for each u and v
sizeChangeU = abs(unorms./median(unorms)-1);
sizeChangeV = abs(vnorms./median(vnorms)-1);

% Compute plane positions compared to n
distanceToOrigin = dot(repmat(n,[1 size(hs,2)]),hs);

% Fit distances to speculatedDistanceToOrigin, see if they are close
% Will ignore systematic bias in this case
% Try both directions as we don't know if the way n is pointed is good
% Distance error is in mm
distanceError1 = distanceToOrigin - speculatedDistanceToOrigin;
distanceError1 = abs(distanceError1-median(distanceError1));
distanceError2 = -distanceToOrigin - speculatedDistanceToOrigin;
distanceError2 = abs(distanceError2-median(distanceError2));
if (mean(distanceError1)<mean(distanceError2))
    distanceError = distanceError1;
else
    distanceError = distanceError2;
end

% Criteria for outlier
isOutlier = ...
	abs(ang) >  5       | ... Angle to the mean normal, above threshold [deg]
	sizeChangeU > 0.06  | ... Pixel size change above threshold [%]
	sizeChangeV > 0.06  | ... Pixel size change above threshold [%]
    distanceError > 0.1    ... Plane position compared to guess above threshold [mm]
    ;
isOk = ~isOutlier;

% Check to make sure we don't have too many outliers. If too many outliers
% are present, fit is failed.
if (sum(isOk) < length(isOk)/3 || sum(isOk)<2)
    warning('Not enugh good samples, everything seems to be an outlier');
    isOutlier = boolean(ones(size(isOutlier)));
    [spfsOut,isOutlier] = makeOutput(spfs,isSPFCell,isOutlier,emptySPFsIndex);
    return;
end

%% Second pass, compute stack-wise parameters 

% Assuming all planes are relatively close, we can take the mean, then
% renormalize
n = mean(ns(:,isOk),2); 
n = n/norm(n);

% Fit plane's distance from orign
distanceToOrigin = dot(repmat(n,[1 size(hs,2)]),hs);
isOk2 = ~isnan(distanceToOrigin) & isOk; %Spacial version of isOk, that makes sure h is not nan
p = polyfit(speculatedDistanceToOrigin(isOk2), distanceToOrigin(isOk2),1);
scale = p(1);

if (abs(scale) > 1.4 || abs(scale) < 1-0.5)
    warning('Scale fit is out of proportion %.2f, expecting value to be 1+-0.5. Correcting scale to 1',abs(scale));
    
    %Refit
    scale = 1*sign(scale);
    offset = median(distanceToOrigin(isOk2)-speculatedDistanceToOrigin(isOk2)*sign(scale));
    p = [scale offset];
end
distanceToOriginRefitted = polyval(p,speculatedDistanceToOrigin); %Fit corrected values

% Compute size
unormRefitted = mean(unorms(isOk));
vnormRefitted = mean(vnorms(isOk));

% Update median size to fit the mean
umedian = umedian/norm(umedian)*unormRefitted;
vmedian = vmedian/norm(vmedian)*vnormRefitted;

%% Update individual planes according to the stack alignment
clear spfsOut;
project = @(vect)(vect - dot(vect,n)*n);
for i=1:length(spfs)
    spf = spfs(i);
    
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
    h = project(spf.h) + n*distanceToOriginRefitted(i);
    
    % Generate a new structure
    s = spfCreateFromUVH(u,v,h);
    
    % Save to array
    if (i>1)
        spfsOut(i) = s;  %#ok<AGROW>
    else
        spfsOut = repmat(s,size(spfs));
    end
end

[spfsOut,isOutlier] = makeOutput(spfsOut,isSPFCell,isOutlier,emptySPFsIndex);

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