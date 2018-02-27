function imgOut = drawCylinder(imgIn, props)

imgOut = zeros(size(imgIn));

xx = 1:size(imgOut, 2);
yy = 1:size(imgOut, 1);

[xx, yy] = meshgrid(xx,yy);

for ii = 1:numel(props)
    
    center = props(ii).Centroid;
    theta = props(ii).Orientation/180 * pi;
    cellLen = props(ii).MajorAxisLength;
    cellWidth = props(ii).MinorAxisLength;
    
    rotX = (xx - center(1)) * cos(theta) - (yy - center(2)) * sin(theta);
    rotY = (xx - center(1)) * sin(theta) + (yy - center(2)) * cos(theta);
    
    %Plot the rectangle
    imgOut(abs(rotX) < (cellLen/2 - cellWidth/2) & abs(rotY) < cellWidth/2) = ii;
    
    % %Plot circles on either end
    imgOut(((rotX-(cellLen/2 - cellWidth/2)).^2 + rotY.^2) < (cellWidth/2)^2 ) = ii;
    imgOut(((rotX+(cellLen/2 - cellWidth/2)).^2 + rotY.^2) < (cellWidth/2)^2 ) = ii;
    
end

% imshow(imgOut);


end