%User interface. User marks the edges of each line and the algorithm estimates the location of the  
% middle of the line.
%USAGE:
%   [ptsPixPosition, ptsId] = findLines (img,lnNames)
%INPUTS:
%   img - Histology fluorescence image with "bar code" on it 
%   InNames- A string that contains the name of the line (for example -x)
%  
%OUTPUTs
%   ptsPixPosition - Vector containing position of lines identified (in pixels, x,y)
%   ptsId -  Vector of line identifiers
%   
%Example:
%   Let us assume 4 lines in the image:
%       n1,n2 parallel to y axis positioned in x=-50microns, x=+50 microns
%       n3,n4 parallel to x axis positioned in y=-50microns, y=+50 microns
% - The user will be asked to mark the edges of the lines (will appear as red lines)
% - The algorithm will compute the estimate of the location of the line (will appear as a green line)
%Notice:
%       1) Circle each line in a bounding polygon

% Options:
% -> Selected method for identifying line centers from user provided
%    points. Options are:
%     1: Cross Correlation with Gaussian Fit
%     2: FMinSearch with Gaussian Fit

function [ptsPixPosition, ptsId] = findLines (img,lnNames,y) 

    %% GUI Hendling

    %Draw image
   
    figure(21);
    subplot(1,1,1);
    imagesc(img);
    colormap gray;
if y==1
    %Ask user to mark lines by there order
    linePts = zeros(2,2,length(lnNames)); %(xy,StartEnd,line)
    linePs = zeros(2,length(lnNames));
    for i=1:length(lnNames)
        title(sprintf('Mark %s.\n Select the Center of the Line. Double Click To Finish',lnNames{i}));
        lns = getline();

        linePts(:,:,i) = lns(1:2,:);
        linePs(:,i) = polyfit(lns(:,2),lns(:,1),1); %Linear fit between 2 lines x as a function of (y)

        %Update Image
        imagesc(img);
        hold on;
        plot(squeeze(linePts(:,1,1:i)),squeeze(linePts(:,2,1:i)));
        hold off;
    end

    %% Find minimal distance between all lines
    minDist = Inf;
    for i=1:length(lnNames)
        for j=1:length(lnNames)
            if (i==j)
                continue;
            end
            %Compute x-distance assuming y is equal
            d = abs(squeeze(linePts(:,1,i))-polyval(linePs(:,j),linePts(:,2,i)));
            d = min(d);
            if (d<minDist)
                minDist = d;
            end
        end
    end
    delta = minDist/2*0.6; %What is the width 
    
    %Update Image
    subplot(2,1,1);
    imagesc(img);
    hold on;
    plot(squeeze(linePts(:,1,1:i)),squeeze(linePts(:,2,1:i)));
    plot(squeeze(linePts(:,1,1:i))-delta,squeeze(linePts(:,2,1:i)),'--k');
    plot(squeeze(linePts(:,1,1:i))+delta,squeeze(linePts(:,2,1:i)),'--k');
    hold off;
            
    %% Main Algorithm Loop for each line and fit 
    gaussian = @(a, x) a(1)-a(2).*exp(-((x-a(3)).^2)./(2.*a(4).^2));

    ptsPixPosition=[];
    ptsId=[];
    for i=1:length(lnNames)
        
        %For every points on the line
        for y=round(linePts(1,2,i)):round(linePts(2,2,i)) %ystart to yend
            xCenter = polyval(linePs(:,i),y);
            x = round(xCenter-delta):round(xCenter+delta);
            data = mean(img(y+(-5:5),x),1); %Get data required for fitting
            
            a = [max(data),max(data)-min(data),xCenter,delta/2];
            a = fminsearch(@(a)(sum(( data - gaussian(a,x) ).^2)),a);
            
            if false
                subplot(2,1,2);
                plot(x,data,x,gaussian(a,x));
                grid on;
                legend('Data','Gaussian Fit');   
                pause(0.01);
            end
                
            %Save Result
            ptsPixPosition(end+1,:) = [a(3) y];
            ptsId(end+1) = i;
        end
    end
    ptsId = ptsId(:);
    
    %% Update With Final Lines
    subplot(2,1,2);
    imagesc(img);
    hold on;
    for i = 1:length(lnNames)
        plot(ptsPixPosition(ptsId==i,1),ptsPixPosition(ptsId==i,2),'o');
    end
    hold off
else
    %Ask user to mark lines by there order
   
    for i=1:length(lnNames)
        title(sprintf('Mark %s.\n Select 10 points on the center of the line. Double Click To Finish',lnNames{i}));
        lns = getline();
        ptsPixPosition((1+(i-1)*length(lns(:,1))):(i*length(lns(:,1))),1:2) = lns;
        lineLf = polyval(polyfit(lns(:,1),lns(:,2),1),lns(:,1));   %Linear fit pf the poitns marked x as a function of (y)
        %Update Image
        hold on;
        scatter(lns(:,1),lns(:,2))
        plot(lns(:,1),lineLf);
        hold off;
        ptsId((1+(i-1)*length(lns(:,1))):(i*length(lns(:,1))),1) = i; 
        clear lns;
    end 
end
end