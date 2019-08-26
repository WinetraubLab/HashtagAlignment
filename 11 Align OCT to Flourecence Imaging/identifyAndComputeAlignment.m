%This function identifies lines and compute basic alignment (single plane)

%% Inputs
slideFilepath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/Slides/Slide01_Section01/SlideConfig.json';

rewriteMode = true; %Don't re write information

%% Jenkins?
if exist('slideFilepath_','var')
    slideFilepath = slideFilepath_;
end

%% Extract Slide Folder
slideFolder = awsModifyPathForCompetability([fileparts(slideFilepath) '/']);
ds = fileDatastore(slideFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
slideJsonFilePath = ds.Files{1};
slideJson = ds.read();

octVolumeFolder = awsModifyPathForCompetability([slideFolder '../../OCTVolumes/']);
ds = fileDatastore(octVolumeFolder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
octVolumeJsonFilePath = ds.Files{1};
octVolumeJson = ds.read();

f = slideJson.FM.fiducialLines;

%% Load Flourecent image
ds = fileDatastore(awsModifyPathForCompetability([slideFolder slideJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
histologyFluorescenceIm = ds.read();

%% Identify Lines
f = fdlnSortLines(f); %Sort lines such that they are organized by position, left to right

isidentifySuccssful = false;
if ~contains([f.group],'1') && ~rewriteMode
    %Identification already happend, skip
    isidentifySuccssful = true;
else
    
    %Get z position of the interface bettween tissue and gel, because that was
    %the position we set at the begning
    zInterface = octVolumeJson.VolumeOCTDimensions.z.values(octVolumeJson.focusPositionInImageZpix); %[um]
    zInterface = zInterface/1000; %[mm]
    grT = [f.group] == 't';
    grTi = find(grT);
    for i=grTi
        f(i).linePosition_mm = zInterface;
    end

    
    group1I = [f.group]=='1' | [f.group]=='v';
    group2I = [f.group]=='2' | [f.group]=='h';
    
    f(group1I) = fdlnIdentifyLines(...
        f(group1I), ...
        octVolumeJson.vLinePositions,octVolumeJson.hLinePositions);
    f(group2I) = fdlnIdentifyLines(...
        f(group2I), ...
        octVolumeJson.vLinePositions,octVolumeJson.hLinePositions);
    
    if (sum([f.group] ~= f(1).group) ~= 0)
        isidentifySuccssful = true;
    end
end

slideJson.FM.fiducialLines = f;

%% Compute U,V,H
if (isidentifySuccssful)
[u,v,h] = fdlnEstimateUVHSinglePlane(f);

slideJson.FM.singlePlaneFit.u = u;
slideJson.FM.singlePlaneFit.v = v;
slideJson.FM.singlePlaneFit.h = h;

%% Compute plane fit statistics
n = cross(u/norm(u),v/norm(v));
tilt = asin(n(3))*180/pi;
rotation = atan2(-n(2),n(1))*180/pi;
dFromOrigin = dot(h,n);
sizeChange = 100*((  slideJson.FM.pixelSize_um / ((norm(u)+norm(v))/2*1e3)  )-1); 

slideJson.FM.singlePlaneFit.tilt_deg = tilt;
slideJson.FM.singlePlaneFit.rotation_deg = rotation;
slideJson.FM.singlePlaneFit.distanceFromOrigin_mm = dFromOrigin;
slideJson.FM.singlePlaneFit.sizeChangePrecent = sizeChange;

%Compute x & y intercept and how should they appear in the image
u_yIntercept = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=0
u_xIntercept = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=0

vspan = [min(min([f.v_pix])) max(max([f.v_pix]))];
yOfYIntercept = u_yIntercept(mean(vspan),0)*u(2)+mean(vspan)*v(2)+h(2);
xOfXIntercept = u_xIntercept(mean(vspan),0)*u(1)+mean(vspan)*v(1)+h(1);
slideJson.FM.singlePlaneFit.xIntercept_mm = [xOfXIntercept 0];
slideJson.FM.singlePlaneFit.yIntercept_mm = [0 yOfYIntercept];

%Compute x & y intercept and how should they appear in the image
u_yIntercept = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=0
u_xIntercept = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=0

end
%% Plot

f1 = figure(223);
set(f1,'units','normalized','outerposition',[0 0 1 1])
subplot(2,2,[1 2]);

%Main Figure
imagesc(histologyFluorescenceIm);
colormap gray
hold on;
uspan = [min(min([f.u_pix])) max(max([f.u_pix]))];
uspan = uspan+uspan.*[-1 1]*0.05;
vspan = [min(min([f.v_pix])) max(max([f.v_pix]))];
vspan = vspan+vspan.*[-0.2 0.75];
xlim(uspan);
ylim(vspan);
axis equal
uspan = xlim;
vspan = ylim;
xlabel('u pix');
ylabel('v pix');

%Plot points found on figure
for i=1:length(f)
    tmp = f(i);
    
    switch(lower(tmp.group))
        case {'h','2'}
            cc = [0.8 0.8 1];
        case {'v','1'}
            cc = [1 0.8 0.8];
        case 't'
            continue; %No need to plot tissue
    end
    
    plot(tmp.u_pix,tmp.v_pix,'.-','LineWidth',2);
    vspan1 = max(tmp.v_pix)-min(tmp.v_pix);
    text(min(tmp.u_pix),max(tmp.v_pix)+diff(vspan)/8,...
        sprintf('%+.0f\n%s',1e3*tmp.linePosition_mm,upper(tmp.group)),...
        'Color',cc,'HorizontalAlignment','center','FontSize',12,'VerticalAlignment','top');
end

if isidentifySuccssful
    %Plot Intercepts
    for i=1:length(octVolumeJson.hLinePositions)
        plot(u_xIntercept(vspan,octVolumeJson.hLinePositions(i)),vspan,'--','Color',[0.8 0.8 1]);
    end
    for i=1:length(octVolumeJson.vLinePositions)
        plot(u_yIntercept(vspan,octVolumeJson.vLinePositions(i)),vspan,'--','Color',[1 0.8 0.8]);
    end

    plot(u_yIntercept(vspan,0),vspan,'--r');
    plot(u_xIntercept(vspan,0),vspan,'--r');
    text(u_yIntercept(mean(vspan)*1.1,0),mean(vspan)*1.1,sprintf(' x=+0\n y=%+.1fmm',yOfYIntercept),'Color','red','FontSize',12,'VerticalAlignment','top')
    text(u_xIntercept(mean(vspan)*1.1,0),mean(vspan)*1.1,sprintf(' x=%+.1fmm\n y=+0',xOfXIntercept),'Color','red','FontSize',12,'VerticalAlignment','top')
end
hold off;

%Plot Plane
subplot(2,2,3);
if isidentifySuccssful
mm = [-1 1]*(octVolumeJson.lineLength/2);
for i=1:length(f)
    c = f(i).linePosition_mm;
    switch(lower(f(i).group))
        case 'v'
            plot([c c],mm,'-','LineWidth',1);
        case 'h'
            plot(mm,[c c],'-','LineWidth',1);
    end
    
    if (i==1)
        hold on;
    end
end

v_ = 0;
plot(u(1)*uspan+v(2)*v_+h(1),u(2)*uspan+v(2)*v_+h(2),'k');
plot(u(1)*uspan(1)+v(2)*v_+h(1),u(2)*uspan(1)+v(2)*v_+h(2),'ko');
text(u(1)*uspan(1)+v(2)*v_+h(1),u(2)*uspan(1)+v(2)*v_+h(2),sprintf('u=%.0f',uspan(1)));
text(u(1)*uspan(end)+v(2)*v_+h(1),u(2)*uspan(end)+v(2)*v_+h(2),sprintf('u=%.0f',uspan(end)));
axis equal;
hold off;
grid on;
title('Plane [To Scale]');

subplot(2,2,4)
if (sizeChange <0)
    s = sprintf('Shrunk by %.1f%%',abs(sizeChange));
else
    s = sprintf('Expanded by %.1f%%',abs(sizeChange));
end
s1 = sprintf('|u|=%.3f[microns]\n|v|=%.3f[microns]\n',norm(u)*1e3,norm(v)*1e3);
s2 = sprintf('Size Change: %.1f%% (%s)\n',sizeChange,s);
s3 = sprintf('Angle In X-Y Plane: %.2f[deg]\nZ Tilt: %.2f[deg]\n',rotation,tilt);
s4 = sprintf('Distance from Origin: %.1f[um]',dFromOrigin*1000);
s = [s1 s2 s3 s4];

set(gcf,'Color', 'white')
delete(get(gca,'Children')); %Clear previuse text
text(0,0.5,s,'VerticalAlignment','Middle','HorizontalAlignment','Left','FontSize',14)
set(gca,'Color','white');
set(gca,'XColor','white');
set(gca,'YColor','white');
end
pause(0.01);

%% Prompt user, would they like to update before we save?
if (rewriteMode)
   button = questdlg('Would you like to manually override line identification?','Q','Yes','No','No');
   if (strcmp(button,'Yes'))
       fi = [f.group] ~= 't';
       fi = find(fi);
       
       fprintf('vLinePositions [mm] = %s\n',sprintf('%.3f ',octVolumeJson.vLinePositions));
       fprintf('hLinePositions [mm] = %s\n',sprintf('%.3f ',octVolumeJson.hLinePositions));
       fprintf('Please enter line groups (left to right), seperate by comma or space [can be v or h]\n Was: ')
       fprintf('%s',sprintf('%s',[transpose([f(fi).group]) repmat(' ',length(fi),1)]'));
       gr = input('\n','s');
       gr = strsplit(gr,{',',' '});
       gr(cellfun(@isempty,gr)) = [];
       
       fprintf('Please enter line positions (left to right), seperate by comma or space [in mm]\n Was: ');
       fprintf('%.3f ',[f(fi).linePosition_mm]);  
       pos = input('\n','s');
       pos = strsplit(pos,{',',' '});
       pos = cellfun(@str2double,pos);
       
       
       if length(fi) ~= length(pos) || length(fi) ~= length(gr)
           error('Missing some lines');
       end
       
       for i=1:length(fi)
           f(i).group = gr(i);
           f(i).linePosition_mm = pos(i);
       end
       
       slideJson.FM.fiducialLines = f;
   end
end

%% Save to JSON & figure
if (rewriteMode)
    awsWriteJSON(slideJson,slideJsonFilePath);
    
    saveas(gcf,'SlideAlignment.png');
    if (awsIsAWSPath(slideJsonFilePath))
        %Upload to AWS
        awsCopyFileFolder('SlideAlignment.png',[fileparts(slideJsonFilePath) '/SlideAlignment.png']);
    else
        copyfile('SlideAlignment.png',[fileparts(slideJsonFilePath) '\SlideAlignment.png']);
    end   
end