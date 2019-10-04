function [slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(slideJson,octVolumeJson,identifyMethod,SlidesJsonsStack,histologyFluorescenceIm)
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
%       'AllOptions' - will try every option and let user decide which
%           works
%   - SlidesJsonsStack - optional, if user would like to do alignment by
%       stack, Jsons of all slide should appear here
%   - histologyFluorescenceIm - optional, will allow better visualization
%       of all options
%OUTPUT:
% - isIdentifySuccssful - true when line identification was successful

if ~exist('SlidesJsonsStack','var')
    SlidesJsonsStack = NaN;
end

if ~exist('histologyFluorescenceIm','var')
    histologyFluorescenceIm = [];
end
%% Part #0, preprocessing
isIdentifySuccssful = false;

f = slideJson.FM.fiducialLines;
f = fdlnSortLines(f); %Sort lines such that they are organized by position, left to right
    
%% Part #1, identify lines (x-y)
if isfield(octVolumeJson,'version') && octVolumeJson.version == 2
    vLinePositions = octVolumeJson.photobleach.vLinePositions;
    hLinePositions = octVolumeJson.photobleach.hLinePositions;
else
    vLinePositions = octVolumeJson.vLinePositions;
    hLinePositions = octVolumeJson.hLinePositions;
end 

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
                f(group1I), vLinePositions, hLinePositions);
            f(group2I) = fdlnIdentifyLinesByRatio(...
                f(group2I), vLinePositions, hLinePositions);
        end
        
    case 'bystack'
        fdlnStack = cell(length(SlidesJsonsStack),1);
        for i=1:length(fdlnStack)
           if isfield(SlidesJsonsStack(i).FM,'fiducialLines')
               fdlnStack{i} = SlidesJsonsStack(i).FM.fiducialLines;
           end
        end
        
        f = fdlnIdentifyLinesByStackInterpolation(f, vLinePositions, hLinePositions,fdlnStack);
        
    case 'manual'
        fprintf('vLinePositions [mm] = %s\n',sprintf('%.3f ',vLinePositions));
        fprintf('hLinePositions [mm] = %s\n',sprintf('%.3f ',hLinePositions));
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
        
    case 'alloptions'
        
        f = identifyLinesAndAlignSlide_GoOverAllOptions(f,vLinePositions,hLinePositions,...
            slideJson.FM.pixelSize_um,octVolumeJson,histologyFluorescenceIm);
   
    otherwise
        error('Unknown Identify Method');
end

%Check if we have multiple groups present
if (sum([f.group] == 'v') >= 2) && (sum([f.group] == 'h') >=2)
    isIdentifySuccssful = true;
end

%% Update z position of tissue interface
%Get z position of the interface bettween tissue and gel, because that was
%the position we set at the begning
zInterface = octVolumeJson.VolumeOCTDimensions.z.values(octVolumeJson.focusPositionInImageZpix); %[um]
zInterface = zInterface/1000; %[mm]
grT = [f.group] == 't';
grTi = find(grT);
for i=grTi
    f(i).linePosition_mm = zInterface;
end

%% Part #2, Compute U,V,H & stats
if (isIdentifySuccssful)
    singlePlaneFit = alignSignlePlane(f,slideJson.FM.pixelSize_um);
else
    singlePlaneFit = NaN;
end

%% Finalize by updating the JSON structure

slideJson.FM.singlePlaneFit = singlePlaneFit;
slideJson.FM.fiducialLines = f;

end