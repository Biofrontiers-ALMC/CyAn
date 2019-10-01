function labels = brightfield (cellImage, opts)

%Pre-process the brightfield image: median filter and
%background subtraction
cellImageTemp = double(medfilt2(cellImage,[3 3]));

bgImage = imopen(cellImageTemp, strel('disk', 40));
cellImageTemp = cellImageTemp - bgImage;

%Fit the background
[nCnts, xBins] = histcounts(cellImageTemp(:), 150);
xBins = diff(xBins) + 0.5 * xBins(1:end-1);

gf = fit(xBins', nCnts', 'gauss1');

%Compute the threshold level
thLvl = gf.b1 + opts.thFactor * gf.c1;

%Compute initial cell mask
mask = cellImageTemp > thLvl;

mask = imfill(mask, 'holes');
mask = imopen(mask, strel('disk', 3));
mask = imclose(mask, strel('disk', 3));

mask = imerode(mask, ones(1));

%Separate the cell clumps using watershedding
dd = -bwdist(~mask);
dd(~mask) = -Inf;
dd = imhmin(dd, opts.maxCellminDepth);

LL = watershed(dd);
mask(LL == 0) = 0;

%Tidy up
mask = imclearborder(mask);
mask = bwmorph(mask,'thicken', 8);

%Redraw the masks using cylinders
rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});

%Remove cells which are too small or too large
rpCells(([rpCells.Area] < min(opts.cellAreaLim)) | ([rpCells.Area] > max(opts.cellAreaLim))) = [];

labels = CyTracker.drawCapsule(size(mask), rpCells);

end