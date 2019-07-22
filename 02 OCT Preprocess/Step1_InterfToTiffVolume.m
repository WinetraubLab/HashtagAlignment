function Step1_InterfToTiffVolume(OCTFolder)
%Step #1 - convert interferograms to OCT volumes

%Batch process
myOCTBatchProcess(OCTFolder,{'dispersionParameterA',6.539e07});

%Load Overview and make an overview file, create a max projection
%depth representation
o = yOCTFromTif([OCTFolder '/overview/scanAbs.tif']);

%TBD