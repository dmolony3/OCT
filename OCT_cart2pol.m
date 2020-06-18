function [OCT_polar, OCT_cart] = OCT_raw2cart()

% this function takes a dicom OCT pullback and converts it to a polar
% pullback

% read multipage tiff
[FILENAME PATHNAME] = uigetfile('*.dcm');
sprintf(FILENAME)

OCT_cart = dicomread(fullfile(PATHNAME, FILENAME));
OCT_cart = squeeze(OCT_cart);

% determine image information
info = dicominfo(fullfile(PATHNAME, FILENAME));
image_size = size(OCT_cart);

cx = image_size(1)/2;
cy = image_size(2)/2;
num_images = image_size(end);

rows = 540;
cols = 960;
OCT_polar = zeros(rows, cols, num_images);

for i = 1:num_images
    polar_image = polartrans(OCT_cart(:,:,i), cols, rows, cx, cy, 'linear', 'valid');
    % flip images and rotate by 180 degrees in order to align corretly
    OCT_polar(:, :, i) = flipud(circshift(polar_image', rows));
end