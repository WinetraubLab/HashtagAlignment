function PhotobleachTickmarks_Thorlabs(x0s,y0s,vLinePositions,hLinePositions,folderToSaveFigure)
%This function phtobleaches tick markers intercepting at x0, y0. [mm]
%x0s and y0s can be an array with multiple ticklines
%Please provide vLinePositions,hLinePositions to avoid interceting with
%Hashtag
%folderToSaveFigure - optional, which folder to save figure to

if ~exist('folderToSaveFigure','var')
    folderToSaveFigure = '.\';
end

%% Configuration
gap = 0.1; %[mm]
tick_length = 0.3; %[mm]

exposurePerLine = 30/2 * 0.3; %[sec]
passes = 2; 

makefig = true;

line1starts = cell(size(x0s));
line1ends = cell(size(x0s));
line2starts = cell(size(x0s));
line2ends = cell(size(x0s));
innerpts1s = cell(size(x0s));
innerpts2s = cell(size(x0s));
for i=1:length(x0s)
    x0 = x0s(i);
    y0 = y0s(i);
    %% Compute start and end positions for tick mark
    slope = -y0/x0;
    tickline_x = @(y) (x0 + y/slope);
    tickline_y = @(x) (slope*(x-x0));
    deltax_given_length = @(l) l/sqrt(1+(y0/x0)^2);
    deltay_given_length = @(l) l/sqrt(1+(x0/y0)^2);

    if (x0>0 && y0>0)
        innerpts1 = [hLinePositions(1) tickline_y(hLinePositions(1))];
        innerpts2 = [tickline_x(vLinePositions(1)) vLinePositions(1)];
        s = [-1, 1]; % sign of shift in (x,y) of 1st line due to gap

    elseif (x0>0 && y0<0)
        innerpts1 = [hLinePositions(1) tickline_y(hLinePositions(1))];
        innerpts2 = [tickline_x(vLinePositions(3)) vLinePositions(3)];
        s = [-1, -1]; % sign of shift in (x,y) of 1st line due to gap

    elseif (x0<0 && y0>0)
        innerpts1 = [tickline_x(vLinePositions(1)) vLinePositions(1)];
        innerpts2 = [hLinePositions(3) tickline_y(hLinePositions(3))];
        s = [-1, -1]; % sign of shift in (x,y) of 1st line due to gap

    elseif (x0<0 && y0<0)
        innerpts1 = [tickline_x(vLinePositions(3)) vLinePositions(3)];
        innerpts2 = [hLinePositions(3) tickline_y(hLinePositions(3))];
        s = [-1, 1]; % sign of shift in (x,y) of 1st line due to gap

    end

    line1start = innerpts1 + s .* [deltax_given_length(tick_length+gap) , deltay_given_length(tick_length+gap)];
    line1end = innerpts1 + s .* [deltax_given_length(gap) , deltay_given_length(gap)];

    line2start = innerpts2 - s .* [deltax_given_length(tick_length+gap) , deltay_given_length(tick_length+gap)];
    line2end = innerpts2 - s .* [deltax_given_length(gap) , deltay_given_length(gap)];

    %% Perform Photobleaching
     ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
            line1start(1),line1start(2), ... Start X,Y
            line1end(1),line1end(2), ... End X,Y
            exposurePerLine,passes); 


     ThorlabsImagerNET.ThorlabsImager.yOCTPhotobleachLine( ...
            line2start(1),line2start(2), ... Start X,Y
            line2end(1),line2end(2), ... End X,Y
            exposurePerLine,passes); 
        
    %% Save
    line1starts{i} = line1start;
    line1ends{i} = line1end;
    line2starts{i} = line2start;
    line2ends{i} = line2end;
    innerpts1s{i} = innerpts1;
    innerpts2s{i} = innerpts2;
end

%% Plot what we did
if makefig == true
    photobleach_length = 2;
    figure; hold on;

    %Draw Lines V lines
    for k=1:length(vLinePositions)
        hPos = [...
            -photobleach_length/2 +photobleach_length/2; ... x
            vLinePositions(k) vLinePositions(k); ... y
            ];
        hPos = hPos; %Rotate, [mm]

        plot(hPos(1,:), hPos(2,:),'Color','r','LineWidth',2); %[x1,x2], [y1,y2]
    end

    %Draw Lines H lines
    for k=1:length(hLinePositions)
         vPos = [...
            hLinePositions(k) hLinePositions(k); ... x
            -photobleach_length/2 +photobleach_length/2; ... y
            ];
        vPos = vPos; %Rotate, [mm]i

        plot(vPos(1,:), vPos(2,:),'Color','r','LineWidth',1); %[x1,x2], [y1,y2]
    end

    %Draw ticks
    for i=1:length(line1starts)
        line1start = line1starts{i};
        line1end = line1ends{i};
        line2start = line2starts{i};
        line2end = line2ends{i};
        innerpts1 = innerpts1s{i};
        innerpts2 = innerpts2s{i};
        plot([line1start(1),line1end(1)],[line1start(2),line1end(2)])
        plot([line2start(1),line2end(1)],[line2start(2),line2end(2)])
        plot([innerpts1(1),innerpts2(1)],[innerpts1(2),innerpts2(2)])
        
        scatter(innerpts1(1),innerpts1(2),50,'filled')
        scatter(innerpts2(1),innerpts2(2),50,'filled')
    end    
    
    saveas(gcf,[folderToSaveFigure 'PhotobleachedLinesOverview.png']);
end
