function img = imReColor(img, oldColor, newColor)
% Change one color in image to a new one. works on RGB colors

if (size(img,3) == 3)
    r = img(:,:,1);
    g = img(:,:,2); 
    b = img(:,:,3);
elseif (size(img,3) == 1) %Gray scale
    r = img(:,:,1);
    g = r;
    b = r;
else
    error('Don''t know what to do here');
end

mask = r == oldColor(1) & g == oldColor(2) & b == oldColor(3);

r(mask) = newColor(1);
g(mask) = newColor(2);
b(mask) = newColor(3);

img(:,:,1) = r;
img(:,:,2) = g;
img(:,:,3) = b;