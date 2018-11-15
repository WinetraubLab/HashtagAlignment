%This is used for manually selecting features in the OCT and histology
%images.  It is to be run after 'script1.m'
%% get points in histology
% click once to select points, hit 'enter' when finished

n=20;
figure; imagesc(histologyImage)
[x,y] = ginput(n)
hold on;
for i = 1:length(x)
    scatter(x,y, 'r')
end

pts_hist(:,1) = x;
pts_hist(:,2) = y;
%save('pts_hist_10_2.mat','pts_hist')
%% get points in rOCT
% draw squares around features of interest, close figure window when
% finished
figure; imagesc(mean(rOCT,3))
%[x,y] = ginput(n)

%h=imrect
index = 1;

while(1)
    
    h=imrect
    position=h.getPosition;

    xmin = round(position(1));
    ymin = round(position(2));
    width = round(position(3));
    height = round(position(4));

    %figure; imagesc(rOCT(ymin:ymin+height,xmin:xmin+width,15))

    %figure; plot(squeeze(mean(mean(rOCT(ymin:ymin+height,xmin:xmin+width,:),1),2)))
    zplot = squeeze(mean(mean(rOCT(ymin:ymin+height,xmin:xmin+width,:),1),2));
    [~,ind] = max(zplot);
    crop = rOCT(ymin:ymin+height,xmin:xmin+width,ind);

    props = regionprops(crop>prctile(crop(:),98), crop, 'WeightedCentroid');
    centroids = props.WeightedCentroid;
    x_crop = round(centroids(1));
    y_crop = round(centroids(2));

    x_c = x_crop + xmin - 1;
    y_c = y_crop + ymin - 1;
    z_c = ind;
    
    point_centers(index,1) = x_c;
    point_centers(index,2) = y_c;
    point_centers(index,3) = z_c;
    
    index = index + 1;
end

% Plot Selected Features
figure; imagesc(mean(rOCT,3)); hold on
for i = 1:size(point_centers,1)
    hold on
    scatter(point_centers(i,1),point_centers(i,2))
end