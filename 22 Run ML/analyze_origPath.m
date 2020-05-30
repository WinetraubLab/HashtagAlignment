function [isPathToDataset, origDatasetName] = analyze_origPath (origPath)
% This is an auxilary script to get if the origPath is originated in a
% dataset or a snapshot, and get the name

origPath = awsModifyPathForCompetability([origPath '/'],true);

if (contains(origPath,'_Datasets/'))
    isPathToDataset = true;
else
    isPathToDataset = false;
end

[~,txt] = fileparts([origPath(1:(end-1)) '.a']);
origDatasetName = txt(1:find(txt == 'x',1,'first'));