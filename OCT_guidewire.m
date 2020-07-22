function OCT_gw = OCT_guidewire(OCT_cath, gw_intensity)

% this function detects the location of the guidewire from a pullback of
% OCT images in the polar orientation based on the method by Ancong Wang et al


if nargin == 1
    gw_intensity = 0.75;
end

% convert to double
OCT_cath = double(OCT_cath);

% detect the peak point in each A-line
peak_intensities = squeeze(max(OCT_cath, [], 2));

% pre-allocate memory
gw_location = zeros(size(peak_intensities));

% determine peak intensity location in the image depth
for i = 1:length(peak_intensities(1, :))
    peak_intensity_matrix = OCT_cath(:, :, i) - repmat(peak_intensities(:, i), 1, length(OCT_cath(1, :, 1)));
    % the peak intensity occurs at the first zero
    peak_intensity_location = [];
    [peak_intensity_location(:, 1) peak_intensity_location(:, 2)] = find(peak_intensity_matrix == 0);

    % sort by circumference
    peak_intensity_location = sortrows(peak_intensity_location, 1);

    % remove any duplicate rows keeping the second max value
    [dummy new_peaks dummy1]=unique(peak_intensity_location(:,1));
    
    % compute one max location for each row
    peak_intensity_location = peak_intensity_location(new_peaks, :);

    % create 3d matrix for storing all intensity locations
    peak_intensity_3D(:, i) = peak_intensity_location(:, 2);
    % assuming the peak intensity occurs around the front/middle of the guidewire
    % we move the peak intensity forward 4 pixels so that we are not 
    % analyzing the guidewire signal still
    peak_intensity_location(:, 2) = peak_intensity_location(:, 2) + 4;
    
    % determine the proportion of the subsum behind the peak point
    intensity_proportion = ones(length(OCT_cath(:, 1, 1)), 1);

    for j = 1:length(OCT_cath(:, 1, 1))
        % detect the peak point location in each A-line
%         intensity_sum = sum(OCT_cath(j, :, i), 2);
%         intensity_sub_sum = sum(OCT_cath(j, peak_intensity_location(j, 2):end, i), 2);
        intensity_sum = mean(OCT_cath(j, :, i), 2);
        intensity_sub_sum = mean(OCT_cath(j, peak_intensity_location(j, 2):end, i), 2);
        
        intensity_proportion(j) = intensity_sub_sum/intensity_sum;
    end
     
    % determine possible guidewire locations based on the subsum intensity 
    % being less than 0.75 of total intensity
    intensity_proportion(intensity_proportion > gw_intensity) = 1;
    intensity_proportion(intensity_proportion < gw_intensity) = 0;
    intensity_proportion = (intensity_proportion - 1).*-1;
    gw_location(:, i) = intensity_proportion;

end

% binary area open to remove small unconnected areas
gw_location = bwareaopen(gw_location, 32);

% in case the guidewire shadow carries over from the bottom to the top of
% the image we make the image periodic
gw_image  = [gw_location; gw_location];

% create a binary distance image
distance_image = bwdist(gw_image);

% find the shortest path through the distance image
N = 10;
% use dynamic programming to find min path
CC = zeros(size(distance_image));
C = distance_image;
matrix_size = size(C);

best_candidate_node = [NaN(N, length(C(1, :))); zeros(size(C));  NaN(N, length(C(1, :)))];
CC = [NaN(N, length(CC(1, :))); CC;  NaN(N, length(CC(1, :)))];
C = [NaN(N, length(C(1, :))); C;  NaN(N, length(C(1, :)))];
for i = 1:length(CC(1, :)) - 1
    for j = 1+N:length(CC(:, 1))-N
        CC(j, i + 1) = min(CC(j-N:j+N, i) + C(j, i + 1));
        % store best candidate node (C(j-N:j+N, ii) for each node where best
        % candidate is the min from the cost matrix
        candidate_nodes = find(CC(j - N:j + N, i) == min(CC(j - N:j + N, i)));
        %         candidate_nodes = find(C(j - N:j + N, ii) == min(C(j - N:j + N, ii)));
        possible_nodes = j-N:j+N;
        best_candidate_node(j, i + 1) = possible_nodes(candidate_nodes(1));
    end
end

% remove padded NaNs
CC(isnan(CC)) = [];
CC = reshape(CC, matrix_size);
best_candidate_node(isnan(best_candidate_node)) = [];
best_candidate_node = reshape(best_candidate_node, matrix_size);

% subtract N from the best candidate node matrix
best_candidate_node = best_candidate_node - N;

% find minimum path
start_path = find(CC(:,end)==min(CC(:,end)));
optimal_path = start_path(1);

for j = 1:length(best_candidate_node(1, :)) - 1
    optimal_path(j + 1) = best_candidate_node(optimal_path(j),end + 1 - j);
%     optimal_path2(i + 1) = find(CC_fc(:, end-i) == min(CC_fc(:, end - i)));
end
optimal_path = fliplr(optimal_path);
% add a layer of thickness to the guidewire based on the location of the
% peak intensities, a guidewire closer to the OCT catheter will block more
% of the image and have a large shadow
gw_shadow = ones(2, length(optimal_path));
% add 4 pixels to the guidewire shadow as we want to be in the center of
% the brightness artifact
gw_shadow(1, :) = optimal_path + 4;

% make peak intensities periodic
peak_intensity_3D = [peak_intensity_3D; peak_intensity_3D];
for j = 1:length(optimal_path);
    % first determine at what depth the peak intensity occurs at
    gw_depth = peak_intensity_3D(optimal_path(j):optimal_path(j)+5, j);
    % in determining the depth using 1 value may be unreliable due to the
    % presence of noise, so we use the median of 5 values
    gw_depth = median(gw_depth);
    % an exponential formula based on empirical data is used to determine
    % the shadow width
    shadow_width = 81.572*exp(-0.007*gw_depth);
    % add the width either side of the center of the brightness artifact
    gw_shadow(2, j) = gw_shadow(1, j) + round(shadow_width/2)+20;
    gw_shadow(1, j) = gw_shadow(1, j) - round(shadow_width/2)-20;    
end

% if any values are greater than the length of the original image these
% need to shifted back to the start
cross_image_border = gw_shadow > length(OCT_cath(:, 1, 1));
gw_shadow(cross_image_border) = gw_shadow(cross_image_border) - length(OCT_cath(:, 1, 1));

% if any values are negative they need to be shifted to the end of the
% image
gw_shadow(gw_shadow < 1) = gw_shadow(gw_shadow < 1)+length(OCT_cath(:, 1, 1));

figure,imshow(gw_location,[])
hold on
axis on
plot(1:length(OCT_cath(1, 1, :)), gw_shadow(1, :),'r.')
plot(1:length(OCT_cath(1, 1, :)), gw_shadow(2, :),'c.')
xlabel('image no.')
ylabel('A-line no.')
% mask the guidewire region with NaNs
OCT_gw = OCT_cath;
for j = 1:length(gw_shadow(1, :))
    if gw_shadow(1, j) > gw_shadow(2, j)
        OCT_gw(1:gw_shadow(2, j), :, j) = 0;
        OCT_gw(gw_shadow(1, j):end, :, j) = 0;
    else
        OCT_gw(gw_shadow(1, j):gw_shadow(2, j), :, j) = 0;
    end
end

figure,imshow(OCT_gw(:,:,9), [0 300])
hold on,plot([500 500], gw_shadow(:, 9), 'r')
axis on


% adjacency_matrix = zeros(length(distance_image(:, 1)), length(distance_image(:, 1)));
% cost_matrix = zeros(length(distance_image(:, 1)), length(distance_image(:, 1)));
% % so that the distance values aren't zero we set zero values in the
% % distance image to a small positive value
% distance_image(distance_image == 0) = 0.001;
% 
% for i = 1:length(distance_image(1, :)) - 1
%     for j = 2:length(distance_image(:, 1)) - 1
%     if gw_image(j, i + 1) == 1
%         connected_pixels = j-1:j+1;
%         connected_pixels_true = gw_image(j-1:j+1, i + 1);
%         connected_pixels_true = find(connected_pixels_true == 1);
%         connected_pixels = connected_pixels(connected_pixels_true);
%         adjacency_matrix(connected_pixels, i + 1) = 1;
%         cost_matrix(connected_pixels, i + 1) = distance_image(connected_pixels, i + 1);
%     end
%     end
% end

