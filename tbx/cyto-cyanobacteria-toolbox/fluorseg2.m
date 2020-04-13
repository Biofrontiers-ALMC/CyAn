function mask = fluorseg2(I, opts)

T = adaptthresh(I, 0.5, 'NeighborhoodSize', 31, 'Statistic', 'Gaussian');
mask = imbinarize(I, T);
mask = imclearborder(mask);
mask = bwareaopen(mask, 200);
mask = imopen(mask, strel('disk', 3));

dd = -bwdist(~mask);
dd(~mask) = -Inf;
dd = imhmin(dd, 1);
LL = watershed(dd);

mask(LL == 0) = 0;
mask = imfill(mask, 'holes');

mask = bwareaopen(mask, 100);

end