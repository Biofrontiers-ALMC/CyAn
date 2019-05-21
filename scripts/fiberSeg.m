bfr = BioformatsImage('D:\Jian\Documents\Projects\CameronLab\Datasets\NickHill\Publication\20180715_N2P122_ccmOp+Washout\seq0002_xy1_crop.nd2');

% vid = VideoWriter('testSeg2.avi');
% vid.Quality = 100;
% vid.FrameRate = 20;
% open(vid)
for iT = 1%:bfr.sizeT
    
    I = getPlane(bfr, 1, 1, 100);
    M = fibermetric(I);
    
    M = M > 0.10;
    %M = imerode(M, strel('disk', 2));
    M = bwareaopen(M, 50); 
    %M = bwmorph(M, 'majority');
    %marker = imopen(M, strel('disk', 3));
    %imshow(marker)
    
    M = ~M;
    M = imclearborder(M);
    M = bwareaopen(M, 50); 
    M = imfill(M, 'holes');
    M = bwmorph(M, 'diag');
    
    M = imclose(M, strel('disk', 1));
    
    I = double(I);
    Iout = showoverlay(I, M);
    %Iout = [Iout, zeros(size(I, 1), 5, 3), repmat(I./max(I(:)), 1, 1, 3)];
    
    imshow(Iout)
    %keyboard
    
%     writeVideo(vid, Iout);
        
end
% close(vid)