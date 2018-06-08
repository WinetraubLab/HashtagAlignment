function [var] = maxGausVar (intensity,dis)
% Use to find the gaussian variance that will yield maximum cross correllation between the intensity and a gaussian.  
%USAGE:
%   [var] = findLines (intensity,dis)
%INPUTS:
%   intensity - 1D vector that contain the image  normalize intensity at a
%   specific Y location.
%   Dis- (scalar) the distance between the two edegs of the line in a specific Y location 
%  
%OUTPUTs
%   Var - The gaussian variance that yield the maximum cross correllation   
      for i = 1:1:20
       Gaus= -1*gausswin([6*dis +1],i);
       Gaus=(Gaus - min(Gaus)) / ( max(Gaus) - min(Gaus) );
       [acor,lag] = xcorr(intensity,Gaus);
       [val,~] = max(abs(acor));
       MaxAcor(i)=val;
      end
      [val ind]=max(MaxAcor);
      var=ind;
end