function OCT_GUI

% opens a GUI where the user can segment OCT images using dynamic
% programming algorithm

figure_dimensions = get(0, 'ScreenSize');
GUI.Fig = figure('position', figure_dimensions, 'menu', 'none');
background_color = get(GUI.Fig, 'color');
set(gcf, 'toolbar' , 'figure')
cameratoolbar('Show')
aspect_ratio = figure_dimensions(1)/figure_dimensions(2);
rect = [0.35 0.2*aspect_ratio];

% first axis for displaying cartesian view
GUI.Ax1 = axes('Parent', GUI.Fig, 'Units', 'normalized', 'position', ...
    [0.05 0.1 2.25*rect(2) 2.25*rect(1)]);
GUI.Ax1.XTick=0;
GUI.Ax1.YTick=0;

% second axis for displaying polar view
GUI.Ax2 = axes('Parent', GUI.Fig, 'Units', 'normalized', 'position', ...
    [0.6 0.5 1.7*rect(2) 1.25*rect(1)]);
GUI.Ax2.XTick=0;
GUI.Ax2.YTick=0;

% buttons for segmentation
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.6 0.325 0.1 0.05], 'String', 'Load pullback',...
    'Callback',@load_images, 'fontsize', 10);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.6 0.275 0.1 0.05], 'String', 'Segment guidewire',...
    'Callback',@segment_gw, 'fontsize', 10);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.6 0.225 0.1 0.05], 'String', 'Segment sheath',...
    'Callback',@segment_sheath, 'fontsize', 10);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.6 0.175 0.1 0.05], 'String', 'Segment lumen',...
    'TooltipString', ['Segment all images with dynamic programming'], ...
    'Callback',@segment_lumen, 'fontsize', 10);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.6 0.125 0.1 0.05], 'String', 'Threshold lumen',...
    'TooltipString', ['Segment current image with threshold'], ...
    'Callback',@threshold_lumen, 'fontsize', 10);

uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.85 0.325 0.1 0.05], 'String', 'Edit lumen',...
    'Callback',@edit_seg_spline, 'fontsize', 10);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.85 0.275 0.1 0.05], 'String', 'Copy lumen',...
    'Callback',@copy_seg, 'fontsize', 10, 'ToolTipString', ['Copy lumen contour from previous image']);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.85 0.225 0.1 0.05], 'String', 'Load lumen', ...
    'Callback',@load_seg, 'fontsize', 10, 'ToolTipString', ['Load saved lumen contour']);
uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.85 0.175 0.1 0.05], 'String', 'Save', ...
    'Callback',@save_seg, 'fontsize', 10);

% initialize first image
GUI.OCT_image = 1;

GUI.Txt = uicontrol('Style', 'text',  'Units', 'Normalized', 'FontSize', 14, 'FontWeight', 'bold', ...
    'Position', [0.05 0.9 0.125 0.025], 'String',strcat('Current Frame :', num2str(GUI.OCT_image)));

% edit and text boxes for guidewire thresholds
img_cath_threshold = 0.2;
gw_threshold = 0.6;
GUI.s2 = uicontrol('Parent', GUI.Fig, 'style','edit','units', 'normalized', ...
    'Position',[0.725 0.325 0.025 0.05], 'String', string(img_cath_threshold), ...
    'ToolTipString', ['Enter a value for thresholding the catheter, use a greater value if more than the catheter is removed']);
GUI.s3 = uicontrol('Parent', GUI.Fig, 'style','edit','units', 'normalized', ...
    'Position',[0.775 0.325 0.025 0.05], 'String', string(gw_threshold), ...
    'ToolTipString', ['Enter a value for thresholding the guidewire']);
GUI.Txt1 = uicontrol('Style', 'text',  'Units', 'Normalized', 'FontSize', 8, 'Position', [0.72 0.375 0.035 0.025], 'String','Catheter');
GUI.Txt2 = uicontrol('Style', 'text',  'Units', 'Normalized', 'FontSize', 8, 'Position', [0.77 0.375 0.035 0.025], 'String','Guidewire');

% checkbox for including stent struts in segmentation
GUI.s4 = uicontrol('Parent', GUI.Fig, 'style','checkbox','units', 'normalized', ...
    'Position',[0.725 0.125 0.1 0.05], 'String', 'Include struts', 'fontsize', 10, ...
    'ToolTipString', ['Check this to include the stent struts inside the lumen mask']);
GUI.s5 = uicontrol('Parent', GUI.Fig, 'style','checkbox','units', 'normalized', ...
    'Position',[0.80 0.125 0.1 0.05], 'String', 'Threshold all', 'fontsize', 10, ...
    'ToolTipString', ['Check this to threshold all images, otherwise just the current image will be processed']);

OCT_polar = [];
OCT_cart = [];
OCT_gw = [];
OCT_sheath = [];
output_size = 1024;
OCT_lumen_contour = [];
OCT_contour_cart = {};
OCT_spline = [];

function slide_images(hObj, eventdata)
    GUI.OCT_image = round(get(hObj, 'value'));
    update_display()
end

function update_display()
    cla(GUI.Ax1)
    cla(GUI.Ax2)
    imshow(OCT_cart(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax1)
    imshow(OCT_gw(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax2)
    set(GUI.Txt, 'string', strcat('Current Frame :', num2str(GUI.OCT_image)));
    plot(OCT_sheath(:,GUI.OCT_image), 1:length(OCT_gw(:, 1, 1)), 'Parent', GUI.Ax2)
    if ~isempty(OCT_contour_cart{GUI.OCT_image})
        plot(OCT_contour_cart{GUI.OCT_image}(:, 1), OCT_contour_cart{GUI.OCT_image}(:, 2), 'Parent', GUI.Ax1)
        plot(OCT_lumen_contour(:, GUI.OCT_image), 1:length(OCT_gw(:, 1, 1)), 'Parent', GUI.Ax2)
    end
end

function load_images(hObj, eventdata)
    % load image files in dcm or raw format
    format = questdlg('Choose format', 'Select format of OCT files', 'raw (.oct)', 'dicom', 'raw (.oct)');
    output_size = 1024;
    if strcmp(format, 'dicom')
        [OCT_polar OCT_cart] = OCT_cart2pol();
        GUI.s2.String = string(0.5);
        GUI.s3.String = string(0.8);
    elseif strcmp(format, 'raw (.oct)')
        [OCT_polar OCT_cart] = OCT_raw2cart(output_size);
        GUI.s2.String = string(0.1);
        GUI.s3.String = string(0.25);
    end
    OCT_gw = OCT_polar;
    OCT_contour_cart = cell(length(OCT_cart(1,1,:)), 1);
    OCT_sheath = zeros(length(OCT_polar(:,1,1)), length(OCT_polar(1,1,:)));

    create_slider()
end

function create_slider()
    % creates slider
    GUI.s1 = uicontrol('Parent', GUI.Fig, 'Style', 'slider', 'units', 'normalized',...
    'Min', 1, 'Max',length(OCT_cart(1,1,:)),'Value',1,'Position', [0.2 0.9 0.3 0.05],...
        'sliderstep', [1/length(OCT_cart(1,1,:)) 10/length(OCT_cart(1,1,:))], 'Callback', @slide_images); 
    imshow(OCT_cart(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax1)
    imshow(OCT_gw(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax2)
    hold(GUI.Ax1, 'on')
    hold(GUI.Ax2, 'on')    
end

function segment_gw(hObj, eventdata)
    % segments the guidewire
    img_cath_threshold = str2num(get(GUI.s2, 'string'));
    gw_threshold = str2num(get(GUI.s3, 'string'));
    OCT_cath = OCT_img_cath(OCT_polar, img_cath_threshold);
    OCT_gw = OCT_guidewire(OCT_cath, gw_threshold);
end

function segment_sheath(hObj, eventdata)
    % segments sheath
    OCT_sheath = OCT_sheath_segmentation(OCT_polar, output_size);
    % plot sheath in polar image
    plot(OCT_sheath(:,GUI.OCT_image), 1:length(OCT_polar(:, 1, 1)), 'Parent', GUI.Ax2)
end

function segment_lumen(hObj, eventdata)
    % segments sheath
    OCT_lumen_contour = OCT_lumen(OCT_gw, OCT_sheath);
    % plot in polar image  
    plot(OCT_lumen_contour(:, GUI.OCT_image), 1:length(OCT_polar(:, 1, 1)), 'Parent', GUI.Ax2)
    % convert to cartesian
    OCT_lumen_contour1 = circshift(OCT_lumen_contour, length(OCT_lumen_contour(:,1))/2);
    OCT_contour_cart = contour2cart(OCT_lumen_contour1, OCT_polar, round(length(OCT_cart(:,1,1,1))/2)*2, 0);
    % if the contour doesn't match the image try reverse x and y
%     for i = 1:length(OCT_contour_cart)
%         OCT_contour_cart{i} = [OCT_contour_cart{i}(:,2) OCT_contour_cart{i}(:, 1)];
%     end
    
    plot(OCT_contour_cart{GUI.OCT_image}(:, 1), OCT_contour_cart{GUI.OCT_image}(:, 2), 'Parent', GUI.Ax1)
end

function threshold_lumen(hObj, eventdata)
    % thresholds the current image to produce lumen segmentation
    include_struts = get(GUI.s4, 'value');
    if get(GUI.s5, 'value') == 1
        h = waitbar(0, 'processing images');
        for i =1:length(OCT_gw(1,1,:))
            waitbar(i/length(OCT_gw(1, 1, :)));
            OCT_lumen_contour1 = OCT_threshold(OCT_gw(:, :, i), OCT_sheath(:, i), include_struts);
            OCT_lumen_contour(:, i) = OCT_lumen_contour1;
            OCT_lumen_contour1 = circshift(OCT_lumen_contour1, length(OCT_lumen_contour1(:,1))/2);
            OCT_contour_cart(i) = contour2cart(OCT_lumen_contour1, OCT_polar, round(length(OCT_cart(:,1,1,1))/2)*2, 0);            
        end
        close(h);
    else
        OCT_lumen_contour1 = OCT_threshold(OCT_gw(:, :, GUI.OCT_image), OCT_sheath(:, GUI.OCT_image), include_struts);
        OCT_lumen_contour(:, GUI.OCT_image) = OCT_lumen_contour1;
        % convert to cartesian
        OCT_lumen_contour1 = circshift(OCT_lumen_contour1, length(OCT_lumen_contour1(:,1))/2);
        OCT_contour_cart(GUI.OCT_image) = contour2cart(OCT_lumen_contour1, OCT_polar, round(length(OCT_cart(:,1,1,1))/2)*2, 0);
    end
    plot(OCT_contour_cart{GUI.OCT_image}(:, 1), OCT_contour_cart{GUI.OCT_image}(:, 2), 'Parent', GUI.Ax1)
    plot(OCT_lumen_contour(:, GUI.OCT_image), 1:length(OCT_gw(:, 1, 1)), 'Parent', GUI.Ax2)

end

function edit_seg(hObj, eventdata)
    % manually edit the segmentation
    % user clicks once to select the point and a second time to place
    % the point, the plot is then updated after the user presses return
    
    % downsample contour
    if length(OCT_contour_cart{GUI.OCT_image}(:, 1)) > 30
%     for i = 1:length(OCT_contour_cart)
        % determine how much undersampling is required
        i=GUI.OCT_image;
        under_sample = round(length(OCT_contour_cart{i}(:, 1))/30);
        OCT_contour_cart2{i}(:, 1) = OCT_contour_cart{i}(1:under_sample:end, 1);
        OCT_contour_cart2{i}(:, 2) = OCT_contour_cart{i}(1:under_sample:end, 2);
%     end
    end
    lumen = [OCT_contour_cart2{GUI.OCT_image}(:,1), OCT_contour_cart2{GUI.OCT_image}(:,2)];

    cla(GUI.Ax1)
    imshow(OCT_cart(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax1)
    plot(lumen(:, 1), lumen(:, 2), 'r.-', 'Parent', GUI.Ax1)

    resume= 0;
    while resume == 0
        
        [x y] = ginput(2);
        if ~isempty(x)
            find_x = lumen(:, 1) - x(1);
            find_y = lumen(:, 2) - y(1);
            % the point will be the minimum added distance from the x and y
            find_point = sum([abs(find_x) abs(find_y)], 2);
            find_point = find(find_point == min(find_point));
            lumen(find_point, :) = [x(2) y(2)];
            cla(GUI.Ax1)
            imshow(OCT_cart(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax1)
            plot(lumen(:, 1), lumen(:, 2), 'r.-', 'Parent', GUI.Ax1)
        else
            % re-interpolate back to desired resolution
%             contour_polar{1} = [lumen; lumen; lumen];
            contour_polar{1} = [lumen];
            contour_polar = contour2pol(contour_polar, OCT_polar, output_size);
%             contour_polar = contour_polar(length(OCT_polar(:,1,1))+1:length(OCT_polar(:,1,1))*2);
            % convert back to cartesian
            OCT_lumen_contour1 = circshift(contour_polar, length(OCT_lumen_contour(:,1))/2);
            contour_cart = contour2cart(OCT_lumen_contour1, OCT_polar, round(length(OCT_cart(:,1,1,1))/2)*2, 0);
            OCT_contour_cart{GUI.OCT_image} = contour_cart{1};
            OCT_lumen_contour(:, GUI.OCT_image) = contour_polar;
            % OCT_contour_cart{GUI.OCT_image} = lumen;
            resume = 1;
        end
    end
    
end

function edit_seg_spline(hObj, eventdata)
    % manually edit the segmentation
    % user  drags sline points around    
    % downsample contour
    if length(OCT_contour_cart{GUI.OCT_image}(:, 1)) > 30
%     for i = 1:length(OCT_contour_cart)
        % determine how much undersampling is required
        i=GUI.OCT_image;
        under_sample = round(length(OCT_contour_cart{i}(:, 1))/30);
        OCT_contour_cart2{i}(:, 1) = OCT_contour_cart{i}(1:under_sample:end, 1);
        OCT_contour_cart2{i}(:, 2) = OCT_contour_cart{i}(1:under_sample:end, 2);
%     end
    end
    lumen = [OCT_contour_cart2{GUI.OCT_image}(:,1), OCT_contour_cart2{GUI.OCT_image}(:,2)];

    cla(GUI.Ax1)
    imshow(OCT_cart(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax1)
    sp = plot(lumen(:, 1), lumen(:, 2), 'r-', 'Parent', GUI.Ax1);
    OCT_spline = splineroi();
    OCT_spline.parent = GUI.Ax1;
    OCT_spline.hSpline = sp;
    OCT_spline.addNode(lumen);
    
    GUI.compute_button = uicontrol('Parent', GUI.Fig, 'style','pushbutton','units', 'normalized', ...
    'Position',[0.6 0.075 0.1 0.05], 'String', 'Recompute',...
    'Callback',@recompute_lumen, 'fontsize', 10);  
end

function recompute_lumen(hObj, eventdata)
    % stores the edited lumen contour
    contour_polar{1} = OCT_spline.calcSpline';
    contour_polar = contour2pol(contour_polar, OCT_polar, output_size);
    OCT_lumen_contour1 = circshift(contour_polar, length(OCT_lumen_contour(:,1))/2);
    contour_cart = contour2cart(OCT_lumen_contour1, OCT_polar, round(length(OCT_cart(:,1,1,1))/2)*2, 0);
    OCT_contour_cart{GUI.OCT_image} = contour_cart{1};
    OCT_lumen_contour(:, GUI.OCT_image) = contour_polar;
    delete(GUI.compute_button);
    delete(OCT_spline.hSpline);
    delete(OCT_spline.hPoint);
    OCT_spline = [];
    update_display();
end

function load_seg(hObj, eventdata)
    % load a previously saved contour segmentation
    [fname pname] = uigetfile('*.mat', 'Load mat file containing saved contour');
    data = load(strcat(pname, fname));
    
    if isempty(OCT_cart) && ~isfield(data, 'OCT_cart')
        errordlg('Please load OCT pullback first', 'Load Error')
    elseif isempty(OCT_cart)
        OCT_cart = data.OCT_cart;
    end
    
    if isempty(OCT_polar) && isfield(data, 'OCT_polar')
        OCT_polar = double(data.OCT_polar);
        if isempty(OCT_gw)
            OCT_gw = OCT_polar;
        end
    end
    
    if isfield(data, 'OCT_contour_cart')
        OCT_contour_cart = data.OCT_contour_cart;
        OCT_lumen_contour  = contour2pol(OCT_contour_cart, OCT_polar, output_size);
    end
    
    if isfield(data, 'OCT_sheath')
        OCT_sheath = data.OCT_sheath;   
    end
    
    if ~isfield(GUI, 's1')
        create_slider()
    end
    update_display();
end

function save_seg(hObj, eventdata)
    % saves data
    fname = inputdlg('Enter filename');
    fname = strcat(fname, '_OCT_segmentation.mat');
    OCT_polar = uint16(OCT_polar);
    save(fname{1}, 'OCT_cart', 'OCT_polar', 'OCT_contour_cart', 'OCT_sheath', 'OCT_lumen_contour')
end

function copy_seg (hObj ,eventdata)
    % copy previous contour to the next image to save editing time
    OCT_contour_cart{GUI.OCT_image}=OCT_contour_cart{GUI.OCT_image - 1};
    OCT_lumen_contour(:, GUI.OCT_image) = OCT_lumen_contour(:, GUI.OCT_image - 1);
  
    cla(GUI.Ax1)
    cla(GUI.Ax2)
    imshow(OCT_cart(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax1)
    imshow(OCT_gw(:,:,GUI.OCT_image), [0 250], 'Parent', GUI.Ax2)
    set(GUI.Txt, 'string', strcat('Current Frame :', num2str(GUI.OCT_image)));
    plot(OCT_sheath(:,GUI.OCT_image), 1:length(OCT_polar(:, 1, 1)), 'Parent', GUI.Ax2)
    plot(OCT_contour_cart{GUI.OCT_image}(:, 1), OCT_contour_cart{GUI.OCT_image}(:, 2), 'Parent', GUI.Ax1)
    plot(OCT_lumen_contour(:, GUI.OCT_image), 1:length(OCT_polar(:, 1, 1)), 'Parent', GUI.Ax2)
    
end


end