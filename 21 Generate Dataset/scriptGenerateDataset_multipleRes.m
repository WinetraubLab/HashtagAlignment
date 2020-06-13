% This script generate datasets in multiple resolutions and scales

call_scriptGenerateDataset('4x');
call_scriptGenerateDataset('2x');
call_scriptGenerateDataset('10x');

fprintf('%s Done Done!\n',datestr(datetime));

function call_scriptGenerateDataset(magnificationName_)
fprintf('%s --- Generate %s ---\n',datestr(datetime),magnificationName_);
scriptGenerateDataset;
end