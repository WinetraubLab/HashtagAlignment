function scGenerateHistologyInstructionsFile(stackConfig,outFilePath,iterations)
%INPUTS:
%   stackConfig - can be stackConfig structure, or file path to stackConfig
%   outFilePath - where to save file, file format can be pdf or txt
%   iterations - optional, specify which iteration of sending the sample to
%       output, keep empty for all iteration

%% Input check

if (awsIsAWSPath(outFilePath))
    awsSetCredentials(1); %we will need to upload files there
end

if ~isstruct(stackConfig)
    %Load
    scInputFP = stackConfig;
    stackConfig = awsReadJSON(stackConfig);
else
    scInputFP = 'json file';
end

if ~exist('iterations','var') || isempty(iterations)
    iterations = 1:length(stackConfig.histologyInstructions.iterations);
end

%Using extension of output file, determine header and how to bold
[~,~,ext] = fileparts(outFilePath);
finalExt = ext;
switch(lower(ext))
    case '.txt'
        nl = newline;
        bStart = '';
        bEnd = '';
        headerStart = '';
        headerEnd = '';
        tab = '   ';
    case '.pdf'
        ext = '.html';
        nl = ['<br>' newline];
        bStart = '<span style=''font-weight: bold;background-color: yellow !important;font-size: big''>';
        bEnd   = '</span>';
        headerStart = [...
            '<html><head><style>' newline ...
            '@media print {' newline ...
            'body {-webkit-print-color-adjust: exact;}' newline ...
            '}</style></head><body>' newline ...
            ];
        headerEnd = '</body></html>';
        tab = '&nbsp;&nbsp;&nbsp;';
    otherwise
        error('Unknown extention %s, file path: %s',ext,outFilePath);
end

%% Generate file
fid = fopen(['tmp' ext],'w');
fprintf(fid,'%s',headerStart);
fprintf(fid,'Sample ID: %s%s',stackConfig.sampleID,nl);

for ii = 1:length(iterations)
    it = iterations(ii);
    
    %Iteration header
    if it > 1
        fprintf(fid,'Followup, iteration #%d%s',it,nl);
    end
    
    
    %Title
    fprintf(fid,'Scanned by: %s%s',stackConfig.histologyInstructions.iterations(it).operator,nl) ;
    fprintf(fid,'Date: %s%s',stackConfig.histologyInstructions.iterations(it).date,nl);
    fprintf(fid,'%s',nl);
    
    %First iteration header
    if (ii == 1)
        fprintf(fid,'* This file contains the post calibration instructions.%s',nl);
        fprintf(fid,'* To view original values, see %s%s',scInputFP,nl);
        fprintf(fid,'%s',nl);
    end
    if(it == 1)
        fprintf(fid,'%s%s%s%s',titleTxt('Instructions for Us'),nl,titleTxt(),nl);
        
        if (stackConfig.histologyInstructions.iterations(it).startCuttingAtDotSide == 1)
            fprintf(fid,'+ We want to cut sections at the same side as black dot.%s',nl);
            fprintf(fid,'+ Mark a red dot on the side opposite to the black dot. %s',nl);
        else
            fprintf(fid,'+ We want to cut sections at the side opposite to the black dot.%s',nl);
            fprintf(fid,'+ Mark a red dot on the same side as black dot. %s',nl);
        end
        
        fprintf(fid,'+ Place sample in the cassette such that red dot is facing up.%s',nl);
        fprintf(fid,'%s%s',nl,nl);
    end
    
    %Instructions for histology
    fprintf(fid,'%s%s%s%s',titleTxt('Instructions for Histology'),nl,titleTxt(),nl);
    
    if (it==1)
        fprintf(fid,'+ Start cutting from the side opposite to the red dot.%s',nl);
        fprintf(fid,'+ Clear paraffin, when seeing a full face.%s',nl);    
    else
        fprintf(fid,'+ Continue cutting from the cut face.%s',nl);   
    end
    
    %Loop over all sections to cut
    s = stackConfig.histologyInstructions.iterations(it).sectionDepthsRequested_um;
    pos = 0; % Current knife position compared to the full face.
    
    %Devide sections to cut to groups
    sGroups = zeros(size(s));
    sGroups(1) = 1;
    for j=2:(length(s)-1)
        d = diff(s((j-1):(j+1)));
        
        if (d(1) == d(2))
            sGroups(j) = sGroups(j-1);
        else
            sGroups(j) = sGroups(j-1)+1; %There is a jum, its a new group
        end
    end
    sGroups(end) = sGroups(end-1);
    
    %Loop over groups
    for j=1:max(sGroups)
        ss = s(sGroups == j);
        
        %Advance to where we need to go
        if (ss(1) > pos+stackConfig.histologyInstructions.histoKnife.thicknessOf25umSlice_um) %Make sure one cut is possible
            d = ss(1)-pos;
            n25Cuts = round(d/stackConfig.histologyInstructions.histoKnife.thicknessOf25umSlice_um);
            
            fprintf(fid,'+ Then %sgo in %.0f um%s, by cutting %.0f sections using slide thickness setting of 25 um.%s', ...
                bStart,n25Cuts*25,bEnd,n25Cuts,nl);
        else
            %No Advance is needed
        end
        
        %Take sections
        nSections = length(ss);
        if (nSections == 1)
            %Only one section
            fprintf(fid,'+ Take %sone slide%s / section.%s',bStart,bEnd,nl); 
        else
            nSlides = ceil(nSections/stackConfig.histologyInstructions.histoKnife.sectionsPerSlide);
            fprintf(fid,'+ Then take %s%.0f slides%s with %.0f sections per slide (%.0f sections).%s',...
                bStart,nSlides,bEnd,stackConfig.histologyInstructions.histoKnife.sectionsPerSlide,nSections,nl);
            
            interval = diff(ss(1:2)) / stackConfig.histologyInstructions.histoKnife.thicknessOf5umSlice_um*5 - stackConfig.histologyInstructions.histoKnife.sectionThickness_um;
            fprintf(fid,'%s- Section interval of %.0f um.%s',tab,interval,nl);
        end
        fprintf(fid,'%s- Slide thickness of %.0f um.%s',tab,stackConfig.histologyInstructions.histoKnife.sectionThickness_um,nl);
        
        pos = ss(end);
    end
    
    %End of iteration
    fprintf(fid,'%s%s%s%s',titleTxt(),nl,nl,nl);
end

fprintf(fid,'%s',headerEnd);
fclose (fid);

%% Convert to pdf if required
if (strcmpi(finalExt,'.pdf'))
   %Use chrome to generate a PDF if its installed
   chromePath = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe';
   if ~exist(chromePath,'file')
       error('Please install chrome to be able to generate PDF');
   end
   
   system(sprintf('"%s" --headless --print-to-pdf="%s" "%s"', ...
       chromePath,[pwd '\tmp.pdf'],[pwd '\tmp.html'] ... 
       ));
   
   delete('tmp.html'); %Cleanup HTML file
end

%% Upload or move around if required
tmpFile = ['tmp' finalExt];
awsCopyFileFolder(tmpFile,outFilePath);
delete(tmpFile);

function txtOut = titleTxt(txt)
n = 80;
txtOut = repmat('-',1,n);

if exist('txt','var') && ~isempty(txt)
    txt = ['  ' txt '  '];
    st = round(n/2 - length(txt)/2);
    en = st+length(txt)-1;
    txtOut(st:en) = txt;
end