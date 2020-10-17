% This script generate datasets in multiple resolutions and scales

% Set date time such that all dataset will carry same date
dataSetInitDate_ = datestr(now,'yyyy-mm-dd'); 

call_scriptGenerateDataset('10x',dataSetInitDate_);
call_scriptGenerateDataset('4x',dataSetInitDate_);
call_scriptGenerateDataset('2x',dataSetInitDate_);
fprintf('%s Done Done!\n',datestr(datetime));
clear dataSetInitDate

function call_scriptGenerateDataset(magnificationName_,dataSetInitDate_)
fprintf('%s --- Generate %s ---\n',datestr(datetime),magnificationName_);
scriptGenerateDataset;
end