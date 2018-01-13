function imC = Polar2Im(imP,W,method)

%Polar2Im turns a polar image (imP) into a cartesian image (imC) of width W
%method can be: '*linear', '*cubic', '*spline', or '*nearest'. The input
%image should have the depth on the y axis and the angle on the x axis

imP(isnan(imP))=0;
% determine image radius
w = round(W/2);

% set pixels
xy = (1:W-w);

% get image size
[M N P]= size(imP);
% create meshgrid in cartesian coordinates
[x y] = meshgrid(xy, xy);

% determine first quadrant end location
n = round(N/4);

% create cartesian values for radial image
rr = linspace(1,w,M);
% W1 is the left side of the image cartesian coordinates
W1 = w:-1:1;
PM = [2 1 3;1 2 3;2 1 3;1 2 3];

% W2 is the right side of the image cartesian coordinates
W2 = w+1:2*w;
% define the full quadrants of the input image
nn = [1:n; n+1:2*n; 2*n+1:3*n; 3*n+1:N;];

% for the defined quadrants define corresponding cartesian coordinates
w1 = [W1;W2;W2;W1];
w2 = [W2;W2;W1;W1];

% define incremental increase for each quadrant
aa = linspace(0,90*pi/180,n);
% create radial image beginning from (1,1)
r = sqrt(x.^2 + y.^2);
% create corresponding angle image
a = atan2(y,x);
% pre-allocate memory
imC = zeros(W,W,P);

%turn each quadrant into a cartesian image
for i=1:4
    imC(w1(i,:),w2(i,:),:) = permute(interp2(rr,aa,imP(:,nn(i,:))',r,a,method),PM(i,:));
end

imC(isnan(imC))=0;