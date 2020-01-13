function histologyInstructionsToStackConfig(subjectPath)
% This function converts histology instructions to stack config. 
% Written at Jan 10, 2020.
%%

%sp = s3GetAllSubjectsInLib();
%subjectPath = sp{1};

deleteOriginalFileWhenDone = true;

%% Figure out if this subject has the older version of histology instructions as we expect.
slidesFolder = [subjectPath '/Slides/'];

try
    hi = awsReadJSON([slidesFolder 'HistologyInstructions.json']);
catch
    disp('Couldn''t load Histology Instructions - does it even exist?, Skipping');
    return;
end

if (hi.version ~= 1.1)
    disp(['Expecting histology instructions version 1.1, found ' num2str(hi.version) ' skipping']); 
    return;
end

%% Generate output structure.
clear stackConfig;

% Loop over each iteration
for i=1:length(hi.iterationDates)
    
    % Stack Config-wide paramters
    if (i==1)
        inputs = {...
            'sampleID',hi.sampleID, ...
            'histoKnife_sectionsPerSlide', hi.histoKnife.sectionsPerSlide,...
            'histoKnife_sectionThickness_um',hi.histoKnife.sectionThickness_um,...
            'histoKnife_thicknessOf5umSlice_um',hi.histoKnife.a5um,...
            'histoKnife_thicknessOf25umSlice_um',hi.histoKnife.a25um,...
            'startCuttingAtDotSide',hi.startAtDotSide,...
        };
    else
        inputs = {'appendToSC',stackConfig};
    end
    
    % Iteration General Parameters
    inputs = [inputs {...
        'iterationNumber',i, ...
        'operator', hi.iterationOperators{i}, ...
        'date', hi.iterationDates{i}, ...
        'section_names', hi.sectionName(hi.sectionIteration==i), ...
        }];
    
    % Section Depths Requested
    if (i==1)
        ref = 0;
    else
        ref = hi.sectionDepthsRequested_um(find(hi.sectionIteration==i-1,1,'last'));
    end
    inputs = [inputs {...
        'sectionDepthsRequested_um', hi.sectionDepthsRequested_um(hi.sectionIteration==i)-ref...
        }];
    
    % Origin Depth
    if i <= length(hi.estimatedDepthOfOCTOrigin_um)
        inputs = [inputs {...
            'estimatedDistanceFromFullFaceToOCTOrigin_um', hi.estimatedDepthOfOCTOrigin_um(i)...
            }];
        d = hi.estimatedDepthOfOCTOrigin_um(i);
    end
    
    % Generate data structure
    stackConfig = scGenerateStackConfig(inputs);
end

%% Save output & delete original version.
awsWriteJSON(stackConfig,[slidesFolder 'StackConfig.json']);

if (deleteOriginalFileWhenDone)
    awsRmFile([slidesFolder 'HistologyInstructions.json']);
end