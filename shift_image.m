function [OCT_gw_shift shadow_rows] = shift_image(OCT_gw)

% this function shifts the guidewire shadow to the bottom of the image so
% that it can be excluded from further image processing

% detect where the zero rows are
detect_shadow = squeeze(sum(OCT_gw, 2));

OCT_gw_shift = zeros(size(OCT_gw));
shadow_rows = ones(2, length(OCT_gw(1, 1, :)));
for i = 1:length(OCT_gw(1, 1, :))
    shadow_rows(1, i) = find(detect_shadow(:, i) == 0, 1, 'first');
    shadow_rows(2, i) = find(detect_shadow(:, i) == 0, 1, 'last');
    
    
    % check if the catheter shadow crosses from the bottom to the top of the
    % image by seeing if the first row is a zero
    if shadow_rows(1, i) == 1 && (shadow_rows(1,i) + shadow_rows(2,i) > 200)
        % first and last zeros are no longer the start and end of catheter
        all_zeros = find(detect_shadow(:, i) == 0);
        positive_match = ones(length(OCT_gw(:, 1, 1)), 1);
        positive_match(all_zeros) = 0;
        % take the difference from the binary matrix and the first positive
        % one corresponds to the end of the shadow and the first negative
        % one correponds to the start of the shadow
        positive_match = diff(positive_match);
        shadow_rows(1, i) = find(positive_match == -1);
        shadow_rows(2, i) = find(positive_match == 1);
        OCT_gw_shift(:, :, i) = [OCT_gw(shadow_rows(2, i) + 1:shadow_rows(1, i) - 1, :, i); OCT_gw(shadow_rows(1, i):end, :, i); OCT_gw(1:shadow_rows(2, i), :, i)];
    else
        OCT_gw_shift(:, :, i) = [OCT_gw(shadow_rows(2, i) + 1:end, :, i); OCT_gw(1:shadow_rows(1, i) - 1, :, i); OCT_gw(shadow_rows(1, i):shadow_rows(2, i), :, i)];
    end
end