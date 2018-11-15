conim = imread('C:\MATLAB_Share\Edwin\2018-8-1 wires in gel\data 8-2\hash2_0p4_0p3\confocal data\Experiment_Image032_ch00.tif');
conim1 = imrotate(conim,-3.5);

count=0;
for i=154:206
    count=count+1;
    roi = conim1(i,220:320);
    avg(i) = mean(roi);
    variance(i) = var(double(roi));
end

figure; plot(avg); hold on; plot(variance)
figure; histogram(conim1(170,220:320))