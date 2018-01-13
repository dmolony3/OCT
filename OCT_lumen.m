function [optimal_path_interpolated OCT_cartesian] = OCT_lumen(OCT_gw, OCT_sheath, output_size)

% this function uses dynamic programming to segment the lumen from OCT
% images, input images must be in the polar format and the catheter sheath
% contour must also be supplied

if nargin == 2
    output_size = 1024;
end

% convert to double
OCT_gw = double(OCT_gw);

% % apply  Gaussian blur
% OCT_gw = imgaussfilt3(OCT_gw, 2);
OCT_gw = imgaussfilt(OCT_gw, 2);

% pre-allocate memory for cartesian coordinates
OCT_cartesian = cell(length(OCT_gw(1,1,:)), 1);

% mask out the catheter sheath, set to zero and replace with image
% background value later
OCT_gw_sheath = OCT_gw;
image_background = ones(length(OCT_gw(1, 1, :)), 1);
optimal_path_interpolated = zeros(length(OCT_gw(:, 1, 1)), length(OCT_gw(1, 1, :)));

% % determine a value for image background so we can apply it to the masked
% % sheath region
% image_background = mean(squeeze(mean(OCT_gw_sheath, 2)));

for ii = 1:length(OCT_gw_sheath(1, 1, :))
    % determine a value for image background so we can apply it to the masked
    % sheath region
    image_background(ii) = mean(mean(OCT_gw_sheath(:, :, ii)));
    for j = 1:length(OCT_gw_sheath(:, 1, 1))
        %     OCT_gw_sheath(j, 1:OCT_sheath(j, i), ii) = OCT_gw_sheath(j, OCT_sheath(j, ii) + 1, ii);
        OCT_gw_sheath(j, 1:OCT_sheath(j, ii), ii) = 0;
    end
end

% shift the guidewire shadow
[OCT_gw_shift shadow_rows] = shift_image(OCT_gw_sheath);

% construct a vessel and lumen window 0.1 mm in size, assuming 4.5micron
% pixel size
mv = round(100e-6/4.5e-6);
ml = mv;
% parameter for the depth of the pixel intensity difference (0.075mm)

% length of line for measuring the gradient
% L = 38e-6/4.5e-6;
L = 20e-6/4.5e-6;
% L = 70e-6/4.5e-6;

% determine the start of the guidewire in the shifted images as these will
% not be included in the algorithm
gw_shadow_start = squeeze(sum(OCT_gw_shift, 2));

h = waitbar(0, 'processing images');

for i = 1:length(OCT_gw(1, 1, :))
    waitbar(i/length(OCT_gw(1, 1, :)));

    % perform dynamic programming to segment the lumen

    first_point = find(gw_shadow_start(:, i) == 0, 1, 'first');
%     if length(OCT_gw_shift(:, 1, 1)) - first_point > ml
        last_point = length(OCT_gw_shift(:, 1, 1)) - first_point;
%     else
%         last_point = mv;
%     end
    
    % pre-allocate memory
    C = zeros(size(OCT_gw(:, :, 1)));
    % set all pixels equal to zero to equal the mean background intensity,
    % these pixels correspond to the catheter sheath region
    OCT_image = OCT_gw_shift(:, :, i);
    OCT_image(OCT_image == 0) = image_background(i);
    
    % first construct the cost function
    for ii = 1:length(C(:, 1)) - last_point
        for j = 1+ml:length(C(1, :)) - mv
            if j <= ml
                ml_temp = 1;
%                 C(ii, j) = mean(OCT_image(ii, j:j + mv)) - mean(OCT_image(ii, ml_temp:j));
                C(ii, j) = mean(OCT_image(ii, j:j + mv) - OCT_image(ii, ml_temp:j));
            else
%                 C(ii, j) = mean(OCT_image(ii, j:j + mv)) - mean(OCT_image(ii, j - ml:j));
                 C(ii, j) = mean(OCT_image(ii, j:j + mv) - OCT_image(ii, j - ml:j));
            end
        end
    end
    
%     C = gradient(OCT_image);
    % normalize C
    C = (C - min(min(C)))./(max(max(C)) - min(min(C)));
    
    % determine the cumulative cost function
    CC = zeros(size(C));
    CC(1, :) = C(1, :);
    N = 10;
    for ii = 1:length(C(:, 1)) - last_point
        for j = 1+N:length(C(1, :)) - N
            max_values = max(CC(ii, j - N:j + N) + C(ii + 1, j));
            CC(ii + 1, j) = max_values(1);
        end
    end
    
    % determine the optimal path from the bottom to the top
    optimal_path = zeros(first_point, 1);
    
    max_values = find(CC(first_point, :) == max(CC(first_point, :)));
    optimal_path(end) = max_values(1);
    
    for  ii = 1:length(CC(:, 1)) - last_point - 1
        search_path =  optimal_path(end - ii + 1) - N:optimal_path(end - ii + 1) + N;
        max_values = find(CC(first_point - ii, search_path) == max(CC(first_point - ii, search_path)));
%         max_values = find(CC(first_point - ii, :) == max(CC(first_point - ii, :)));
        max_values = optimal_path(end - ii + 1) + max_values - N;
        optimal_path(end - ii) = max_values(1);
    end
    
    % smooth the path with a median filter
    optimal_path_filtered = medfilt1(optimal_path, 5); 
    
    % shift the optimal path back to original coordinates 
%     optimal_path_filtered(end + 1:length(OCT_gw(:, 1, 1))) = NaN;
    optimal_path_filtered(end -5:length(OCT_gw(:, 1, 1))) = NaN;
    
    % shift the path by the number of A lines the image was shifted
    shift_path = length(OCT_gw_shift(:, 1, 1)) - shadow_rows(2,i);
    optimal_path_original = circshift(optimal_path_filtered, -shift_path);
    
%     cla(figure(1))
%     figure(1), imshow(OCT_gw(:, :, i), [0 100])
%     hold on
%     s2=plot(circshift(optimal_path_filtered, -shift_path), 1:length(OCT_gw(:, 1, 1)))
%     pause(0.5)
%     % remove NaNs before path intepolation
%     remove_NaNs = isnan(optimal_path_original);
%     optimal_path_original(remove_NaNs) = [];
%     
%     % interpolate the path at the guidewire shadow
%     optimal_path_interpolated(:, i) = interp1(find(remove_NaNs == 0), optimal_path_original, 1:length(OCT_gw(:, 1, 1)));
    optimal_path_original = repmat(optimal_path_original, 3, 1);
    optimal_path_interp = interp1(1:length(optimal_path_original), optimal_path_original, 1:length(optimal_path_original), 'pchip');
    optimal_path_interpolated(:, i) = optimal_path_interp(length(OCT_gw(:, 1, 1)) + 1:length(OCT_gw(:, 1, 1))*2);
%     figure, plot(optimal_path_original, '.r')
%     hold on, plot(optimal_path_interp,'c')
    % convert to cartesian coordinates using correction factor based on
    % different image sizes
    conversion_factor = (output_size/2)/length(OCT_gw(1, :, 1));
    optimal_path_cart = [];
    [optimal_path_cart(:, 1) optimal_path_cart(:, 2)] = pol2cart(linspace(2*pi/length(OCT_gw(:, 1, 1)),2*pi,length(OCT_gw(:, 1, 1)))', optimal_path_interpolated(:, i).*conversion_factor);
    optimal_path_cart(:, 1) = optimal_path_cart(:, 1) + (output_size/2);
    optimal_path_cart(:, 2) = optimal_path_cart(:, 2) + (output_size/2);
%     % image needs to be rotate and flipped to display
%     figure,imshow(imrotate(fliplr(OCT(:,:,i)), -90, 'crop'), [0 200])
    OCT_cartesian{i} = optimal_path_cart;
end
close(h)