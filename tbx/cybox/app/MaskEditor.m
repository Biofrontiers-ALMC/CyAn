classdef MaskEditor < handle
    
    properties (Hidden)
        
        handles_
        
        baseImgPath
        baseImgReader
        
        baseImgData
        baseImgHandle
        
        maskPath
        maskData
        maskHandle
        
        lastPt
        
    end
    
    methods
        
        function obj = MaskEditor
            
            obj.handles_ = guihandles(editorFig);
            
            set(obj.handles_.mnuLoadImage, 'callback', @(src, event) loadImage(obj, src, event));
            
            set(obj.handles_.mnuLoadMask, 'callback', @(src, event) loadMask(obj, src, event));
            set(obj.handles_.mnuSaveAsMask, 'callback', @(src, event) saveMask(obj, src, event));
            set(obj.handles_.mnuOverwriteMask, 'callback', @(src, event) saveMask(obj, src, event));
            
            set(obj.handles_.mnuDrawCapsules, 'callback', @(src, event) drawCapsules(obj, src, event));
            
            set(obj.handles_.sldZPos,  'callback', @(src,event) updateSlider(obj, src, event));
            set(obj.handles_.sldChannel,  'callback', @(src,event) updateSlider(obj, src, event));
            set(obj.handles_.sldTime,  'callback', @(src,event) updateSlider(obj, src, event));
            
            set(obj.handles_.txtZPos,  'callback', @(src,event) updateTxt(obj, src, event));
            set(obj.handles_.txtChannel,  'callback', @(src,event) updateTxt(obj, src, event));
            set(obj.handles_.txtTime,  'callback', @(src,event) updateTxt(obj, src, event));
            
            set(obj.handles_.figure1,  'closerequestfcn', @(src,event) closeFcn(obj, src, event));
            
            set(obj.handles_.uiPaintTool, 'OnCallback', @(src, event) togglePencil(obj, src, event));
            set(obj.handles_.uiPaintTool, 'OffCallback', @(src, event) togglePencil(obj, src, event));
        end
        
    end
    
    methods (Access = private)
        
        function loadImage(obj, src, events)
            
            [fname, fpath, indx] = uigetfile({'*.nd2', 'Nikon Image Files (*.nd2)';...
                '*.tif; *.tiff', 'TIFF stacks (*.tif; *.tiff)'},'Select Image File');
            
            if fname == 0
                return;
            end
            
            obj.baseImgPath = fullfile(fpath, fname);
            
            switch indx
                
                case 1
                    obj.baseImgReader = BioformatsImage(fullfile(fpath, fname));
                    
                    %Set the slider properties
                    obj.handles_.sldZPos.Min = 1;
                    obj.handles_.sldZPos.Max = obj.baseImgReader.sizeZ;
                    if obj.handles_.sldZPos.Max > 1
                        obj.handles_.sldZPos.SliderStep = [1/(obj.handles_.sldZPos.Max-1) 10/(obj.handles_.sldZPos.Max-1)];
                        obj.handles_.sldZPos.Enable = 'on';
                    else
                        obj.handles_.sldZPos.SliderStep = [1 1];
                        obj.handles_.sldZPos.Enable = 'off';
                    end
                    obj.handles_.sldZPos.Value = 1;
                    obj.handles_.txtTime.String = 1;
                    obj.handles_.txtTime.Enable = 'on';
                    obj.handles_.txtSizeZ.String = sprintf('of %d', obj.handles_.sldZPos.Max);
                    
                    obj.handles_.sldChannel.Min = 1;
                    obj.handles_.sldChannel.Max = obj.baseImgReader.sizeC;
                    if obj.handles_.sldChannel.Max > 1
                        obj.handles_.sldChannel.SliderStep = [1/(obj.handles_.sldChannel.Max -1) 10/(obj.handles_.sldChannel.Max-1)];
                        obj.handles_.sldChannel.Enable = 'on';
                    else
                        obj.handles_.sldChannel.SliderStep = [1, 1];
                        obj.handles_.sldChannel.Enable = 'off';
                    end
                    obj.handles_.sldChannel.Value = 1;
                    obj.handles_.txtChannel.String = 1;
                    obj.handles_.txtChannel.Enable = 'on';
                    obj.handles_.txtSizeC.String = sprintf('of %d', obj.handles_.sldChannel.Max);
                    
                    obj.handles_.sldTime.Min = 1;
                    obj.handles_.sldTime.Max = obj.baseImgReader.sizeT;
                    if obj.handles_.sldTime.Max > 1
                        obj.handles_.sldTime.SliderStep = [1/(obj.handles_.sldTime.Max-1) 10/(obj.handles_.sldTime.Max-1)];
                        obj.handles_.sldTime.Enable = 'on';
                    else
                        obj.handles_.sldTime.SliderStep = [1. 1];
                        obj.handles_.sldTime.Enable = 'off';
                    end
                    obj.handles_.sldTime.Value = 1;
                    obj.handles_.txtZPos.String = 1;
                    obj.handles_.txtZPos.Enable = 'on';
                    obj.handles_.txtSizeT.String = sprintf('of %d', obj.handles_.sldTime.Max);
                    
            end
            
            %Enable the Mask menu
            obj.handles_.mnuMask.Enable = 'on';
            
            updateImage(obj, src, events);
            
        end
        
        function loadMask(obj, src, events)
            
            [fname, fpath] = uigetfile({ '*.tif; *.tiff', 'TIFF stacks (*.tif; *.tiff)'},'Select Mask File');
            
            if fname == 0
                return;
            end
            
            obj.maskPath = fullfile(fpath, fname);
            
            maskFinfo = imfinfo(obj.maskPath);
            
            obj.maskData = false(maskFinfo(1).Height,maskFinfo(1).Width, obj.handles_.sldTime.Max);
            for iT = 1:numel(maskFinfo)
                obj.maskData(:,:,iT) = imread(obj.maskPath, iT);
            end
            
            updateImage(obj);
            
            %Change the menu item description
            obj.handles_.mnuOverwriteMask.Text = ['Overwrite ', fname];
            
            %Enable the save menu items
            obj.handles_.mnuOverwriteMask.Enable = 'on';
            obj.handles_.mnuSaveAsMask.Enable = 'on';
            
            obj.handles_.mnuFunctions.Enable = 'on';
        end
        
        function updateImage(obj, src, events)
            
            obj.baseImgData = obj.baseImgReader.getPlane(obj.handles_.sldZPos.Value,...
                obj.handles_.sldChannel.Value,...
                obj.handles_.sldTime.Value);
            
            obj.baseImgHandle = imshow(obj.baseImgData, [],  'Parent', obj.handles_.axes1);
            
            hold on
            maskColor = cat(3, zeros(size(obj.baseImgData)), ...
                ones(size(obj.baseImgData)), zeros(size(obj.baseImgData)));
            
            obj.maskHandle = imshow(maskColor, 'Parent', obj.handles_.axes1);
            
            if ~isempty(obj.maskData)
                mask = obj.maskData(:,:,obj.handles_.sldTime.Value);
            else
                mask = false(size(obj.baseImgData));
            end
            set(obj.maskHandle, 'AlphaData', mask);
            hold off
        end
        
        function delete(obj)
            %class deconstructor - handles the cleaning up of the class &
            %figure. Either the class or the figure can initiate the closing
            %condition, this function makes sure both are cleaned up
            
            %remove the closerequestfcn from the figure, this prevents an
            %infitie loop with the following delete command
            set(obj.handles_.figure1,  'closerequestfcn', '');
            %delete the figure
            delete(obj.handles_.figure1);
            %clear out the pointer to the figure - prevents memory leaks
            obj.handles_ = [];
        end
        
        function obj = closeFcn(obj, src, event)
            delete(obj);
        end
        
        function updateSlider(obj, src, event)
            
            %Round to nearest slider value
            src.Value = floor(src.Value);
            
            switch src.Tag
                
                case 'sldTime'
                    
                    %Update the text box
                    obj.handles_.txtTime.String = src.Value;
                    
                case 'sldChannel'
                    
                    %Update the text box
                    obj.handles_.txtChannel.String = src.Value;
                    
                case 'sldZPos'
                    
                    %Update the text box
                    obj.handles_.txtZPos.String = src.Value;
            end
            
            
            %Update image
            updateImage(obj);
            
        end
        
        function updateTxt(obj, src, event)
            
            %Validate the functions
            switch src.Tag
                
                case 'txtZPos'
                    validMax = obj.handles_.sldZPos.Max;
                    oldValue = obj.handles_.sldZPos.Value;
                    
                case 'txtChannel'
                    validMax = obj.handles_.sldChannel.Max;
                    oldValue = obj.handles_.sldChannel.Value;
                    
                case 'txtTime'
                    validMax = obj.handles_.sldTime.Max;
                    oldValue = obj.handles_.sldTime.Value;
                    
            end
            
            newValue = str2double(src.String);
            if newValue ~= oldValue
                %Only make change if the value has changed
                
                if newValue < 1
                    newValue = 1;
                elseif newValue > validMax
                    newValue = validMax;
                end
                
                %Make sure values are round
                newValue = floor(newValue);
                
                %Update the sliders
                switch src.Tag
                    
                    case 'txtZPos'
                        obj.handles_.sldZPos.Value = newValue;
                        obj.handles_.txtZPos.String = newValue;
                        
                    case 'txtChannel'
                        obj.handles_.sldChannel.Value = newValue;
                        obj.handles_.txtChannel.String = newValue;
                        
                    case 'txtTime'
                        obj.handles_.sldTime.Value = newValue;
                        obj.handles_.txtTime.String = newValue;
                        
                end
                
                updateImage(obj);
            end
            
            
            
            
        end
        
        function startDrawing(obj, src, event)
            
            if ~isempty(obj.maskData)
                %Update the drawing
                draw(obj);
                
                %Start drawing if mouse is still down
                set(obj.handles_.figure1, 'WindowButtonMotionFcn', @(src, events) draw(obj, src, events));
            end
            
        end
        
        function draw(obj, src, events)
            
            %Get mouse coordinates relative to the axes/figure position
            C = get(obj.handles_.axes1, 'CurrentPoint');
            
            %Check that mouse is within the image area
            xlim = get(obj.handles_.axes1, 'xlim');
            ylim = get(obj.handles_.axes1, 'ylim');
            
            inX = C(1,1) >= xlim(1) && C(1,1) <= xlim(2);
            inY = C(1,2) >= ylim(1) && C(1,2) <= ylim(2);
            
            if inX && inY
                
                if ~isempty(obj.lastPt)
                    
                    %Interpolate the data based on the end points
                    
                   [drawX, drawY] = bresenham(obj.lastPt(1), obj.lastPt(2), C(1,1), C(1,2));
                                        
%                     xx = floor([obj.lastPt(1), C(1,1)]);
%                     yy = floor([obj.lastPt(2), C(1,2)]);
%                     
%                     %Another solution is to only interpolate the largest
%                     %difference
%                     if diff(xx) > diff(yy)
%                         
%                         drawX = floor(linspace(floor(obj.lastPt(1)),floor(C(1,1)),...
%                             abs(floor(obj.lastPt(1)) - floor(C(1,1)))));
%                         
%                         if numel(drawX) > 1
%                             drawY = floor(interp1(xx,yy,drawX,'linear'));
%                         else
%                             drawX = floor(C(1,1));
%                             drawY = floor(C(1,2));
%                         end
%                         
%                     else
%                         drawY = floor(linspace(floor(obj.lastPt(2)),floor(C(1,2)),...
%                             abs(floor(obj.lastPt(2)) - floor(C(1,2)))));
%                         
%                         if numel(drawY) > 1
%                             drawX = floor(interp1(yy,xx,drawY,'linear'));
%                         else
%                             drawX = floor(C(1,1));
%                             drawY = floor(C(1,2));
%                         end
%                     end
     
                else
                    
                    %Only select the current pixel
                    drawX = floor(C(1,1));
                    drawY = floor(C(1,2));
                    
                end
                
                try
                switch get(gcf, 'selectiontype')
                    case 'normal'
                        obj.maskData(drawY, drawX, obj.handles_.sldTime.Value) = true;
                        
                    case 'alt'
                        obj.maskData(drawY, drawX, obj.handles_.sldTime.Value) = false;
                end
                
                obj.lastPt = [drawX(end), drawY(end)];
                
                catch
                    disp(drawX)
                    disp(drawY)
                    
                end
                
                %Update the drawing
                set(obj.maskHandle, 'AlphaData', obj.maskData(:,:, obj.handles_.sldTime.Value));
                
            else
                disp('Outside image')
                obj.lastPt = [];
            end
            
%             pause(0.1);
            function [x, y] = bresenham(x1,y1,x2,y2)
                
                %Matlab optmized version of Bresenham line algorithm. No loops.
                %Format:
                %               [x y]=bham(x1,y1,x2,y2)
                %
                %Input:
                %               (x1,y1): Start position
                %               (x2,y2): End position
                %
                %Output:
                %               x y: the line coordinates from (x1,y1) to (x2,y2)
                %
                %Usage example:
                %               [x y]=bham(1,1, 10,-5);
                %               plot(x,y,'or');
                
                x1=round(x1); x2=round(x2);
                y1=round(y1); y2=round(y2);
                
                dx=abs(x2-x1);
                dy=abs(y2-y1);
                
                steep=abs(dy)>abs(dx);
                
                if steep
                    t=dx;
                    dx=dy;
                    dy=t;
                end
                
                %The main algorithm goes here.
                if dy==0
                    q=zeros(dx+1,1);
                else
                    q=[0;diff(mod((floor(dx/2):-dy:-dy*dx+floor(dx/2))',dx))>=0];
                end
                
                %and ends here.
                
                if steep
                    if y1<=y2
                        y=(y1:y2)';
                    else
                        y=(y1:-1:y2)';
                    end
                    if x1<=x2
                        x=x1+cumsum(q);
                    else
                        x=x1-cumsum(q);
                    end
                else
                    if x1<=x2
                        x=(x1:x2)';
                    else
                        x=(x1:-1:x2)';
                    end
                    if y1<=y2
                        y=y1+cumsum(q);
                    else
                        y=y1-cumsum(q);
                    end
                end
            end
          
        end
                
        function stopDrawing(obj,src, event)
            
            set(obj.handles_.figure1, 'WindowButtonMotionFcn', '');
            obj.lastPt = [];            
            
        end
        
        function saveMask(obj, src, event)
            
            switch src.Tag
                
                case 'mnuSaveAsMask'
                    
                    [maskFN, maskP] = uiputfile({'*.tif; *.tiff','TIF stack (*.tif; *.tiff)'},...
                        'Save Mask As...');
                    
                    if maskFN == 0
                        return;                        
                    end
                
                    maskFN = fullfile(maskP, maskFN);
                
                case 'mnuOverwriteMask'
                    maskFN = obj.maskPath;
                
            end
            
            imwrite(obj.maskData(:,:,1),maskFN,'compression','none');
            
            for iT = 2:size(obj.maskData,3)
                imwrite(obj.maskData(:,:,iT),maskFN,'compression','none', 'writemode','append');                
            end
            
            %Update the current mask path
            obj.maskPath = maskFN;
            
            
        end
        
        function drawCapsules(obj, src, event)
            
            %Get current data
            
            currMask = obj.maskData(:,:,obj.handles_.sldTime.Value);
            
            currMask = bwmorph(currMask, 'skel');
            
            props = regionprops(currMask,'MajorAxisLength','MinorAxisLength','Centroid','Orientation');
            
            %--- Draw code ---%
            imgOut = zeros(size(obj.maskData(:,:,obj.handles_.sldTime.Value)));
            
            xx = 1:size(imgOut, 2);
            yy = 1:size(imgOut, 1);
            
            [xx, yy] = meshgrid(xx,yy);
            
            for ii = 1:numel(props)
                
                center = props(ii).Centroid;
                theta = props(ii).Orientation/180 * pi;
                cellLen = floor(props(ii).MajorAxisLength);
                cellWidth = floor(props(ii).MinorAxisLength);
                
                rotX = (xx - center(1)) * cos(theta) - (yy - center(2)) * sin(theta);
                rotY = (xx - center(1)) * sin(theta) + (yy - center(2)) * cos(theta);
                
                %Plot the rectangle
                imgOut(abs(rotX) < (cellLen/2 - cellWidth/2) & abs(rotY) < cellWidth/2) = ii;
                
                % %Plot circles on either end
                imgOut(((rotX-(cellLen/2 - cellWidth/2)).^2 + rotY.^2) < (cellWidth/2)^2 ) = ii;
                imgOut(((rotX+(cellLen/2 - cellWidth/2)).^2 + rotY.^2) < (cellWidth/2)^2 ) = ii;
                
            end
            
            obj.maskData(:,:,obj.handles_.sldTime.Value) = imgOut;
            updateImage(obj);
            
        end
        
        function togglePencil(obj, src, event)
           
            switch event.EventName
                
                case 'On'
                    
                    set(obj.handles_.figure1,  'WindowButtonDownFcn', @(src, event) startDrawing(obj, src, event));
                    set(obj.handles_.figure1, 'WindowButtonUpFcn', @(src, event) stopDrawing(obj, src, event));
                    
                case 'Off'
                    
                    set(obj.handles_.figure1,  'WindowButtonDownFcn', '');
                    set(obj.handles_.figure1, 'WindowButtonUpFcn', '');
            end
        end
    end
    
    
end