function [isTraining, subjectNamesInTraining] = ...
    isFilesInTrainingSet(fileNames, filesInTestingSet)
% INPUTS:
% fileNames - cell array with subject names or file names
% filesInTestingSet - cell array of file names that are not in training, but in testing set
% OUTPUTS:
% isTraining - array of true / false - if true subject is in training
% subjectNamesInTraining - cell array of the subjects in training

%% Set Default
if ~exist('filesInTestingSet','var') || isempty(filesInTestingSet)
	filesInTestingSet = { ...
        'LE-03','LF-01', ... Good samples for figures
        ... Samples from unknown area, or not good
        ... alignment or histology image quality but still useable as test:
        'LD-11','LG-07', 'LG-02', ...
        ... New Samples Coming in:
        'LG-2','LG-3','LG-4','LG-5','LG-6','LG-7','LGC' ...
        }; 
end

%% Do work
isTraining = zeros(size(fileNames),'logical');
for i=1:length(isTraining)
    isInTesting = cellfun(@(x)(contains(fileNames{i},x)),filesInTestingSet);
    if ~any(isInTesting)
        isTraining(i) = true;
    end
end

subjectNamesInTraining = fileNames(isTraining);