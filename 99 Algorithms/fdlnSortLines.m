function fdln = fdlnSortLines (fdln)
%This function sorts Fiducial Line structure array such that they are orderd left to
%right, tissue interface at the begning of the array


%% In case class is empty
if isempty(fdln)
    %No lines in the structure, so consider it sorted
    return;
end

%% Sort from left to right
upos = cellfun(@mean,{fdln.u_pix});
[~,iSort] = sort(upos);
fdlnOld = fdln;
for i=1:length(fdln)
    f = fdlnOld(iSort(i));
    
    if ~strcmp(f.group,'t')
        [~,ii] = sort(f.v_pix); %Sort lines from up to down
    else
        [~,ii] = sort(f.u_pix); %Tissue markers should be sorted left to right
    end
    
    f.u_pix = f.u_pix(ii);
    f.u_pix = f.u_pix(:);
    
    f.v_pix = f.v_pix(ii);
    f.v_pix = f.v_pix(:);
    fdln(i) = f;
end

%% Put tissue at the begining
fdln = fdln(:);
tI = [fdln.group] == 't';
fdln = [fdln(tI); fdln(~tI)];
