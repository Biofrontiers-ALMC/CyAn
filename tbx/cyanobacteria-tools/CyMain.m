classdef CyMain
    %CYMAIN  main Class (needs a better name)
    
    properties
        
        ChannelToSegment = '!CStack';
        FrameRange = 1;
        
    end
    
    methods
        
        function processFile(obj, varargin)
            %PROCESSFILE  Segment and track cells in a video file
            
            ip = inputParser;
            ip.addOptional('Filename','',@(x) ischar(x));
            ip.addParameter('OutputMovie',false, @(x) islogical(x));
            ip.parse(varargin{:});
            
            if isempty(ip.Results.Filename)
                [fname, fpath] = uigetfile({'*.nd2','ND2 file (*.nd2)'},...
                    'Select a file');
                
                if fname == 0
                    %Stop running the script
                    return;
                end
                
                filename = fullfile(fpath,fname);
                
            else
                filename = ip.Results.Filename;
            end
            
            %Get a reader object for the image
            bfReader = BioformatsImage(filename);
            
            %Get the frame range to process
            if isinf(obj.FrameRange)
                frameRange = 1:bfReader.sizeT;
            else
                %TODO: Check that requested range is actually within sizeT
                frameRange = obj.FrameRange;
            end
            
            %Segment cells
            for iT = frameRange
                
                %Get image to segment
                if strcmpi(obj.ChannelToSegment,'!CStack')
                    
                    imgToSegment = zeros(bfReader.height, bfReader.width);
                    for iC = 1:bfReader.sizeC
                        
                        %Add the intensity of a channel, weighted by the
                        %number of channels
                        imgToSegment = imgToSegment + double(bfReader.getPlane(1, iC, iT)) ./ bfReader.sizeC;
                        
                    end
                    
                else
                    imgToSegment = bfReader.getPlane(1, obj.ChannelToSegment, iT);
                end
                
            end
            
            %Segment cells and get cell label
            cellLabels = CyMain.getCellLabels(imgToSegment);
            
            %Get cell data
            cellData = CyMain.getCellData(cellLabels, bfReader);
           
            %Link cells
            if iT == frameRange(1)
                
                %Set up the cell tracker
                trackLinker = TrackLinker(iT, cellData, 'LinkedBy', 'OverlapScore');
                
            else
                
                trackLinker.assignTracks(iT, cellData);
                
            end
            
            CyMain.showoverlay(CyMain.normalizeimg(imgToSegment),bwperim(cellLabels),[0 1 0])
            
        end
        
    end
    
    methods (Static)
        
        function cellLabels = getCellLabels(cellImage, varargin)
            %GETCELLLABELS  Segment and label individual cells
            %
            %  L = CyMain.GETCELLLABELS(I) will segment the cells in image
            %  I, returning a labelled image L. Each value in L should
            %  correspond to an individual cell.
            %
            %  L = CyMain.GETCELLLABELS(I, M) will use image M to mark
            %  cells. M should be a fluroescent image (e.g. YFP, GFP) that
            %  fully fills the cells.
            
            if isempty(varargin)

                cellMarkerImg = [];
                
            else
                
                %TODO: Add the ability to have a cell marker image
                
            end
            
            
            thLvl = CyMain.getThreshold(cellImage);
            
            mask = cellImage > thLvl;
            
            mask = imopen(mask,strel('disk',2));
            mask = imclearborder(mask);
            
            mask = activecontour(cellImage,mask);
            
            mask = bwareaopen(mask,100);
            mask = imopen(mask,strel('disk',2));
            
            mask = imfill(mask,'holes');
                     
%             CyMain.showoverlay(CyMain.normalizeimg(cellImage),bwperim(mask),[0 1 0]);
%             keyboard

            
            if isempty(cellMarkerImg)
                
                dd = -bwdist(~mask);
                dd(~mask) = -Inf;
                
                imgToWatershed = imhmin(dd,1);
                
            else
                %TODO
                
                %%Find extended maxima in the cell marker channel
                %fgmarker = ColonyTracker.getCellMarker(cellMarkerImg);
                
                %%Invert the cell marker image so that the centers are dark
                %img = imcomplement(cellMarkerImg);
                
                %Mark the negative regions (e.g. regions that are not the cell
                %and each cell region)
                %markedImage = imimposemin(img, ~colonyMask | fgmarker);
                
            end
            
            cellLabels = watershed(imgToWatershed);
            cellLabels = imclearborder(cellLabels);
            
        end
        
        function thLvl = getThreshold(imageIn)
            %GETTHRESHOLD  Get a threshold level to binarize the image
            %
            %  T = CyMain.GETTHRESHOLD(I) will look for a suitable
            %  greyscale level T to binarize image I.
            
            [nCnts, binEdges] = histcounts(imageIn(:),150);
            binCenters = diff(binEdges) + binEdges(1:end-1);
            
            nCnts = smooth(nCnts,3);
            nCnts(1) = 0;
            [~,locs] = findpeaks(nCnts,'Npeaks',2,'sortStr','descend','MinPeakDistance',5);
            
            %Find valley
            [~,valleyLoc] = min(nCnts(locs(1):locs(2)));
            
            thLvl = binCenters(valleyLoc + locs(1));
            
            if isempty(thLvl)
                warning('Threshold level not found')
                keyboard
            end
            
        end
        
        function varargout = showoverlay(baseimage, mask, color, varargin)
            %SHOWOVERLAY    Plot an overlay mask on an image
            %
            %  SHOWOVERLAY(IMAGE,MASK,COLOR) will plot an overlay specified by a binary
            %  MASK on the IMAGE. The color of the overlay is specified using a three
            %  element vector COLOR.
            %
            %  Example:
            %
            %    mainImg = imread('cameraman')
            %
            %
            %  Downloaded from http://cellmicroscopy.wordpress.com
            
            if ~exist('color','var')
                color = [1 1 1]; %Default color of the overlay
            end
            
            if size(baseimage,3) == 3
                red = baseimage(:,:,1);
                green = baseimage(:,:,2);
                blue = baseimage(:,:,3);
                
            elseif size(baseimage,3) == 1
                red = baseimage;
                green = baseimage;
                blue = baseimage;
                
            else
                error('Image should be either NxNx1 (greyscale) or NxNx3 (rgb)')
            end
            
            %Make sure the mask is binary (anything non-zero becomes true)
            mask = (mask ~= 0);
            
            if isinteger(baseimage)
                maxInt = intmax(class(baseimage));
            else
                maxInt = 1;
            end
            
            red(mask) = color(1) .* maxInt;
            green(mask) = color(2) .* maxInt;
            blue(mask) = color(3) .* maxInt;
            
            %Concatenate the output
            outputImg = cat(3,red,green,blue);
            
            if nargout == 0
                %Get the current warning status
                warningStatus = warning;
                warningStatus = warningStatus(1).state;
                
                %Turn off warnings
                warning off
                
                %Show image
                imshow(outputImg,[])    
                
                %Restore warning state
                warning(warningStatus)
            else
                varargout{1} = outputImg;
            end
        end
        
        function imageOut = normalizeimg(imageIn,varargin)
            %NORMALIZEIMG   Linear dynamic range expansion for contrast enhancement
            %   N = NORMALIZEIMG(I) expands the dynamic range (or contrast) of image I
            %   linearly to maximize the range of values within the image.
            %
            %   This operation is useful when enhancing the contrast of an image. For
            %   example, if I is an image with uint8 format, with values ranging from
            %   30 to 100. Normalizing the image will expand the values so that they
            %   fill the full dynamic range of the format, i.e. from 0 to 255.
            %
            %   The format of the output image N depends on the format of the input
            %   image I. If I is a matrix with an integer classs (i.e. uint8, int16), N
            %   will returned in the same format. If I is a double, N will be
            %   normalized to the range [0 1] by default.
            %
            %   N = NORMALIZEIMG(I,[min max]) can also be used to specify a desired
            %   output range. For example, N = normalizeimg(I,[10,20]) will normalize
            %   image I to have values between 10 and 20. In this case, N will be
            %   returned in double format regardless of the format of I.
            %
            %   In situations where most of the interesting image features are
            %   contained within a narrower band of values, it could be useful to
            %   normalize the image to the 5 and 95 percentile values.
            %
            %   Example:
            %       I = imread('cameraman.tif');
            %
            %       %Calculate the values corresponding to the 5 and 95 percentile of
            %       %values within the image
            %       PRC5 = prctile(I(:),5);
            %       PRC95 = prctile(I(:),95);
            %
            %       %Threshold the image values to the 5 and 95 percentiles
            %       I(I<PRC5) = PRC5;
            %       I(I>PRC95) = PRC95;
            %
            %       %Normalize the image
            %       N = normalizeimg(I);%
            %
            %       %Display the normalized image
            %       imshow(N)
            
            %Define default output value range
            outputMin = 0;
            outputMax = 1;
            
            %Check if the desired output range is set. If it is, make sure it contains
            %the right number of values and format, then update the output minimum and
            %maximum values accordingly.
            if nargin >= 2
                if numel(varargin{1}) ~= 2
                    error('The input parameter should be [min max]')
                end
                
                outputMin = varargin{1}(1);
                outputMax = varargin{1}(2);
            else
                %If the desired output range is not set, then check if the image is an
                %integer class. If it is, then set the minimum and maximum values
                %to match the range of the class type.
                if isinteger(imageIn)
                    inputClass = class(imageIn);
                    
                    outputMin = 0;
                    outputMax = double(intmax(inputClass)); %Get the maximum value of the class
                    
                end
            end
            
            %Convert the image to double for the following operations
            imageIn = double(imageIn);
            
            %Calculate the output range
            outputRange = outputMax - outputMin;
            
            %Get the maximum and minimum input values from the image
            inputMin = min(imageIn(:));
            inputMax = max(imageIn(:));
            inputRange = inputMax - inputMin;
            
            %Normalize the image values to fit within the desired output range
            imageOut = (imageIn - inputMin) .* (outputRange/inputRange) + outputMin;
            
            %If the input was an integer before, make the output image the same class
            %type
            if exist('inputClass','var')
                eval(['imageOut = ',inputClass,'(imageOut);']);
            end
            
        end
        
    end
    
end