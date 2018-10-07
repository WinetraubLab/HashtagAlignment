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

function [ptsPixPosition, ptsId, lnLen] = findLines (img,lnNames,linePts0,linePs, lnlength) 
    linePts = linePts0;
    %% GUI Hendling
%     i=3;
%     %figure; imagesc(img); colormap(gray)
%     %figure; plot(xCenter,y);axis ij
%     y=round(linePts(1,2,i)):round(linePts(2,2,i));
%     xCenter = polyval(linePs(:,i),y);
%     y=round(linePts(1,2,i)):round(linePts(2,2,i));
%     
%     %jitter initial point
%     linePts(1,2,i) = round(linePts0(1,2,i) + (rand-0.5)*4); %ydirection
%     linePts(1,1,i) = round(linePts0(1,1,i) + (rand-0.5)*2); %xdirection
%     
%     angle = atan(linePs(1,i))*180/pi*( 1 + (rand)*0.6);
%     newy = round(linePts(1,2,i)+ lnlength * cos(angle*pi/180));
%     newx = round(linePts(1,1,i)+ lnlength * sin(angle*pi/180));
%     
%     %hold on; plot([linePts(1,1,i),newx],[linePts(1,2,i),newy],'LineWidth',2)
    
    %figure;
    for i=1:length(lnNames)
        
        %% jitter lines
        %jitter initial point
        linePts(1,2,i) = round(linePts0(1,2,i) + (rand-0.5)*4); %ydirection
        linePts(1,1,i) = round(linePts0(1,1,i) + (rand-0.5)*2); %xdirection
    
        angle = atan(linePs(1,i))*180/pi*( 1 + (rand)*0.6);
        newy = round(linePts(1,2,i)+ lnlength/2 * cos(angle*pi/180));
        newx = round(linePts(1,1,i)+ lnlength/2 * sin(angle*pi/180));
    
        linePts(2,2,i) =newy;
        linePts(2,1,i) =newx;
        %% same as before
        linePs(:,i) = polyfit(linePts(:,2,i),linePts(:,1,i),1); %Linear fit between 2 lines x as a function of (y)

        %Update Image
        %imagesc(img);
        %hold on;
        %plot(squeeze(linePts(:,1,1:i)),squeeze(linePts(:,2,1:i)));
        %hold off;
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
            
    %% Main Algorithm Loop for each line and fit 
    gaussian = @(a, x) a(1)-a(2).*exp(-((x-a(3)).^2)./(2.*a(4).^2));

    ptsPixPosition=[];
    ptsId=[];
    for i=1:length(lnNames)
        
        %For every points on the line
        for y=round(linePts(1,2,i)):round(linePts(2,2,i)) %ystart to yend
            xCenter = polyval(linePs(:,i),y);
            x = round(xCenter-delta):round(xCenter+delta); x(x>size(img,2)) = [];  x(x<1) = [];
            data = mean(img(y+(-5:5),x),1); %Get data required for fitting
            
            options = optimset('TolFun',1e-5,'MaxIter',5e3,'TolX',1e-5);
            a = [max(data),max(data)-min(data),xCenter,delta/2];
            a = LMFnlsq(@(a) [data - gaussian(a,x) ]',a);
              
            %figure; plot(x,data); hold on; plot(x,gaussian(a,x))
            
            % discard bad fits
            if abs(a(3) - xCenter) > delta/2 && y>200
                a(3) = xCenter;
            end
            
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
    
    %% Calculate Line Distances
    lnLen = zeros(size(linePts,3),1);
    for k = 1:size(linePts,3)
        lnLen(k) = sqrt(sum((linePts(1,:,k)-linePts(2,:,k)).^2));
    end
    
end