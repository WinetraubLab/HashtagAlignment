function writeMatFileToCloud(data,path)
%This function writes a single file to path. Notice that it will create a
%folder in path because of the way tall works, so path might be slightly
%different then expected

T = tall({data});
location = awsModifyPathForCompetability(sprintf('%s/m*.mat',path),false);
evalc(... use evalc to reduce number of screen prints
    'write(location,T,''WriteFcn'',@tallWriter)' ... %Not a trivial implementation but it works
    ); 

end

function tallWriter (info, data)
if (info.PartitionIndex ~= 1) || (info.BlockIndexInPartition ~= 1)
    error('info.PartitionIndex = %d, info.BlockIndexInPartition = %d - both should be 1',...
        info.PartitionIndex,info.BlockIndexInPartition);
end
ff = strrep(info.RequiredFilePattern,'*','1');%Remove required pattern, its easier that way
filename1 = sprintf('%s/%s',info.RequiredLocation, ff);
%filename1 = info.SuggestedFilename;
yOCT2Mat(data{:}, filename1);
end