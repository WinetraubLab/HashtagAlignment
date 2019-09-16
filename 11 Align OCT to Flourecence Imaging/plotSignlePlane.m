function plotSignlePlane(singlePlaneFit,f,histologyFluorescenceIm,octVolumeJson,isSaveFigureAsPNG)
%This function plots the data estimated by single plane fit & Fiducial line
%structure.
%INPUTS:
%   singlePlaneFit - see alignSinglePlane
%   f - Fiducial line structure
%   histologyFluorescenceIm - optional, Fluoresence image to plot on. set
%       to [] if no image is found
%   octVolumeJson - JSON loaded from the OCT Volume scan
%   isSaveFigureAsPNG - default: true

if ~exist('isSaveFigureAsPNG','var')
    isSaveFigureAsPNG = true;
end

if ~exist('histologyFluorescenceIm','var') 
    histologyFluorescenceIm = [];
end

if isstruct(singlePlaneFit)
    u = singlePlaneFit.u;
    v = singlePlaneFit.v;
    h = singlePlaneFit.h;
    
    %Plane projections
    xPlaneUFunc_pix = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=c
    yPlaneUFunc_pix = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=c
    zPlaneVFunc_pix = @(uint,c)(-u(3)/v(3)*uint-h(3)/v(3)+c/v(3)); %z=c
end

%Data from OCT Volume
if exist('octVolumeJson','var')
    lineLength = octVolumeJson.lineLength;
    hLinePositions = octVolumeJson.hLinePositions;
    vLinePositions = octVolumeJson.vLinePositions;
else
    lineLength = 2;
    hLinePositions = [f([f.group]=='h').linePosition_mm];
    vLinePositions = [f([f.group]=='v').linePosition_mm];
end

%% Figure out line order such that all lines have the same colors
plotOrder1 = zeros(length(vLinePositions),1);
plotOrder2 = zeros(length(hLinePositions),1);

for i=1:length(plotOrder1)
    tmp = find(([f.group]=='v') & abs([f.linePosition_mm] - vLinePositions(i)) < 1e-4,1,'first');
    
    if ~isempty(tmp)
        plotOrder1(i) = tmp;
    else
        plotOrder1(i) = 0; %Line not found
    end
end

for i=1:length(plotOrder2)
    tmp = find(([f.group]=='h') & abs([f.linePosition_mm] - hLinePositions(i)) < 1e-4);
    
    if (length(tmp) > 1)
        error('Two lines with the same position? (1)');
    elseif length(tmp) == 1
        plotOrder2(i) = tmp;
    else
        plotOrder2(i) = 0; %Line not found
    end
end

plotOrder = [plotOrder1; plotOrder2];

%% Setup Figure
f1 = figure(223);
set(f1,'units','normalized','outerposition',[0 0 1 1])
subplot(1,1,1);

%% Plot 
subplot(2,2,[1 2]);
delete(get(gca,'Children')); %Clear prev text (if exist)

%Plot Fluoresence if we have it
if ~isempty(histologyFluorescenceIm)
    imagesc(histologyFluorescenceIm);
    colormap gray
    
    hold on;
else 
    axis ij;
end

%Set axis
fToUse = [f.group] ~= 't';
uspanO = [min(min([f(fToUse).u_pix])) max(max([f(fToUse).u_pix]))];
uspan = uspanO+uspanO.*[-1 1]*0.1;
vspanO = [min(cellfun(@min,{f.v_pix})) max(cellfun(@max,{f.v_pix}))];
vspan = vspanO+vspanO.*[-0.2 0.2];
axis equal
xl = xlim;
yl = ylim;
r = diff(xl)/diff(yl);
vspan = mean(vspan) + diff(uspan)/r/2*[-1 1];
xlim(uspan);
ylim(vspan);
uspan = xlim;
vspan = ylim;
xlabel('u pix');
ylabel('v pix');

%Plot points found on figure
for i=1:length(plotOrder)
    if (i==1)
        hold on;
    end
    
    if (plotOrder(i) == 0)
        plot(0,0,'.'); %Use the color, but plot nothing
    else
        tmp = f(plotOrder(i));
        plot(tmp.u_pix,tmp.v_pix,'.-','LineWidth',2);
    end
end

%Plot the associated plane from the fit
if isstruct(singlePlaneFit)
for i=1:length(f)
    tmp = f(i);
    
    switch(lower(tmp.group))
        case 'v'
            cc = [1 0.8 0.8];
            plot(xPlaneUFunc_pix(vspan,tmp.linePosition_mm), vspan,'--','Color',cc);
        case 'h'
            cc = [0.8 0.8 1];
            plot(yPlaneUFunc_pix(vspan,tmp.linePosition_mm), vspan,'--','Color',cc);
        case 't'
            cc = [0.5 1 0.5];
            plot(uspan, zPlaneVFunc_pix(uspan,tmp.linePosition_mm),'--','Color',cc);
            %plot(tmp.u_pix,tmp.v_pix,'.-','Color',cc);
            
            continue; %No need to write text
    end

    text(min(tmp.u_pix),max(tmp.v_pix)+diff(vspan)/8,...
        sprintf('%+.0f\n%s',1e3*tmp.linePosition_mm,upper(tmp.group)),...
        'Color',cc,'HorizontalAlignment','center','FontSize',12,'VerticalAlignment','top');
end
end

%Plot Intercepts
if isstruct(singlePlaneFit)
    plot(xPlaneUFunc_pix(vspan,0),vspan,'--r');
    plot(yPlaneUFunc_pix(vspan,0),vspan,'--r');
    text(xPlaneUFunc_pix(mean(vspan)*1.1,0),mean(vspan)*1.1,sprintf(' x=+0\n y=%+.1fmm',singlePlaneFit.yIntercept_mm(2)),'Color','red','FontSize',12,'VerticalAlignment','top')
    text(yPlaneUFunc_pix(mean(vspan)*1.1,0),mean(vspan)*1.1,sprintf(' x=%+.1fmm\n y=+0',singlePlaneFit.xIntercept_mm(1)),'Color','red','FontSize',12,'VerticalAlignment','top')
end
hold off;

%% Plot top view
if isstruct(singlePlaneFit)

    subplot(2,2,3);
    delete(get(gca,'Children')); %Clear prev text (if exist)
    
    %Photobleached lines
    mm = [-1 1]*(lineLength/2);
    for i=1:length(vLinePositions)
        c = vLinePositions(i);
        plot([c c],mm,'-','LineWidth',1);
        if (i==1)
            hold on;
        end
    end
    for i=1:length(hLinePositions)
        c = hLinePositions(i);
        plot(mm,[c c],'-','LineWidth',1);
    end
   
    %Histology plane
    x = polyval(singlePlaneFit.xFunctionOfU,uspan);
    y = singlePlaneFit.m*x+singlePlaneFit.n;
    plot(x,y,'k');
    plot(x(1),y(1),'ko');
    text(x(1),y(1),sprintf('u=%.0f',uspan(1)));
    text(x(end),y(end),sprintf('u=%.0f',uspan(end)));
    axis equal;
    axis ij;
    hold off;
    grid on;
    title('Plane [To Scale]');
end

%% Statistics
if isstruct(singlePlaneFit)
    subplot(2,2,4)
    if (singlePlaneFit.sizeChange_precent <0)
        s = sprintf('Shrunk by %.1f%%',abs(singlePlaneFit.sizeChange_precent));
    else
        s = sprintf('Expanded by %.1f%%',abs(singlePlaneFit.sizeChange_precent));
    end
    s1 = sprintf('|u|=%.3f[microns]\n|v|=%.3f[microns]\n',norm(u)*1e3,norm(v)*1e3);
    s2 = sprintf('Size Change: %.1f%% (%s)\n',singlePlaneFit.sizeChange_precent,s);
    s3 = sprintf('Angle In X-Y Plane: %.2f[deg]\nZ Tilt: %.2f[deg]\n', ...
        singlePlaneFit.rotation_deg,singlePlaneFit.tilt_deg);
    s4 = sprintf('Distance from Origin: %.1f[um]\n',singlePlaneFit.distanceFromOrigin_mm*1000);
    
    fs = singlePlaneFit.fitScore; fs(isnan(fs)) = [];
    ss = sprintf('%.0f, ',fs); ss(end+(-1:0)) = [];
    s5 = sprintf('Fit Score (Mean) %.1f[pix].\n  Individual Lines (Left to Right): %s [pix]\n',mean(fs),ss);
    s = [s1 s2 s3 s4 s5];

    set(gcf,'Color', 'white')
    delete(get(gca,'Children')); %Clear prev text (if exist)
    text(0,0.5,s,'VerticalAlignment','Middle','HorizontalAlignment','Left','FontSize',14)
    set(gca,'Color','white');
    set(gca,'XColor','white');
    set(gca,'YColor','white');
end

%% Make figure and save
pause(0.01);
if (isSaveFigureAsPNG)
    saveas(gcf,'SlideAlignment.png');
end

