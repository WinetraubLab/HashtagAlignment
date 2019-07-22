function Step2_StitchPos(OCTFolder)
%Step #2 - Stich positions at different depths to one image

%Load JSON to get scan configuration and different depths
ds = fileDatastore([OCTFolder '\ScanConfig.json'],'ReadFcn',@readJSON);
config = ds.read();

%TBD EDWIN, your code here





function o = readJSON(filename)
fid = fopen(filename);
txt=fscanf(fid,'%s');
fclose(fid);
o = jsondecode(txt);