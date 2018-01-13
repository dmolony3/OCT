function OCT_contour_cart = contour2cart(OPTIMAL_PATH, OCT_polar, output_size, rotate)

% this function turns a contour from the polar coordinate system into a
% contour in the cartesian system, the input optimal path is a mxn matrix
% where rows correspond to depth and columns to different images
OCT_contour_cart = cell(1, length(OPTIMAL_PATH(1, :)));
for i = 1:length(OPTIMAL_PATH(1, :))
    OCT_contour = round(OPTIMAL_PATH(:, i));
    
    if length(OCT_contour(:, 1)) ~= length(OCT_polar(:, 1, 1))
        warning('assuming guidewire shadow present and adding points to contour')
        no_points = length(OCT_polar(:, 1, 1)) - length(OCT_contour(:, 1));
        OCT_contour(end + 1:end + no_points, :) = OCT_contour(end);
%         error('the no. of points in the contour does not agree with the image')
    end
        
    % create a binary image for each contour
    OCT_binary = zeros(size(OCT_polar(: ,:, 1)));
    for j = 1:length(OCT_binary(:, 1, 1))
        OCT_binary(j, 1:OCT_contour(j)) = 1;
    end
     % input to Polar2Im must have the depth on the y axis
    OCT_contour_image = Polar2Im(double(OCT_binary'), output_size, 'linear');
    % convert to actual binary 
    OCT_contour_image = im2bw(OCT_contour_image, 0);
    % rotate and flip to correct orientation
    if rotate == 1
    OCT_contour_image = imrotate(OCT_contour_image, 90);
    end
%     OCT_contour_image(:, :, i) = fliplr(OCT_contour_image(: ,:, i));

    % determine contour from binary edges
    OCT_contours = bwboundaries(OCT_contour_image);
    [OCT_contour_cart{i}] = OCT_contours{1};
%     hold on, plot(OCT_contour_cart{i}{1}(:, 2), OCT_contour_cart{i}{1}(:, 1), 'r')
end