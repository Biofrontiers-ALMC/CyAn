classdef MaskEditor < handle
    
    properties
        
        handles_
        
        baseImgPath
        baseImgReader
        
        baseImgData
        
        maskPath
        maskData
        
        isDrawing = false;
        
    end
    
    methods
        
        function obj = MaskEditor
            
            obj.handles_ = guihandles(editorFig);
            
            set(obj.handles_.mnuLoadImage, 'callback', @(src, event) loadImage(obj, src, event));
            set(obj.handles_.mnuLoadMask, 'callback', @(src, event) loadMask(obj, src, event));
                        
            set(obj.handles_.sldZPos,  'callback', @(src,event) updateSlider(obj, src, event));
            set(obj.handles_.sldChannel,  'callback', @(src,event) updateSlider(obj, src, event));
            set(obj.handles_.sldTime,  'callback', @(src,event) updateSlider(obj, src, event));
            
            set(obj.handles_.txtZPos,  'callback', @(src,event) updateTxt(obj, src, event));
            set(obj.handles_.txtChannel,  'callback', @(src,event) updateTxt(obj, src, event));
            set(obj.handles_.txtTime,  'callback', @(src,event) updateTxt(obj, src, event));
            
            set(obj.handles_.figure1,  'closerequestfcn', @(src,event) closeFcn(obj, src, event));
            
            set(obj.handles_.figure1,  'WindowButtonDownFcn', @(src, event) startDrawing(obj, src, event));
            set(obj.handles_.figure1, 'WindowButtonUpFcn', @(src, event) stopDrawing(obj, src, event));
            
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
            for iZ = 1:numel(maskFinfo)
                obj.maskData(:,:,iZ) = imread(obj.maskPath, iZ);                
            end
            
            updateImage(obj);
            
        end
        
        function updateImage(obj, src, events)
            
            obj.baseImgData = obj.baseImgReader.getPlane(obj.handles_.sldZPos.Value,...
                obj.handles_.sldChannel.Value,...
                obj.handles_.sldTime.Value);
            
            if ~isempty(obj.baseImgData)
                if ~isempty(obj.maskData)
                    mask = obj.maskData(:,:,obj.handles_.sldTime.Value);
                else
                    mask = false(size(obj.baseImgData));
                end
                
                img = MaskEditor.showoverlay(obj.baseImgData, mask);
                imshow(img, [], 'Parent', obj.handles_.axes1);
            end
            
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
                %Start drawing
                set(obj.handles_.figure1, 'WindowButtonMotionFcn', @(src, events) draw(obj, src, events));
            end
            
        end
        
        function draw(obj, src, events)
            
            %Check if mouse is in axes position
            
            %This returns the mouse coordinates relative to the axes/figure
            %position
            C = get(obj.handles_.axes1, 'CurrentPoint');
            
            xlim = get(obj.handles_.axes1, 'xlim');
            ylim = get(obj.handles_.axes1, 'ylim');
            
            inX = C(1,1) >= xlim(1) && C(1,1) <= xlim(2);
            inY = C(1,2) >= ylim(1) && C(1,2) <= ylim(2);
            
            if inX && inY
                %I think this assignment is wrong
                
                obj.maskData(floor(C(1,2)) + 1, floor(C(1,1)) + 1, obj.handles_.sldTime.Value) = true;
                %disp(obj.maskData(floor(C(1,2)) + 1, floor(C(1,1)) + 1, obj.handles_.sldTime.Value))
            else
                disp('false')
            end
            
            img = MaskEditor.showoverlay(obj.baseImgData, obj.maskData(:,:, obj.handles_.sldTime.Value));
            imshow(img, 'Parent', obj.handles_.axes1);
            
%             pause(0.1);
            %                 keyboard
        end
        
        
        function stopDrawing(obj,src, event)
            
            set(obj.handles_.figure1, 'WindowButtonMotionFcn', '');
            
            
%             keyboard
            
        end
        
    end
    
    methods (Static)
        
        function varargout = showoverlay(img, mask, varargin)
            %SHOWOVERLAY  Overlays a mask on to a base image
            %
            %  SHOWOVERLAY(I, M) will overlay mask M over the image I, displaying it in
            %  a figure window.
            %
            %  C = SHOWOVERLAY(I, M) will return the composited image as a matrix
            %  C. This allows multiple masks to be composited over the same image. C
            %  should be of the same class as the input image I. However, if the input
            %  image I is a double, the output image C will be normalized to between 0
            %  and 1.
            %
            %  Optional parameters can be supplied to the function to modify both the
            %  color and the transparency of the masks:
            %
            %     'Color' - 1x3 vector specifying the color of the overlay in
            %               normalized RGB coordinates (e.g. [0 0 1] = blue)
            %
            %     'Opacity' - Value between 0 - 100 specifying the alpha level of
            %                      the overlay
            %
            %  Examples:
            %
            %    %Load a test image
            %    testImg = imread('cameraman.tif');
            %
            %    %Generate a masked region
            %    maskIn = false(size(testImg));
            %    maskIn(50:70,50:200) = true;
            %
            %    %Store the image to a new variable
            %    imgOut = SHOWOVERLAY(testImg, maskIn);
            %
            %    %Generate a second mask
            %    maskIn2 = false(size(testImg));
            %    maskIn2(100:180, 50:100) = true;
            %
            %    %Composite and display the second mask onto the same image as a
            %    %magenta layer with 50% transparency
            %    SHOWOVERLAY(imgOut, maskIn2, 'Color', [1 0 1], 'Transparency', 50);
            
            % Author: Jian Wei Tay (jian.tay@colorado.edu)
            % Version 2018-Feb-01
            
            ip = inputParser;
            ip.addParameter('Color',[0 1 0]);
            ip.addParameter('Opacity',100);
            ip.parse(varargin{:});
            
            alpha = ip.Results.Opacity / 100;
            
            %Get the original image class
            imageClass = class(img);
            imageIsInteger = isinteger(img);
            
            %Process the input image
            img = double(img);
            img = img ./ max(img(:));
            
            if size(img,3) == 1
                %Convert into an RGB image
                img = repmat(img, 1, 1, 3);
            elseif size(img,3) == 3
                %Do nothing
            else
                error('showoverlay:InvalidInputImage',...
                    'Expected input to be either a grayscale or RGB image.');
            end
            
            %Process the mask
            if any(mask(:))
                mask = double(mask);
                mask = mask ./ max(mask(:));
                
                if size(mask,3) == 1
                    %Convert mask into an RGB image
                    mask = repmat(mask, 1, 1, 3);
                    
                    for iC = 1:3
                        mask(:,:,iC) = mask(:,:,iC) .* ip.Results.Color(iC);
                    end
                elseif size(mask,3) == 3
                    %Do nothing
                else
                    error('showoverlay:InvalidMask',...
                        'Expected mask to be either a logical or RGB image.');
                end
                
                %Make the composite image
                replacePx = mask ~= 0;
                img(replacePx) = img(replacePx) .* (1 - alpha) + mask(replacePx) .* alpha;
            end
            
            %Recast the image into the original image class
            if imageIsInteger
                multFactor = double(intmax(imageClass));
            else
                multFactor = 1;
            end
            
            img = img .* multFactor;
            img = cast(img, imageClass);
            
            %Produce the desired outputs
            if nargout == 0
                imshow(img,[])
            else
                varargout = {img};
            end
            
        end
        
        function trackMouse(src, eventdata)
            
            keyboard
            
        end
        
    end
   
    
end