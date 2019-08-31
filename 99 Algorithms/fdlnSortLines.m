function fdln = fdlnSortLines (fdln)
%This function sorts Fiducial Line structure array such that they are orderd left to
%right, tissue interface at the begning of the array

%% Sort from left to right
upos = cellfun(@mean,{fdln.u_pix});
[~,iSort] = sort(upos);
fdlnOld = fdln;
for i=1:length(fdln)
    f = fdlnOld(iSort(i));
    [~,ii] = sort(f.v_pix);
    f.u_pix = f.u_pix(ii);
    f.v_pix = f.v_pix(ii);
    fdln(i) = f;
end

%% Put tissue at the begining
fdln = fdln(:);
tI = [fdln.group] == 't';
fdln = [fdln(tI); fdln(~tI)];
