slide_ = imrotate(-double(slide)+256,13);

%slide_ = -double(slice_masked_)+256,-13;
bckgrndimg = flipud(sample_mask .*sample_exp);
bckgrnd = slice_masked/max(max(slice_masked))*0.8*255;

bckgrnd = mean(mean(slide_(130:165,321:331),1),2);
slide__ = slide_-bckgrnd;
slide__(slide__<1) =1;

signal = slide__(101:180,260:440);
figure; plot(mean(slide__(135,:),1))
figure; imagesc(signal)
for x=1:size(signal,2)
   signal_(:,x) = movmean(signal(:,x),10);
end
figure; imagesc(signal_)
figure; plot(signal_(27,:))

snr_std=sqrt(var(signal_(27,18:30)));