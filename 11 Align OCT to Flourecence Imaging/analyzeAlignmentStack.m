% This script loads all slides of one subject, compute trends
%run this script twice to correct slide alignment based on stack trned

%% Inputs
subjectFilePath =  's3://delazerdamatlab/Users/OCTHistologyLibrary/LB/LB-01/';

%% Find all JSONS
awsSetCredentials(1);

disp([datestr(now) ' Loading JSONs']);
ds = fileDatastore(subjectFilePath,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
jsons = ds.readall();

octJsonI = find(cellfun(@(x)contains(x,'ScanConfig.json'),ds.Files));
octVolumeJsonFilePath = ds.Files{octJsonI};
octVolumeJson = jsons{octJsonI};

slideJsonsI = find(cellfun(@(x)contains(x,'SlideConfig.json'),ds.Files));
slideJsonFilePaths = ds.Files(slideJsonsI);
slideJsons = [jsons{slideJsonsI}];

%%  Figure out slide names & other parameters
slideNames = cell(size(slideJsonFilePaths));
singlePlanes = slideNames;
fs = slideNames;
for i=1:length(slideNames)
    [~, sn] = fileparts([fileparts(slideJsonFilePaths{i}) '.tmp']);
    slideNames{i} = sn;
    
    if isfield(slideJsons(i).FM,'singlePlaneFit')
        singlePlanes{i} = slideJsons(i).FM.singlePlaneFit;
    end
    if isfield(slideJsons(i).FM,'fiducialLines')
        fs{i} = slideJsons(i).FM.fiducialLines;
    end
end

%Non empty options
ii = find(~cellfun(@isempty,singlePlanes) & ~cellfun(@isempty,fs));
singlePlanes = singlePlanes(ii);
singlePlanes = [singlePlanes{:}];
fs = fs(ii);

%% For every fame compute key parameters
plans_x = zeros(2,length(ii)); %(Start & Finish, n)
plans_y = plans_x; 
l = octVolumeJson.lineLength;

for i=1:length(ii)
    
    %Extract data
    sp = singlePlanes(i);
    f = fs{i};
    
    c = mean([sp.xIntercept_mm sp.yIntercept_mm],2);
    slopeV = [1; sp.m];
    slopeV = slopeV/norm(slopeV);
    
    plans_x(:,i) = c(1)+slopeV(1)*l/2*[1 -1];
    plans_y(:,i) = c(2)+slopeV(2)*l/2*[1 -1];
end

d_mm = zeros(1,length(ii));%Directional distance
slideCenter_mm = zeros(2,length(ii)); %Center position of the slide (x/y,n)

%Compute prepandicular direction to the slides
sn = 1:length(singlePlanes);
xm = mean(plans_x,1);
ym = mean(plans_y,1);
px = polyfit(sn,xm,1);
py = polyfit(sn,ym,1);
n = [px(1);py(1)]; n = n/norm(n);

for i=1:length(ii)
    
    %Extract data
    sp = singlePlanes(i);
    
    c = mean([sp.xIntercept_mm sp.yIntercept_mm],2); 
    slideCenter_mm(:,i) = c;
    d_mm(i) = sign(dot(c,n))*norm(c);
end

figure(100);
subplot(1,1,1); %Clear previuse figure
%% Plot all planes on one figure
subplot(2,2,1);

%Plot Photobleached lines
vLinePositions = octVolumeJson.photobleach.vLinePositions;
hLinePositions = octVolumeJson.photobleach.hLinePositions;
lineLength = octVolumeJson.photobleach.lineLength;
mm = [-1 1]*(lineLength/2);
for i=1:length(vLinePositions)
    c = vLinePositions(i);
    plot([c c],mm,'-k','LineWidth',1);
    if (i==1)
        hold on;
    end
end
for i=1:length(hLinePositions)
    c = hLinePositions(i);
    plot(mm,[c c],'-k','LineWidth',1);
end
grid on;
axis equal;
axis ij;
h = plot(plans_x,plans_y,'LineWidth',2); %Plot the planes
set(h, {'color'}, num2cell(winter(size(plans_x,2)),2));

%Texts
v = [mean(diff(mean(plans_x)));mean(diff(mean(plans_y)))];
v = v/norm(v)*0.2; 
for i = [1 size(plans_x,2)]
    d = (i==1)*2-1;
    if (abs(singlePlanes(i).rotation_deg)>90)
        %Line arrangement is filpt, so add 180[deg]
        ang = -(singlePlanes(i).rotation_deg+180);
    else
        ang = -singlePlanes(i).rotation_deg;
    end
    text(mean(plans_x(:,i))-v(1)*d,mean(plans_y(:,i))-v(2)*d,strrep(slideNames{ii(i)},'_',' '),'Rotation',ang,'HorizontalAlignment','center','VerticalAlignment','middle')
end

theDot = [octVolumeJson.theDotX; octVolumeJson.theDotY];
theDot = theDot/norm(theDot)*octVolumeJson.lineLength/2;
plot(theDot(1),theDot(2),'bo','MarkerSize',10,'MarkerFaceColor','b');

hold off;
title('Planes');
xlabel('[mm]');
ylabel('[mm]');

%% Plot distance to origin
subplot(2,2,3);
p = polyfit(sn,d_mm,1);
plot(sn,polyval(p,sn),'--r',mean(sn),polyval(p,mean(sn)),'.r');
y = ylim;
hold on;
plot(d_mm,'.');
hold off;
ylim(y);
ylabel('\mum');
xlabel('Slide #')
title('Distance From Origin');
grid on;
legend(...
    sprintf('%.0f\\mum/slide \\pm%.0f\\mum',...
    abs(p(1))*1000,...
    std(polyval(p,sn)-d_mm)*1000 ...
    ),...
    sprintf('Center: %.0f\\mum',polyval(p,mean(sn))*1000), ...
    'location','north');

%% Plot rotations
subplot(2,2,2);
rot = [singlePlanes.rotation_deg];
plot(rot,'.')
hold on;
plot(sn([1 end]),median(rot)*[1 1],'--');
hold off;
ylabel('deg');
xlabel('Slide #');
title(sprintf('Rotation Angle: %.1f \\pm %.1f[deg]',mean(rot),std(rot)));
grid on;

%% Plot size change 
subplot(2,2,4);
sc = [singlePlanes.sizeChange_precent];
plot(sc,'.')
hold on;
plot(sn([1 end]),median(sc)*[1 1],'--');
hold off;
ylabel('%');
xlabel('Slide #');
title(sprintf('1D Pixel Size Change: %.1f \\pm %.1f [%%]',mean(sc),std(sc)));
grid on;