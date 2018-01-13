function OCT_cath = OCT_img_cath(OCT_polar, img_cath_threshold)

% this function detects the OCT imaging catheter in polar coordinates and
% returns the masked OCT pullback, based on the paper by Ancong Wang et al., 

% this is the threshold at which the summed image is considered as part of
% the catheter, large values excludes more intensities, ranges from 0 to 1
if nargin == 1
    img_cath_threshold = 0.25;
end

% detect the minimum image over the image set through each column
min_image = min(OCT_polar, [],3);

% compute sums over the columns
min_image_sum = sum(min_image);

% determine global maxima
global_max = max(min_image_sum);
% global_mean = mean(min_image);

% determine where the summed min image falls below 50% of the max
img_cath = min_image_sum > img_cath_threshold*global_max;

% detect the first bunch of positive values as a second bunch will
% correspond to the guidewire artifact
img_cath = find(img_cath == 1);
find_cath = img_cath(end);
% find_cath = diff(img_cath);
% find_cath = find(find_cath == - 1, 1, 'first');

% create masked imageset with the imaging catheter removed
OCT_cath = OCT_polar;
% OCT_cath(:, 1:find_cath+1, :) = NaN;
OCT_cath(:, 1:find_cath+1, :) = 0;