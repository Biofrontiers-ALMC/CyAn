function LL = bulkSeg(cellImage, opts)
%BULKSEG is a simplified version of segmentation derived from
%'nicksversion'. It should be used for single images of cells (from bulk
%experiments), and not for movies.


%Pre-process the brightfield image: median filter and
%background subtraction
cellImageTemp = double(medfilt2(cellImage,[3 3]));

bgImage = imopen(cellImageTemp, strel('disk', 40));
cellImageTemp = cellImageTemp - bgImage;

%Fit the background
[nCnts, xBins] = histcounts(cellImageTemp(:), 100);
nCnts = smooth(nCnts, 3);
xBins = diff(xBins) + xBins(1:end-1);

%Find the peak background
[bgPk, bgPkLoc] = max(nCnts);

%Find point where counts drop to fraction of peak
thLoc = find(nCnts(bgPkLoc:end) <= bgPk * opts.thFactor, 1, 'first');
thLoc = thLoc + bgPkLoc;

thLvl = xBins(thLoc);

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

%Filter out all objects with low StDev
maskCC = bwconncomp(mask);

stdBG = std(cellImageTemp(~mask));

for iObj = 1:maskCC.NumObjects
    
    stdObj = std(cellImageTemp(maskCC.PixelIdxList{iObj}));
    
    if stdObj < 5 * stdBG
        mask(maskCC.PixelIdxList{iObj}) = 0;
    end
end


%Redraw the masks using cylinders
rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});

%Remove cells which are too small or too large
rpCells(([rpCells.Area] < min(opts.cellAreaLim)) | ([rpCells.Area] > max(opts.cellAreaLim))) = [];

LL = CyTracker.drawCapsule(size(mask), rpCells);




% % % % % % % % % keyboard
% % % % % % % % % %Pre-process the brightfield image: median filter and
% % % % % % % % % %background subtraction
% % % % % % % % % cellImage = double(cellImage);
% % % % % % % % % 
% % % % % % % % % bgImage = imopen(cellImage, strel('disk', 40));
% % % % % % % % % cellImageTemp = cellImage - bgImage;
% % % % % % % % % cellImageTemp = imgaussfilt(cellImageTemp, 2);
% % % % % % % % % 
% % % % % % % % % %Fit the background
% % % % % % % % % [nCnts, xBins] = histcounts(cellImageTemp(:), 100);
% % % % % % % % % nCnts = smooth(nCnts, 3);
% % % % % % % % % xBins = diff(xBins) + xBins(1:end-1);
% % % % % % % % % 
% % % % % % % % % %Find the peak background
% % % % % % % % % [bgPk, bgPkLoc] = max(nCnts);
% % % % % % % % % 
% % % % % % % % % %Find point where counts drop to fraction of peak
% % % % % % % % % thLoc = find(nCnts(bgPkLoc:end) <= bgPk * opts.thFactor, 1, 'first');
% % % % % % % % % thLoc = thLoc + bgPkLoc;
% % % % % % % % % thLvl = xBins(thLoc);
% % % % % % % % % 
% % % % % % % % % %Compute initial cell mask
% % % % % % % % % mask = cellImageTemp > thLvl;
% % % % % % % % % mask = imopen(mask, strel('disk', 3));
% % % % % % % % % mask = imclose(mask, strel('disk', 3));
% % % % % % % % % mask = imerode(mask, ones(1));
% % % % % % % % % 
% % % % % % % % % %Separate the cell clumps using watershedding
% % % % % % % % % dd = -bwdist(~mask);
% % % % % % % % % dd(~mask) = -Inf;
% % % % % % % % % dd = imhmin(dd, opts.maxCellminDepth);
% % % % % % % % % LL = watershed(dd);
% % % % % % % % % mask(LL == 0) = 0;
% % % % % % % % % 
% % % % % % % % % %Tidy up
% % % % % % % % % mask = imclearborder(mask);
% % % % % % % % % mask = bwareaopen(mask, 100);
% % % % % % % % % mask = bwmorph(mask,'thicken', 8);
% % % % % % % % % 
% % % % % % % % % %Filter out all objects with low StDev
% % % % % % % % % maskCC = bwconncomp(mask);
% % % % % % % % % keyboard
% % % % % % % % % stdBG = std(cellImageTemp(~mask));
% % % % % % % % % 
% % % % % % % % % for iObj = 1:maskCC.NumObjects
% % % % % % % % %     
% % % % % % % % %     stdObj = std(cellImageTemp(maskCC.PixelIdxList{iObj}));
% % % % % % % % %     
% % % % % % % % %     if stdObj < 3 * stdBG
% % % % % % % % %         mask(maskCC.PixelIdxList{iObj}) = 0;
% % % % % % % % %     end
% % % % % % % % % end
% % % % % % % % % 
% % % % % % % % % %Redraw mask as cylinders
% % % % % % % % % rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
% % % % % % % % % LL = CyTracker.drawCapsule(size(mask), rpCells);




end

