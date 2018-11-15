%Simulation of Photobleaching and Alignment Algorithm
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Allows user to specify:
%   - choice of horizontal and vertical hashtag lines specified by intercept point
%   - a slicing plane determined by vectors u, v, h
%   - a sample plane representing the surface of the sample determined by normal vector s and a point p
% 
%   - a photobleaching beam specified by a focal depth z0 and beam width w0 and wavelength lambda
%
%Returns: 
%   - actual parameters of Pixel Size, Angle in X-Y Plane and Intercept Points
%   - algorithm predicted Pixel Size, Angle in X-Y Plane and Intercept Points
%Example:
%   Let us assume 4 lines in the image:
%       n1,n2 parallel to y axis positioned in x=-50microns, x=+50 microns
%       n3,n4 parallel to x axis positioned in y=-50microns, y=+50 microns
% - The user will be asked to mark the edges of the lines (will appear as red lines)
% - The algorithm will compute the estimate of the location of the line (will appear as a green line)
%

close all;
clear;


count = 0;
while(1)
    count = count + 1;
    %% Inputs - hashtag lines
    OCTVolumePosition = [-1e-3 -1e-3     0; ... %x,y,z position [m] of the first A scan in the first B scan (1,1)
                         +1e-3 +1e-3  0.968e-6*2040]';     %x,y,z position [m] of the las A scan in the last B scan (end,end). z is deeper!
    lnDist = 1e-6*[-50  +50  -100    0  +50]; %Line distance from origin [m]
    lnDir  =      [  0    0    1    1    1]; %Line direction 0 - left right, 1 - up down
    lnNames=    { '-x' '+x' '-y' '0y' '+y'}; %Line names

    %% Inputs - slicing plane - uv plane
    NPixU = 512; %Number of pixels in each direction
    NPixV = 512;

    % u, v must be chosen to be orthogonal, and equal in norm
    imgPixU = 2e-6; imgPixV = 2e-6;
    u = [2; -2; 0]; u = u/norm(u)*imgPixU;
    v = [2e-2;  2e-2; 1]; v = v/norm(v)*imgPixV;
    h = [-0.2e-3 0.4e-3 0];

    % set limits to prevent /0 error
    u(u==0) = 1e-12;
    v(v==0) = 1e-12;


    %% Inputs - sample plane
    % Equation of plane is given by s1(x-p1) + s2(y-p2) + s3(z-p3) = 0,
    % where (s1,s2,s3) is the normal vector and (p1,p2,p3) is the origin
    % of the plane
    s = [0;0.2;1]; p = [0;0;0.5e-3]; 
    % equation of intersection of sample plane and uv plane in uv coordinates
    % m1 *c1 + m2*c2 = -b
    m2 = (s(1)*v(1) + s(2)*v(2) + s(3)*v(3)); 
    m1 = (s(1)*u(1)+ s(2)*u(2) + s(3)*u(3));
    b = -(s(1)*(p(1) - h(1)) + s(2)*(p(2) - h(2)) + s(3)*(p(3) - h(3)));
    [C1_mesh,C2_mesh] = meshgrid([1:NPixU],[1:NPixV]);
    % create mask to delineate sample surface
    sample_mask = zeros(NPixV,NPixU);
    sample_mask((C1_mesh*m1 + C2_mesh*m2 +b) <0) = 1;
    % create exponential fall-off
    falloff = 100e-6; %[um]
    sample_exp = exp(-1/falloff*sqrt((m1*m2*C1_mesh+m2*b+m2*m2*C2_mesh).^2+(m1*m2*C2_mesh+m1*b+m1*m1*C1_mesh).^2)/sqrt(m1^2+m2^2));
    
       
    %% Create photobleached lines
    % units of parameters in meters
    E0 =1;
    w0 =5e-6;
    lambda = 0.8e-6;
    z0 = 400e-6; %height of photobleach focus position
    t = 1;
    img = gaussian_pb(E0, w0, lambda, t, z0, u, v, h, lnDist, lnDir);

    %% Further Processing - add noise to image amd mask and flip image
    img_ = imnoise(img,'gaussian',0.1);
    img_ = imnoise(uint8(img_*255*0.9),'poisson');
    slice_masked = flipud(double(img_)/255 .* sample_mask .* sample_exp); 
    %slice_masked = flipud(img_ .* sample_mask); 
    %figure; imagesc(slice_masked); colormap(gray)

    %% Solve for intercepts in sample plane
    % y-intercept
    % from equation c1 * ux + c2 * vx = x-hx and m1 *c1 + m2*c2 = -b
    y_mat = [m1, m2 ; u(1), v(1)];
    y_int_uv = y_mat^-1 * [-b; -h(1)];
    y_int = h(2) + y_int_uv(1) * u(2) + y_int_uv(2) * v(2);
    % x-intercept
    % from equation c1 * uy + c2 * vy = x-hy and m1 *c1 + m2*c2 = -b
    x_mat = [m1, m2 ; u(2), v(2)];
    x_int_uv = x_mat^-1 * [-b; -h(2)];
    x_int = h(1) + x_int_uv(1) * u(1) + x_int_uv(2) * v(1);

    %% Print Actual Slice Measurements
    %fprintf('Actual Pixel Size: |u|=%.3f[microns], |v|=%.3f[microns]\n',1e6*imgPixU,1e6*imgPixV)
    %fprintf('Actual Angle In X-Y Plane: %.2f[deg], Tilt: %.2f[deg]\n',atan2(u(2),u(1))*180/pi,acos(dot(v/norm(v),[0;0;1]))*180/pi);
    %fprintf('Actual Intercept Points. x=%.3f[mm],y=%.3f[mm]\n',1e3*x_int,1e3*y_int);
    %fprintf('\n');

    %% Run Hashtage Alignment Algorithm
    [ptsPixPosition, ptsId, lnLen] = findLines (slice_masked,lnNames);
    close all
    %Find position and direction by line identity
    ptsLnDist = lnDist(ptsId); ptsLnDist = ptsLnDist(:);
    ptsLnDir  = lnDir(ptsId);  ptsLnDir  = ptsLnDir(:);

    %Compute plane parameters
    [u_out,v_out,h_out] = identifiedPointsToUVH (ptsPixPosition,ptsLnDist, ptsLnDir);

    % Compute intercepts
    V_out = mean(ptsPixPosition(:,2)); %Take average image height
    UX_out=-(h_out(2)+V_out*v_out(2))/u_out(2);
    X_out=u_out(1)*UX_out+v_out(1)*V_out+h_out(1);
    UY_out=-(h_out(1)+V_out*v_out(1))/u_out(1);
    Y_out=u_out(2)*UY_out+v_out(2)*V_out+h_out(2);

    %fprintf('Algorithm Pixel Size: |u|=%.3f[microns], |v|=%.3f[microns]\n',norm(u_out)*1e6,norm(v_out)*1e6)
    %fprintf('Algorithm Actual Angle In X-Y Plane: %.2f[deg], Tilt: %.2f[deg]\n',atan2(u_out(2),u_out(1))*180/pi,acos(dot(v_out/norm(v_out),[0;0;1]))*180/pi);
    %fprintf('Algorithm Intercept Points. x=%.3f[mm],y=%.3f[mm]\n',1e3*X_out,1e3*Y_out);
    %fprintf('Average Line: %.3f[um] with %.3f points\n',2*mean(lnLen),size(ptsId,1)/5); %lnLen 2 um * lnLen
    
    length(count) = 2*mean(lnLen);
    error(count) = abs(acos(dot(v/norm(v),[0;0;1]))*180/pi-acos(dot(v_out/norm(v_out),[0;0;1]))*180/pi);
    
end

figure; scatter(length,error)
xlim([10 435])
ylim([0 2.6])