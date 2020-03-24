function mask = fluorseg(I, opts)

T = adaptthresh(I, 0.8, 'NeighborhoodSize', 41);
mask = imbinarize(I, T);
mask = imclearborder(mask);
mask = bwareaopen(mask, 200);
mask = imopen(mask, strel('disk', 3));

dd = -bwdist(~mask);
dd(~mask) = -Inf;
dd = imhmin(dd, 1);
LL = watershed(dd);

mask(LL == 0) = 0;
mask = bwareaopen(mask, 100);

end