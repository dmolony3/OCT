function [OCT OCT_cart2] = OCT_raw2cart(output_size)

% this function takes a raw OCT pullback and converts it to a cartesian
% pullback

% [FILENAME PATHNAME] = uigetfile('*.oct');
% OCT=importdata('C:\Gatech\Neb29\{9B341B61-B726-41F2-9E4E-E881EB97E9DB}.oct');

% read multipage tiff
[FILENAME PATHNAME] = uigetfile('*.tif');
sprintf(FILENAME)
% determine image information
info = imfinfo(strcat(PATHNAME, FILENAME));
num_images = numel(info);


% pre-allocate memory (read first file to determine correct size)
OCT = imread(strcat(PATHNAME, FILENAME), 1, 'Info', info);
OCT = uint16(ones(length(OCT(:,1)), length(OCT(1, :)), num_images));

for i = 1:num_images
    OCT(: ,:, i) = imread(strcat(PATHNAME, FILENAME), i, 'Info', info);
end

if nargin == 1
    OCT_log = ones(size(OCT));
    OCT_cart2 = ones(output_size, output_size, num_images);
    % apply logarithmic compression
    for i = 1:num_images
        c(i) = 255/(log10(1 + double(abs(max(max(OCT(:, :, i)))))));
        OCT_log(:, :, i) = c(i).*log10(double(abs(OCT(:, :, i))));
        
        % convert to cartesian
        OCT_cart = Polar2Im(double(OCT_log(:, :, i)'), output_size, 'linear');
        
        % to display as same format as St. Jude rotate by 90 and fliplr
        OCT_cart2(:, :, i) = imrotate(OCT_cart,90);
        OCT_cart2(:, :, i) = fliplr(OCT_cart2(:, :, i));
    end
end
% % transpose OCT iimage so that rows represent depth
% OCT_image=OCT(:,:,i)';
% 
% % create cartesian and polar grids
% THETA = linspace(1, 360, length(OCT_image(1, :)));
% THETA = repmat(THETA, length(OCT_image(:, 1)), 1);
% % assuming outer sheath is 1mm create 9.4e-6 (applies for 10x10mm
% % cartesian(catheter dia = 0.9024mm)
% % also, while 7x7mm cartesian has 6.9e-6 resolution (catheter dia=0.93mm). 
% 
% pixel_size = 9.4e-6;
% RAD = repmat((1:length(OCT_image(1, :)))'.*pixel_size, 1, length(OCT_image(1, :)));
% 
% % set image limit based on the pixel size and image size
% image_limit = 2*max(max(RAD));
% 
% % determine pixel size for a 1024x1024 image
% pixel_size2 = image_limit/output_size;
% 
% % create a 1024x1024 cartesian grid with polar coordinates
% [x y] = meshgrid(1:1024, 1:1024);
% x = x.*pixel_size2;
% y = y.*pixel_size2;
% 
% % convert original polar to cartesian
% [X Y] =pol2cart(deg2rad(THETA), RAD);
% cx = (output_size/2)*pixel_size2;
% cy = (output_size/2)*pixel_size2;
% X = RAD.*cosd(THETA) + cx;
% Y = RAD.*sind(THETA) + cy;
% 
% OCT_cart = interp2(X, Y, double(OCT(:,:,1)), x, y);
% 
% % convert cartesian to polar 
% [theta_new rad_new] = cart2pol(x - (length(x)/2)*pixel_size, y - (length(y)/2)*pixel_size);
% 
% rad_new = rad_new - max(max(rad_new))/2;
% % convert from polar to degrees
% theta_new = rad2deg(theta_new);
% theta_new(theta_new < 0) = theta_new(theta_new < 0) + 360;
% 
% OCT_cart = interp2(THETA, RAD, double(OCT(:,:,1)), theta_new, rad_new);
% 
% imR = PolarToIm (double(OCT(:,:,i)'), 0, 1, 1024, 1024);
% 
