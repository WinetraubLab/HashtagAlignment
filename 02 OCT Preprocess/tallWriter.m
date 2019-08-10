function tallWriter (info, data)
filename = [info.RequiredLocation '\' strrep(info.RequiredFilePattern,'*','')];%Remove required pattern, its easier that way
%filename = info.SuggestedFilename;
yOCT2Mat(data{:}, filename);
end