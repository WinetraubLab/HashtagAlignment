function drawSlideStatus(im,FM)
% Helper function to draw status on figure 
% Inputs: im - flourecense image, FM - Flourecense Microscope Json file

L = get(gca,{'xlim','ylim'});  % Get axes limits.
imagesc(im);
axis equal;
axis off;
colormap gray;

if (sum(L{1} == [0 1]) + sum(L{2} == [0 1]) == 4)
    %This is the first time the figure appears. No zoom to return to
else
    zoom reset
    set(gca,{'xlim','ylim'},L)
end

hold on;
if isfield(FM,'fiducialLines') 
    for i=1:length(FM.fiducialLines)
        ln = FM.fiducialLines(i);
        switch(ln.group)
            case {'1','v'}
                spec = '-ob';
            case {'2','h'}
                spec = '-or';
            case '-'
                spec = '--oy';
            case 't'
                spec = '--o';
        end
        
        if (ln.group ~= 't')
            plot(ln.u_pix,ln.v_pix,spec,'LineWidth',2); 
        else
            plot(ln.u_pix,ln.v_pix,spec,'LineWidth',2,'Color',[0.9 0.9 0.9]);
        end
    end
end
hold off;