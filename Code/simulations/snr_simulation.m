%slide_ = imrotate(-double(slide)+256,13);

%slide_ = -double(slice_masked_)+256,-13;
bckgrndimg = flipud(sample_mask .*sample_exp);
bckgrnd = bckgrndimg/max(max(bckgrndimg))*0.8*255;
slide__ = double(slice_masked_)-bckgrnd;

%bckgrnd = mean(mean(slide_(130:165,321:331),1),2);
%slide__ = slide_-bckgrnd;
slide__ = -slide__;
slide__(slide__<1) =1;

signal = slide__(284:330,81:383);
figure; plot(mean(slide__(135,:),1))
figure; imagesc(signal)
for x=1:size(signal,2)
   signal_(:,x) = movmean(signal(:,x),10);
end
figure; imagesc(signal_)
figure; plot(signal_(10,:))

line1 = mean(signal_(:,20:23),2); noise1 = sqrt(var(signal_(:,32:52),0,2));
line2 = mean(signal_(:,132:135),2); noise2 = sqrt(var(signal_(:,141:162),0,2));
line3 = mean(signal_(:,188:191),2); noise3 = sqrt(var(signal_(:,196:216),0,2));
line4 = mean(signal_(:,231:234),2); noise4 = sqrt(var(signal_(:,238:258),0,2));
line5 = mean(signal_(:,287:290),2); noise5 = sqrt(var(signal_(:,295:303),0,2));

figure; plot(line1./noise1)
hold on; plot(line2./noise2)
hold on; plot(line3./noise3)
hold on; plot(line4./noise4)
hold on; plot(line5./noise5)
legend('ln1','ln2','ln3','ln4','ln5')

snr_std=sqrt(var(signal_(10,40:118)));