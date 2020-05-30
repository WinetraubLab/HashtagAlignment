% This script generate datasets in multiple resolutions and scales

magnificationName_ = '10x';
fprintf('%s --- Generate %s ---\n',datestr(datetime),magnificationName_);
scriptGenerateDataset;

magnificationName_ = '2x';
fprintf('%s --- Generate %s ---\n',datestr(datetime),magnificationName_);
scriptGenerateDataset;

magnificationName_ = '4x';
fprintf('%s --- Generate %s ---\n',datestr(datetime),magnificationName_);
scriptGenerateDataset;


fprintf('%s Done Done!\n',datestr(datetime));
