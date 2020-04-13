function labels = bfseg(cellImage, opts)
    
    I = cellImage(:, :, 1);
    I_cy5 = cellImage(:, :, 2);
    
    bg = medfilt2(I, [50 50]);
    
    meanBG = mean(bg(bg > 0));
    
    mask = I < meanBG * 0.95;
    
    mask = imopen(mask, strel('disk', 3));
    mask = imfill(mask, 'holes');
    mask = bwareaopen(mask, min(opts.cellAreaLim));
    
%     I_cy5 = imgaussfilt(I_cy5, 2);
%     I_cy5 = imopen(I_cy5, strel('disk', 8));
%     
%     exMax = imextendedmax(I_cy5, 7, 8);
    
    dd = -bwdist(~mask);
    dd = imhmin(dd, 1);
    %dd = imimposemin(dd, exMax);
    LL = watershed(dd);
    
    labels = mask;
    labels(LL == 0) = 0;
    
end