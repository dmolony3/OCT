function contour_path_final = OCT_threshold(OCT_gw, OCT_sheath, include_struts)

% this function thresholds an OCT image and returns the lumen contour,
% thresholding is performed on the polar image.

contour_path_final = zeros(length(OCT_gw(:,1,1)), 1);
struts = zeros(size(OCT_gw));

for i = 1:length(OCT_gw(1,1,:))
    % set values inside the sheath to 0
    for j = 1:length(OCT_sheath(:, 1))
        OCT_gw(j, 1:OCT_sheath(j, i), i) = 0;
    end
    OCT_gw(:, :, i) = medfilt2(OCT_gw(:, :, i), [5 5]);
    
    % set threshold based on whether images are uint8 or uint16
    if max(OCT_gw(:)) <= 255
        threshold = 100;
    else
        threshold = 100;
    end
    
    % convert to binary image
    bin = imbinarize(double(OCT_gw(:,:,i)), threshold);
    
    % remove small islands
    bin = bwareaopen(bin, 25);
    
    % remove 4 connected pixels
    se = strel('disk',4);
    bin = imclose(bin,se);

    % fill image and remove larger islands
    bin = imfill(bin, 'holes');    
    bin = bwareaopen(bin, 250);
    
    if include_struts == 1
        % edit image based on whether struts should be included or excluded
        image_max = max(OCT_gw(:,:,i),[], 2);
        image_max(image_max == 0) = median(image_max);
        image_max_normalized = image_max./max(image_max);

        image_mean = mean(OCT_gw(:,:,i), 2);
        image_mean(image_mean == 0) = median(image_mean);
        image_mean_normalized = image_mean./max(image_mean);

        image_mean_max = (1./image_mean_normalized) + image_max_normalized;
        idx = find(image_mean_max > median(image_mean_max)+0.5);
        bin(idx, :) = 0;
        struts(idx ,i) = 1;
    end
    
%     
%     % remove small islands
%     % get properties of each binary component
%     labeledImage = bwlabel(bin);
%     blobMeasurements = regionprops(labeledImage, 'area', 'Centroid');
%     allAreas = [blobMeasurements.Area];
%     
%     % keep only regions grater than 1000 pixels
%     blobkeep = allAreas > 1000;
%     binary_image(:, :, i) = ismember(labeledImage, find(blobkeep));
% 
%     % keep only the first pixel in each row (corresponds to lumen)
%     isOne = binary_image(:, :, i) == 1 ;
%     bin_contour = isOne & cumsum(isOne,2) == 1;

    labeledImage = bwlabel(bin);

    % find label closest to right side of image
    idx = arrayfun(@(x)find(labeledImage(x,:),1,'last'),1:size(labeledImage,1),  'UniformOutput', 0);
    row_idx = find(cellfun(@isempty, idx)==0);
    idx = cell2mat(idx);

    idx = sub2ind(size(labeledImage), row_idx, idx);
    labels = unique(labeledImage(idx));

    labeledImage = ismember(labeledImage, labels);
    bin_contour = labeledImage & cumsum(labeledImage,2) == 1;

    % get index of lumen
    contour_path = find(bin_contour);
    [r c] = ind2sub(size(bin_contour), contour_path);
    contour_sorted = sortrows([r,c]);
    
    % make contour periodic
    contour_path = [[contour_sorted(:,1);contour_sorted(:,1) + length(bin_contour(:, 1)); ...
        contour_sorted(:, 1) + length(bin_contour(:, 1))*2], ...
        [contour_sorted(:, 2); contour_sorted(:, 2); contour_sorted(:, 2)]];

    % create continuous contour by interpolating missing regions
    contour_path_interp = interp1(contour_path(:, 1), contour_path(:, 2), 1:length(bin_contour(:, 1))*3, 'pchip');
    contour_path_final(:, i) = contour_path_interp(length(bin_contour(:, 1, 1)) + 1:length(bin_contour(:, 1, 1))*2);
end