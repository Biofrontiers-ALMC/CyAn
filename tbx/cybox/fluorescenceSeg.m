function LL = fluorescenceSeg(I, opts)
keyboard
mask = I > max(I(:))/ opts.thFactor;
mask = bwareaopen(mask, 300);

mask = imopen(mask, strel('disk', 10));

dd = imcomplement(double(medfilt2(I, [10 10])));
dd(~mask) = -Inf;
dd = imhmin(dd, 50);

LL = watershed(dd);
LL = LL - 1;

%Redraw the masks using cylinders
% rpCells = regionprops(LL,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
% LL = CyTracker.drawCapsule(size(LL), rpCells);

end
