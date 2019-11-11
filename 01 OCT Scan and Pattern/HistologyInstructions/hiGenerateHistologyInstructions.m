function HI = hiGenerateHistologyInstructions(in1,in2,operatorName,ddate,sampleID)
%This functions will generate histology instructions structure
%USAGE:
%   HI = generateHistologyInstructions(histText); %For parsing histology text
%   HI = generateHistologyInstructions(reqPos,dir); %For adding requested Positions
%INPUTS:
%in1 - can be
%   1) Vector of positions as of to where to take histology sections at
%   (request)
%   2) Text from a histology instructions file that we will interpert
%in2 - can be either 
%   1) a HI structure (from previuse iteartion) or
%   2) cutting direction indication. =1 for starting to cut from dot side,
%       =-1 for starting to cut oposite to the dot side
%operatorName - name or email of the person making the decision
%ddate - string or date number of the date decision was made, if empty will
%   set to today
%sampleID - For example 'LC-01', to keep trakc
%OUTPUT:
%HI - Histology Instructions structure with the fields
%   .sectionDepthsRequested_um - vector containing what depth each section
%       should be (in microns). This data is generated using in1. Origin of
%       this structure is at full face. 
%       Example sectionDepthsRequested_um = [500 530 560] means:
%       Get to full face, go in 500 microns and cut 3 sections 30 microns
%       apart.
%   .sectionDepthsInstructions_um - convert sectionDepthsRequested_um to
%       instructions for pathologist, given knife calibration
%   .startAtDotSide = 1 if yes, -1 if no
%   .histoKnife - defenitions about the histology machine
%              .sectionsPerSlide - how many sections per slide
%              .sectionThickness_um - usually 5 microns
%              .a5um - how much the knife advances for each cut of 5um  
%              .a25um - how much the knife advances for each cut of 25um
%   .sectionIteration - a vector containing for each section was it done in
%       first iteration (=1) or following iterations. This varible helps
%       keep track of what instructions were given to pathologist, and
%       when.
%   .iterationOperators - cell array with the operator name deciding on
%       each iteration
%   .iterationDates - cell array with the date where each iteration was
%       decided on
%   .sampleID - string
%   .version - version indication

histoKnife.sectionsPerSlide = 3;
histoKnife.sectionThickness_um = 5;
histoKnife.a5um = 10;
histoKnife.a25um = 25*1.7;

%% Process Operator Name
if ~exist('operatorName','var')
    operatorName = 'unknown';
end
i = strfind(operatorName,'@');
if ~isempty(i)
    operatorName = operatorName(1:(i-1));
end

%% Date
if ~exist('ddate','var')
    ddate = now();
end

%If date is not numeric, make it so for unified formating
if ~isnumeric(ddate)
    datenum(ddate);
end
ddate = datestr(ddate,'mmm dd, yyyy');

%% Sample ID
if ~exist('sampleID','var')
    sampleID = 'unknown';
end
    
if isnumeric(in1)
    %% Build instructions from vector
    if ~isstruct(in2)
        %Start from scratch
        HI.sectionDepthsRequested_um = in1(:);
        HI.startAtDotSide = in2;
        HI.histoKnife = histoKnife;
        HI.sectionIteration = ones(size(HI.sectionDepthsRequested_um));
        HI.iterationOperators = {operatorName};
        HI.iterationDates = {ddate};
        HI.sampleID = sampleID;
        HI.version = 1.1;
    else
        %Start from the existing structure
        HI = in2; 
        nextIteration = max(HI.sectionIteration)+1;
        
        HI.sectionDepthsRequested_um = [HI.sectionDepthsRequested_um(:);in1(:)];
        HI.sectionIteration = [HI.sectionIteration(:); ones(size(in1(:)))*nextIteration];
        HI.iterationOperators(end+1) = {operatorName};
        HI.iterationDates(end+1) = {ddate};
    end  
else
    %% Text interpetatation of instructions  
    lines = split(in1,newline);
    
    currentDepth_um = 0;
    sectionDepthsRequested_um = [];
    %Loop over every line
    for i=1:length(lines)
        l = lines{i};
        
        if(contains(lower(l),'sample id'))
            l = l(strfind(l,':')+1:end);
            sampleID = strtrim(l);
        elseif(contains(lower(l),'scanned by'))
            l = l(strfind(l,':')+1:end);
            operatorName = strtrim(l);
        elseif(contains(lower(l),'date'))
            l = l(strfind(l,':')+1:end);
            ddate = strtrim(l);
        elseif(contains(lower(l),'we want to cut sections at the same side as black dot'))
            side = 1;
        elseif(contains(lower(l),'we want to cut sections at the side opposite to the black dot'))
            side = -1;
        elseif(contains(lower(l),'take one slide / section'))
            sectionDepthsRequested_um = [sectionDepthsRequested_um currentDepth_um];
        elseif(contains(lower(l),'go in')) && ~contains(lower(l),'we would like')
            l = l((strfind(lower(l),'go in')+5):end);
            l = l(1:(strfind(lower(l),'um,')-1));
            l = strtrim(l);
            currentDepth_um = currentDepth_um+str2double(l)*histoKnife.a25um/25;
        elseif(contains(lower(l),'take') && contains(lower(l),'sections per slide'))
            l = l((strfind(lower(l),'slide (')+7):end);
            l = l(1:(strfind(lower(l),' sections')-1));
            
            nSections = str2double(strtrim(l));
            
            %Section interval is on the next line
            l = lower(lines{i+1});
            l = l((strfind(l,'interval of')+11):end);
            l = l(1:(strfind(l,'um')-1));
            interval_um = (str2double(strtrim(l))+histoKnife.sectionThickness_um)*histoKnife.a5um/5;
            
            n = 0:(nSections-1);
            sectionDepthsRequested_um = [sectionDepthsRequested_um (currentDepth_um+n*interval_um)];
            currentDepth_um = max(sectionDepthsRequested_um);
            
            %Add it to HI
            if ~exist('HI','var')
                %New HI
                HI = hiGenerateHistologyInstructions(sectionDepthsRequested_um,side,operatorName,ddate,sampleID);
            else
                HI = hiGenerateHistologyInstructions(sectionDepthsRequested_um,HI,operatorName,ddate);
            end
            sectionDepthsRequested_um = []; %Reset depths
        else
            %Do nothing
        end
    end
end
