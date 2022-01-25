clearvars
clc

bfr = BioformatsImage('D:\Projects\2019Aug Cameron CyAn\Data\20190702 tetO\teto_red50_xy0000.nd2');

iT = 40;
brightfield = getPlane(bfr, 1, 'Red', iT);
chlFluor = getPlane(bfr, 1, 'Cy5', iT);
mOrangeFluor = getPlane(bfr, 1, '555-mOrange', iT);
gfpFluor = getPlane(bfr, 1, 'GFP', iT);

CT = CyTracker;

%Make redSeg figure
CT.ChannelToSegment = 'Red';
CT.SegMode = 'redSeg';
CT.SeriesRange = 1;
CT.ImageReader = 'BioformatsImage';
CT.MaxCellMinDepth = 5;
CT.ThresholdLevel = 10;
CT.CellAreaLim = [300 2000];

mask = CT.getCellLabels(brightfield, CT.ThresholdLevel, CT.SegMode, CT.MaxCellMinDepth, CT.CellAreaLim);
figure(1);
showoverlay(chlFluor, bwperim(mask));

% %% Make fluorSeg figure
% CT.ChannelToSegment = '555-mOrange';
% CT.SegMode = 'fluorescence';
% CT.SeriesRange = 1;
% CT.ImageReader = 'nd2sdk';
% CT.MaxCellMinDepth = 5;
% CT.ThresholdLevel = 10;
% 
% 
% mask = CT.getCellLabels(mOrangeFluor, CT.ThresholdLevel, CT.SegMode, CT.MaxCellMinDepth, CT.CellAreaLim);
% imshow(mask)


%% Make dot figure
opts.SpotSegMode = 'dog';
opts.SpotErodePx = 7;
opts.DoGSpotDiameter = 3;
opts.SpotThreshold = 4;
opts.MinSpotArea = 4;

spotMask = CT.segmentSpots(gfpFluor, mask, opts);
figure(2);
showoverlay(gfpFluor, spotMask, 'Opacity', 30)

