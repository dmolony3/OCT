function OCT_contour = contour2pol(OCT_contour_cart, OCT_polar, output_size)

% this function converts a contour from cartesian coordinates to polar
% coordinates
no_cols = length(OCT_polar(1, :, 1));
no_rows = length(OCT_polar(:, 1, 1));

for i = 1:length(OCT_contour_cart)
    OCT_contour_polar = [];
    
    if ~isempty(OCT_contour_cart{i})
        [OCT_contour_polar(:, 2) OCT_contour_polar(:, 1)] = cart2pol(OCT_contour_cart{i}(:, 2) - (output_size/2), OCT_contour_cart{i}(:, 1) - (output_size/2));
        % convert to 0 to 2pi range
        OCT_contour_polar(OCT_contour_polar < 0) = OCT_contour_polar(OCT_contour_polar < 0)+2*pi;
        % convert pixel size in cartesian to polar based on image sizes
        OCT_contour_polar(:,1) = OCT_contour_polar(:,1).*(no_cols/(output_size/2));
        % remove duplicates and interpolate to match the no. of A lines
    %     OCT_contour_polar = unique(OCT_contour_polar,'rows');
    %     OCT_contour_polar = sortrows(OCT_contour_polar, 2);
        [theta unique_idx] = unique(OCT_contour_polar(:, 2));
        OCT_contour_polar = OCT_contour_polar(unique_idx, :);
        OCT_contour_interp = interp1(OCT_contour_polar(:,2), OCT_contour_polar(:, 1), linspace(0, 2*pi-(2*pi)/no_rows, no_rows)');
        % if output contains NaNs we are interpolating outside the range of the contour
        % make contour repeating periodic signal
        if any(isnan(OCT_contour_interp))
            OCT_contour_polar = [repmat(OCT_contour_polar(:, 1), 3, 1) [OCT_contour_polar(:, 2); OCT_contour_polar(:, 2)+2*pi; OCT_contour_polar(:, 2)+4*pi]];
            OCT_contour_interp = interp1(OCT_contour_polar(:,2), OCT_contour_polar(:, 1), linspace(0, 6*pi-(2*pi)/(no_rows*3), no_rows*3)');
            OCT_contour_interp = OCT_contour_interp(length(OCT_polar(:,1,1))+1:length(OCT_polar(:,1,1))*2, :);
        end
            % shift the contour by 90 degrees
        OCT_contour_interp = circshift(OCT_contour_interp, -no_rows/4);
        OCT_contour(:, i) = round(OCT_contour_interp);
    end
end