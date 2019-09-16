function [slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,identifyMethod,SlidesJsonsStack)
%This function preforms the basic preprocessing of a slide, identify the
%lines and do a single plane alignment
%INPUTS:
%   - slideJson - Single slide JSON file
%   - octVolumeJson - JSON file of the entire OCT Volume
%   - identifyMethod - which method to use to identify the lines. Can be:
%       'None' - keep lines as is, don't change
%       'ByLinesRatio' - identify lines by ratio between lines distances
%       'ByStack' - identify lines by interpolation of stack, must inclide
%           SlideJsonsStack as well.
%       'Manual' - prompt user to enter their insights
%   - SlidesJsonsStack - optional, if user would like to do alignment by
%       stack, Jsons of all slide should appear here
%OUTPUT:
% - isIdentifySuccssful - true when line identification was successful


%% Part #0, preprocessing
isIdentifySuccssful = false;

f = slideJson.FM.fiducialLines;
f = fdlnSortLines(f); %Sort lines such that they are organized by position, left to right
    
%% Part #1, identify lines (x-y)
switch(lower(identifyMethod))
    case {'none','asis'}
        %Do nothing, keep the identification we already have
        
    case 'bylinesratio'
        group1I = [f.group]=='1' | [f.group]=='v';
        group2I = [f.group]=='2' | [f.group]=='h';
    
        if (sum(group1I) < 3 || sum(group2I) < 3)
            isIdentifySuccssful = false;
            disp('Not enugh lines to preform identification, make that manually');
        else
            f(group1I) = fdlnIdentifyLinesByRatio(...
                f(group1I), ...
                octVolumeJson.vLinePositions,octVolumeJson.hLinePositions);
            f(group2I) = fdlnIdentifyLinesByRatio(...
                f(group2I), ...
                octVolumeJson.vLinePositions,octVolumeJson.hLinePositions);
        end
        
    case 'bystack'
        fdlnStack = cell(length(SlidesJsonsStack),1);
        for i=1:length(fdlnStack)
           if isfield(SlidesJsonsStack(i).FM,'fiducialLines')
               fdlnStack{i} = SlidesJsonsStack(i).FM.fiducialLines;
           end
        end
        
        f = fdlnIdentifyLinesByStackInterpolation(f,octVolumeJson.vLinePositions,octVolumeJson.hLinePositions,fdlnStack);
        
    case 'manual'
        fprintf('vLinePositions [mm] = %s\n',sprintf('%.3f ',octVolumeJson.vLinePositions));
        fprintf('hLinePositions [mm] = %s\n',sprintf('%.3f ',octVolumeJson.hLinePositions));
        fprintf('Please enter line groups (left to right), seperate by comma or space [can be v or h]\n');
        fprintf(   'Orig Was: %s\n',sprintf('%s',[transpose([f.group]) repmat(' ',length(f),1)]'))
        gr = input('Input:    ','s');
        gr = strsplit(lower(strtrim(gr)),{',',' '});
        gr(cellfun(@isempty,gr)) = [];

        fprintf('Please enter line positions (left to right), seperate by comma or space [in mm]\n');
        fprintf(    'Orig Was: %s\n',sprintf('%.3f ',[f.linePosition_mm]));  
        pos = input('Input:    ','s');
        pos = strsplit(strtrim(pos),{',',' '});
        pos = cellfun(@str2double,pos);

        if length(f) ~= length(pos) || length(f) ~= length(gr)
           error('Missing some lines');
        end

        for i=1:length(f)
           f(i).group = gr{i};
           f(i).linePosition_mm = pos(i);
        end
   
    otherwise
        error('Unknown Identify Method');
end

%Check if we have multiple groups present
if (sum([f.group] == 'v') >= 2) && (sum([f.group] == 'h') >=2)
    isIdentifySuccssful = true;
end

%% Part #2, Compute U,V,H & stats
if (isIdentifySuccssful)
    singlePlaneFit = alignSignlePlane(f,slideJson.FM.pixelSize_um);
else
    singlePlaneFit = NaN;
end

%% Finalize - update z position
%Get z position of the interface bettween tissue and gel, because that was
%the position we set at the begning
zInterface = octVolumeJson.VolumeOCTDimensions.z.values(octVolumeJson.focusPositionInImageZpix); %[um]
zInterface = zInterface/1000; %[mm]
grT = [f.group] == 't';
grTi = find(grT);
for i=grTi
    f(i).linePosition_mm = zInterface;
end

%% Finalize by updating the JSON structure

slideJson.FM.singlePlaneFit = singlePlaneFit;
slideJson.FM.fiducialLines = f;

end
function singlePlaneFit = alignSignlePlane(f,pixelSize_um)
%This function computes a single plane fit using Fiducial Lines.
%INPUTS:
%   f - Fiducial lines structure array
%   pixelSize_um - optional, pixel size at the Flourecent Image - this will
%       allow us to cmpute % shrinkage
%   single plane contains singlePlane.u, .v, .h and some statistics about the
%   plane

gr = [f.group];
if (sum(gr == 'v') < 2) || (sum(gr == 'h') < 2)
    singlePlaneFit = NaN;
    return; %Failed to align
end

%% Compute fit
[u,v,h] = fdlnEstimateUVHSinglePlane(f); %u,v,h in mm

singlePlaneFit.u = u;
singlePlaneFit.v = v;
singlePlaneFit.h = h;

n = cross(u/norm(u),v/norm(v)); %Compute norm vector to the plane

vspan = [min(cellfun(@min,{f.v_pix})) max(cellfun(@max,{f.v_pix}))];
v_ = mean(vspan);

%% Notes
singlePlaneFit.notes = sprintf([...
    'tilt_deg - angle between plane norm and z axis [deg] \n' ...
    'rotation_deg - rotation angle about the z axis (on the x-y plane) [deg] \n' ...
    'distanceFromOrigin_mm - distance between origin (0,0,0) to the plane [mm]\n' ...
    'sizeChange_precent - if negative value, isotropic shrinkage of the histology compared to OCT. If positive, expansino [%%]\n' ...
...    'xPlaneUFunc_pix - This describes the projection of the plane x=c on to the histology section the fuction recives v [pix] and c and returns u_pix\n' ...
...    'yPlaneUFunc_pix - This describes the projection of the plane y=c on to the histology section the fuction recives v [pix] and c and returns u_pix\n' ...
...    'zPlaneVFunc_pix - This describes the projection of the plane z=c on to the histology section the fuction recives u [pix] and c and returns v_pix\n' ...
    'xIntercept_mm - (x,y) position of where histology plane hits x=0 plane (average position) [mm]\n' ...
    'yIntercept_mm - (x,y) position of where histology plane hits y=0 plane (average position) [mm]\n' ...
    'fitScore - lower is better, distance between photobleached feducial lines to the approximation [pix]\n' ...
    'Parameters when viewing from the top, approximation if tilt was 0[deg], y=mx+n:\n' ...
    ' * m,n - equation that defines the plane\n' ...
    ' * xFunctionOfU - 2vector (to be used by polyvar) converts u coordinates to x'
    ]);

%% Top plane approximation
pt1 = 0*u+v_*v+h;
pt2 = 1*u+v_*v+h;
dp = pt2-pt1;
ml = dp(2)/dp(1);
nl = pt1(2)-pt1(1)*ml;

singlePlaneFit.m = ml;
singlePlaneFit.n = nl;
singlePlaneFit.xFunctionOfU = polyfit([0,1],[pt1(1) pt2(1)],1);
singlePlaneFit.xFunctionOfU = singlePlaneFit.xFunctionOfU(:);

%% Compute general gemoetry
tilt = asin(n(3))*180/pi; %[deg]
rotation = 90-atan2(-n(2),n(1))*180/pi; %[orientation]
if (rotation > 180)
    rotation = rotation-360;
end
dFromOrigin = abs(dot(h,n));

if exist('pixelSize_um','var')
    sizeChange = 100*(( pixelSize_um / ((norm(u)+norm(v))/2*1e3)  )-1); 
else
    sizeChange = NaN;
end

singlePlaneFit.tilt_deg = tilt;
singlePlaneFit.rotation_deg = rotation;
singlePlaneFit.distanceFromOrigin_mm = dFromOrigin;
singlePlaneFit.sizeChange_precent = sizeChange;

%% Cross sections projections
%Compute x & y intercept and how should they appear in the image

xPlaneUFunc_pix = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=c
yPlaneUFunc_pix = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=c
zPlaneVFunc_pix = @(uint,c)(-u(3)/v(3)*uint-h(3)/v(3)+c/v(3)); %z=c

%0 intercepts
yOfYIntercept = xPlaneUFunc_pix(v_,0)*u(2)+v_*v(2)+h(2);
xOfXIntercept = yPlaneUFunc_pix(v_,0)*u(1)+v_*v(1)+h(1);
singlePlaneFit.xIntercept_mm = [xOfXIntercept;0];
singlePlaneFit.yIntercept_mm = [0;yOfYIntercept];

%% Compute Fit Score, lower is better
scores = zeros(size(f));
for i=1:length(f)
    ff = f(i);
    switch(ff.group)
        case 'v'
            scores(i) = sqrt(mean( (ff.u_pix-xPlaneUFunc_pix(ff.v_pix,ff.linePosition_mm) ).^2 ));
        case 'h'
            scores(i) = sqrt(mean( (ff.u_pix-yPlaneUFunc_pix(ff.v_pix,ff.linePosition_mm) ).^2 ));
        otherwise
            scores(i) = NaN;
    end
end
singlePlaneFit.fitScore = scores(:);
end