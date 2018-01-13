function OCT_sheath = OCT_sheath_segmentation(OCT_polar, output_size)

% this function segments an OCT sheath by finding the best match of a range
% of catheter sizes. The sheath match has larger values for the inner
% sheath compared to the outer sheath so as to prevent it from moving
% towards the lumen in contact with the sheath. The input is OCT images in
% the polar domain, while the output is a nxm matrix where n is the A-line
% column where the sheath ends and m corresponds to each image in the
% pullback

% the diameter of the sheath is approximately 100 pixels in a 1024x0124
% image, so we select a range of radii for different sheath sizes

% open a window that allows for an interactive measure of the sheath radius
% by selecting 2 points on the sheath
OCT_image= Polar2Im(double(OCT_polar(:,:,8)'), output_size, 'linear');
% figure, imshow(OCT_image(output_size/2-70:output_size/2+70,output_size/2-70:output_size/2+70),[0 300])
figure, imshow(OCT_image(output_size/2-100:output_size/2+100,output_size/2-100:output_size/2+100),[0 300])
[x y] = getpts();
r_o = sqrt((x(1) - x(2)).^2 + (y(1) - y(2)).^2)/2;
hold on, plot(x, y, 'r')
[x y] = getpts();
r_i = sqrt((x(1) - x(2)).^2 + (y(1) - y(2)).^2)/2;
plot(x, y, 'c')
close(gcf)
r_o = r_o-2:2:r_o+2;
r_i = r_i-2:2:r_i+2;
ix = output_size;
iy = output_size;

% pre-allocate memory
sheath_contour = cell(length(OCT_polar(1, 1, :)), 1);
sheath_centroid_point = zeros(length(OCT_polar(1, 1, :)), 2);
h = waitbar(0, 'processing images');

% pre-allocate a 4d matrix for the sheath mask, row and columns specify the
% pixel coordinates, third dimension the and the fourth dimension for
% different radii
sheath_mask = zeros(output_size, output_size, 13*13, length(r_o));
% create an array that contains the potential masks and then apply to each
% image
for j = 1:length(r_o)
    ii = 1;
    for cx = output_size/2 - 6:output_size/2 + 6
        for cy = output_size/2 - 6:output_size/2 + 6
            % cx and cy describe the center of the mask
            [x y] = meshgrid(-(cx - 1):(ix - cx), -(cy - 1):(iy - cy));
            %             c_mask = ((x.^2 + y.^2) <= r(j)^2);
            
            c_mask = ((x.^2 + y.^2) <= r_o(j)^2);
            c_mask2 = bwdist(bwdist(c_mask));
            
            % set pixels that should correspond to the sheath equal to a large value
            c_mask3 = double(c_mask);
            c_mask3(c_mask == 1) = 0.5;
            % mask outer sheath edge (first 2 pixels) from binary distance image
            c_mask2(c_mask2 == 0) = max(max(c_mask2)); % remove all zeros first
            c_mask3(c_mask2 <= 2) = 1;
            % mask out inner sheath edge as this falls within a certain pixel size
            c_mask2(c_mask2 > (r_o(j)-r_i(j))) = 0;
            c_mask2(c_mask2 < (r_o(j)-r_i(j) - 2)) = 0;
            % give a higher strength to the inner sheath as this will not
            % encounter noise such as blood or the lumen
            c_mask3(c_mask2 ~= 0) = 2;

            sheath_mask(:, :, ii, j) = c_mask3;
            ii = ii + 1;
        end
    end
end
    
for i = 1:length(OCT_polar(1, 1, :))
    waitbar(i/length(OCT_polar(1, 1, :)));
    
    % convert to cartesian domain
    OCT_image= Polar2Im(double(OCT_polar(:,:,i)'), output_size, 'linear');
    % make a duplicate for processing later
    OCT_image2 = OCT_image;
    % remove very high intensities such as the guidewire to aid in the
    % segmentation
    OCT_image(OCT_image == -Inf) = 30;
    OCT_image(OCT_image > 100) = 0;
    % h=fspecial('gaussian', [round(2*3) round(2*3)], 3);
    % OCT_image = imfilter(OCT_image, h);
    image_med = zeros(13, 13, 3);
    image_med2 = zeros(13, 13, 3);
    for j = 1:length(r_o)
        ii = 1;
        for cx = output_size/2 - 6:output_size/2 + 6
            for cy = output_size/2 - 6:output_size/2 + 6
%                 % cx and cy describe the center of the mask
%                 [x y] = meshgrid(-(cx - 1):(ix - cx), -(cy - 1):(iy - cy));
%                 %             c_mask = ((x.^2 + y.^2) <= r(j)^2);
%                 
%                 c_mask = ((x.^2 + y.^2) <= r_o(j)^2);
%                 c_mask2 = bwdist(bwdist(c_mask));
%                 
%                 % set pixels that should correspond to the sheath equal to a large value
%                 c_mask3 = double(c_mask);
%                 c_mask3(c_mask == 1) = 0.5;
%                 % mask outer sheath edge (first 2 pixels) from binary distance image
%                 c_mask2(c_mask2 == 0) = max(max(c_mask2)); % remove all zeros first
%                 c_mask3(c_mask2 <= 2) = 1;
%                 % mask out inner sheath edge as this falls within a certain pixel size
%                 c_mask2(c_mask2 > (r_o(j)-r_i(j))) = 0;
%                 c_mask2(c_mask2 < (r_o(j)-r_i(j) - 2)) = 0;
%                 % give a higher strength to the inner sheath as this will not
%                 % encounter noise such as blood or the lumen
%                 c_mask3(c_mask2 ~= 0) = 2;
%                 weighted_image = c_mask3.*OCT_image;
%                 
%                 image_med(cx -505, cy - 505, j) = mean(weighted_image(c_mask));
                
                
                weighted_image = sheath_mask(:, :, ii, j).*OCT_image;
                % create a binary image for averaging the pixels in the
                % ROI, add 0.5 so that values that equal 0.5 are included
                % in the binary image
                c_mask = im2bw(sheath_mask(:, :, ii, j)+.5);
                image_med(cx - (output_size/2 - 7), cy - (output_size/2 - 7), j) = mean(weighted_image(c_mask));
                %                 image_med2(cx - 505, cy - 505, j) = median(weighted_image(c_mask));
                ii = ii + 1;

                % weight the values at the center of the circle greater in
                % order to constrain circle from moving too far
                %             image_med(cx -length(OCT_polar(:, 1, 1)), cy -length(OCT_polar(:, 1, 1)), j) = mean(OCT_image(c_mask));
            end
        end
    end
    % in order to avoid guidewire artifact and the wall assign large values a
    % a zero value
%     [cx cy cz] = ind2sub(size(image_med), find(image_med == max(max(max(image_med)))));
%     cx = cx + 506;
%     cy = cy + 506;
%     
%     [x y] = meshgrid(-(cx - 1):(ix - cx), -(cy - 1):(iy - cy));
%     c_mask = ((x.^2 + y.^2) <= r_o(cz)^2);
    
    [mask_no(1) mask_no(2) r_no] = ind2sub(size(image_med), find(image_med == max(max(max(image_med)))));
    c_mask = sheath_mask(:, :, sub2ind(size(image_med(:,:,1)), mask_no(2), mask_no(1)), r_no);

    % mask_image = zeros(size(OCT_image(:, :, 1)));
    % mask_image(c_mask == 1) = OCT_image(c_mask);
    % OCT_image2=OCT_image./max(max(OCT_image));
    % figure, h1 = imshow(OCT_image2, [])
    % hold on
    % h2=imshow(c_mask3,[])
    % h3=imshow(mask_image,[])
    % hold off
    % axis([ 460 580 450 570])
    % alpha = ones(size(OCT_image))*0.25;
    % set(h3, 'AlphaData', alpha)
    
%     % mask the catheter sheath out of the image
%     OCT_sheath = imcomplement(c_mask).*OCT_image2;
%     OCT_sheath_polar(:, :, i) = polartrans(OCT_sheath, 960,length(OCT_polar(:, 1, 1)), 512, 512, 'linear' ,'valid');
    
    % dtermine contour points, 1st column is y and 2nd column is x
    sheath_contour{i} = cell2mat(bwboundaries(c_mask));

    % determine sheath centroid
    sheath_centroid = [];
    % reverse indexes so that find outputs x into first column
    [sheath_centroid(:, 2) sheath_centroid(:, 1)] = find(c_mask);
    sheath_centroid_point(i, :) = [mean(sheath_centroid(:, 1)) mean(sheath_centroid(:, 2))];
end
close(h)

% apply a filter to the centroid position as this should not change greatly
% between successive images
sheath_centroid_filtered(:, 1) = medfilt1(sheath_centroid_point(:, 1), 5);
sheath_centroid_filtered(:, 2) = medfilt1(sheath_centroid_point(:, 2), 5);

% move the contour if the centroid position has changed
% convert the images to cartesian coordinates
move_sheath = sheath_centroid_point - sheath_centroid_filtered;

% as the sheath contour has x coorindates in the 2nd column we switch the
% order here to match it
move_sheath = fliplr(move_sheath);
OCT_sheath = zeros(length(OCT_polar(:, 1, 1)), length(OCT_polar(1, 1, :)));
for i=1:length(OCT_polar(1,1,:))
    % move the sheath contour to the new coordinates in the filtered center
    sheath_contour{i} = sheath_contour{i} - repmat(move_sheath(i, :),length(sheath_contour{i}(:,1)), 1);
    % the cartesian translation at the beginning sends the first A-line to
    % be the at 12 o'clock and it follows clockwise
    
    % convert cartesian coordinaets to polar coordinates
    OCT_sheath_polar = [];
    [OCT_sheath_polar(:, 2) OCT_sheath_polar(:, 1)] = cart2pol(sheath_contour{i}(:, 2) - output_size/2, sheath_contour{i}(:, 1) - output_size/2);
    % convert to 0 to 2pi range
    OCT_sheath_polar(OCT_sheath_polar < 0) = OCT_sheath_polar(OCT_sheath_polar < 0)+2*pi;
    % convert pixel size in cartesian to polar based on image sizes
    OCT_sheath_polar(:,1) = OCT_sheath_polar(:,1).*(length(OCT_polar(1, :, 1))/(output_size/2));
    % remove duplicates and interpolate to match the no. of A lines
    OCT_sheath_polar = unique(OCT_sheath_polar,'rows');
    OCT_sheath_polar = sortrows(OCT_sheath_polar, 2);
    OCT_sheath_interp = interp1(OCT_sheath_polar(:,2), OCT_sheath_polar(:, 1), linspace(0, 2*pi-(2*pi)/length(OCT_polar(:,1, 1)),length(OCT_polar(:, 1, 1)))', 'linear', 'extrap');
    % shift the contour by 90 degrees
    OCT_sheath_interp = circshift(OCT_sheath_interp,length(OCT_polar(:, 1, 1))/4);
    OCT_sheath(:, i) = round(OCT_sheath_interp);
end
%     cx = sheath_centroid_point(i, 2);
%     cy = sheath_centroid_point(i, 1);
%     [x y] = meshgrid(-(cx - 1):(ix - cx), -(cy - 1):(iy - cy));
%     c_mask = ((x.^2 + y.^2) <= r_o^2);
%     OCT_image2 =  Polar2Im(double(OCT_polar(:,:,i)'), output_size, 'linear');
%     OCT_sheath = imcomplement(c_mask).*OCT_image2;
%     OCT_sheath_polar(:, :, i) = polartrans(OCT_sheath, 960,length(OCT_polar(:, 1, 1)), 512, 512, 'linear' ,'valid');
% end

%
% figure,imshow(Polar2Im(double(OCT_polar(:,:,5)'), output_size, 'linear'), [0 100])
% hold on
% plot(sheath_contour{5}(:, 2), sheath_contour{5}(:, 1),'r')
%
% figure, imshow(OCT_polar(:,:, 338), [0 100])
% hold on
% s1=plot(OCT_sheath(:,i), 1:length(OCT_polar(:,1)))