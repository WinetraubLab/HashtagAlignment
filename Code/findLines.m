function [ptsPixPosition, ptsId] = findLines (img,lnNames)


imagesc(img);
resp= 'Y';
j=1;

while 1
    if strcmpi(resp,'N')
        break;
    end
 if mod(j, 2) == 0
       x_av=mean(Points_temp_x(:,j-1:j),2);
       y_av=mean(Points_temp_y(:,j-1:j),2);
   for i=1:length(Points_temp_x(:,j))
       dis=round(abs(Points_temp_x(i,j)-Points_temp_x(i,j-1)));
       intensity=mean(img(((round(y_av(i))-10):(round(y_av(i))+10)),((round(x_av(i))-2*dis):(round(x_av(i))+2*dis))));
       intensity=(intensity - min(intensity )) / ( max(intensity ) - min(intensity ) );
       var = maxGausVar(intensity,dis);
       Gaus= -1*gausswin([4*dis +1],var);
       Gaus=(Gaus - min(Gaus)) / ( max(Gaus) - min(Gaus) );
       [acor,lag] = xcorr(intensity,Gaus);
       [~,I] = max(abs(acor));
       lagDiff = lag(I);
       x_estimate(i)= x_av(i)-lagDiff+1;
   end
    x_estimate=x_estimate';
    p=polyfit(x_estimate,y_av,1);
    hold on;
    plot(x_estimate,p(1)*x_estimate+p(2),'g');
    ptsPixPosition_x(:,j/2)=[x_estimate];
    ptsPixPosition_y(:,j/2)=[p(1)*x_estimate+p(2)];
    ptsId(:,j/2)=repmat([j/2],[11,1]);
    j=j+1;
    resp = inputdlg('Do you wish to continue to mark lines? Y/N: ','s');
    clear x1; clear y1; clear x2; clear y2; clear Nx1; clear Ny1; clear Nx2; clear Ny2; 
    clear x_av; clear y_av; clear dis; clear intensity; clear gaus; clear acor; clear lag;
    clear I; clear lagDiff; clear x_estimate; clear p;
 else
     title(['Mark ' lnNames{round(j/2)} ' Left Side of the line. double click to finish']);
     [x1,y1] = getline;
     Nx1=length(x1);
     Ny1=length(y1);
     hold on
     plot(x1,y1,'r')
     [x2,y2] = getline;
     Nx2=length(x2);
     Ny2=length(y2);
     hold on
     plot(x2,y2,'r')
     j=j+1;
     Points_temp_x(:,j-1)=interp1([0:1:Nx1-1],x1,[0:(Nx1-1)/10:Nx1-1],'spline');
     Points_temp_y(:,j-1)=interp1([0:1:Ny1-1],y1,[0:(Ny1-1)/10:Ny1-1],'spline');
     Points_temp_x(:,j)=interp1([0:1:Nx2-1],x2,[0:(Nx2-1)/10:Nx2-1],'spline');
     Points_temp_y(:,j)=interp1([0:1:Ny2-1],y2,[0:(Ny2-1)/10:Ny2-1],'spline');
  end
end
ptsPixPosition=[ptsPixPosition_x(:) ptsPixPosition_y(:)];
ptsId=ptsId(:);
end
