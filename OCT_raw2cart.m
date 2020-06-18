function [OCT, OCT_cart2] = OCT_raw2cart(output_size)

% this function takes a raw OCT pullback and converts it to a cartesian
% pullback

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