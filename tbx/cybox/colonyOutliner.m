function LL = colonyOutliner(cellImage, opts)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

%Threshold
% cellImage = double(medfilt2(cellImage,[3 3]));
% cellImage = imsharpen(cellImage,'Amount', 2);

%Get a threshold
[nCnts, binEdges] = histcounts(cellImage(:),linspace(0, double(max(cellImage(:))), 150));
binCenters = diff(binEdges) + binEdges(1:end-1);

%Find the peak background
[bgPk, bgPkLoc] = max(nCnts);

%Find point where counts drop to fraction of peak
thLoc = find(nCnts(bgPkLoc:end) <= bgPk * 1000, 1, 'first'); %Set thFactor
thLoc = thLoc + bgPkLoc;

thLvl = binCenters(thLoc);
keyboard
mask = cellImage > thLvl;
mask = bwareaopen(mask, 1000);
mask = bwmorph(mask, 'spur');
mask = bwmorph(mask, 'bridge');
mask = imfill(mask, 'holes');
mask = imopen(mask, strel('disk', 7));
LL = bwareaopen(mask, 1000);
% mask = activecontour(cellImage, mask);

% mask = bwmorph(mask, 'clean');
% mask = imclose(mask, strel('disk', 3));
% mask = imopen(mask, strel('disk', 3));
% LL = bwmorph(mask, 'thicken');

end

