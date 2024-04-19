# Horos / OsiriX ROI Analysis

The roi class in `ROI.h` shows us the different types of regions of interest that can be created in the OsiriX application. The different types of regions of interest are as follows:

```objective-c
/** \brief Region of Interest
* 
* Region of Interest on a 2D Image:\n
* Types\n
*	tMesure  = line\n
*	tROI = Rectangle\n
*	tOval = Oval\n
*	tOPolygon = Open Polygon\n
*	tCPolygon = Closed Polygon\n
*	tAngle = Angle\n
*	tText = Text\n
*	tArrow = Arrow\n
*	tPencil = Pencil\n
*	t3Dpoint= 3D Point\n
*	t2DPoint = 2D Point\n
*	tPlain = Brush ROI\n
*	tLayerROI = Layer Overlay\n
*	tAxis = Axis\n					
*	tDynAngle = Dynamic Angle\n
*   tTAGT = 2 paralles lines and 1 perpendicular line
*/

@interface ROI : NSObject <NSCoding, NSCopying>
{
	NSRecursiveLock *roiLock;
	
	int				textureWidth, textureHeight;

	unsigned char   *textureBuffer, *textureBufferSelected;
    
	NSMutableArray *ctxArray;	//All contexts where this texture is used
	NSMutableArray *textArray;	//All texture id

	int				textureUpLeftCornerX,textureUpLeftCornerY,textureDownRightCornerX,textureDownRightCornerY;
	int				textureFirstPoint;
	
	NSMutableArray  *points;
	NSMutableArray  *zPositions;
	NSRect			rect;
	BOOL			_hasIsSpline, _isSpline;
	
	ToolMode		type;
	long			mode, previousMode;
	BOOL			needQuartz;
	
	float			thickness;
	
	BOOL			fill;
	float			opacity;
	RGBColor		color;
	
	BOOL			closed,clickInTextBox;
	
	NSString		*name;
	NSString		*comments;
	
	double			pixelSpacingX, pixelSpacingY;
	NSPoint			imageOrigin;
	
	// **** **** **** **** **** **** **** **** **** **** TRACKING
	
    BOOL            mouseOverROI;
	int				PointUnderMouse;
	long			selectedModifyPoint;
	NSPoint			clickPoint, previousPoint, originAnchor;
	
	DCMView			*curView;
	DCMPix			*pix;
	
	float			rmean, rmax, rmin, rdev, rtotal, rskewness, rkurtosis;
	float			Brmean, Brmax, Brmin, Brdev, Brtotal, Brskewness, Brkurtosis;
	
	float			mousePosMeasure;
	
	StringTexture	*stringTex;
	NSMutableDictionary	*stanStringAttrib;
	NSCache         *stringTextureCache;
    
	ROI*			parentROI;
	
	NSRect			drawRect;
	
	float			offsetTextBox_x, offsetTextBox_y;
	
	NSString		*textualBoxLine1, *textualBoxLine2, *textualBoxLine3, *textualBoxLine4, *textualBoxLine5, *textualBoxLine6;
	
	BOOL			_displayCalciumScoring;
	int				_calciumThreshold;
	double			_sliceThickness;
	int				_calciumCofactor;
	
	NSString		*layerReferenceFilePath;
	NSImage			*layerImage;//, *layerImageWhenSelected;
	NSData			*layerImageJPEG;//, *layerImageWhenSelectedJPEG;
	float			layerPixelSpacingX, layerPixelSpacingY;
	BOOL			isLayerOpacityConstant;
	BOOL			canColorizeLayer, canResizeLayer;
	NSColor			*layerColor;
	
	NSNumber		*uniqueID;		// <- not saved, only valid during the 'life' of a ROI
	NSTimeInterval	groupID;		// timestamp of a ROI group. Grouped ROI will be selected/deleted together.
	
	BOOL			displayTextualData;
	BOOL			displayCMOrPixels;
	
	BOOL			locked;
	BOOL			selectable;
	BOOL			isAliased;
	int				originalIndexForAlias;
    
    BOOL            hidden;
    
	StringTexture *stringTexA, *stringTexB, *stringTexC;
}
```
## Importing

when we click on menu to import ROI, the following code is executed in `ViewerController.m`:

```objective-c
- (IBAction) roiLoadFromFiles: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:YES];
    [panel setCanChooseDirectories:NO];
    
    panel.allowedFileTypes = @[@"roi", @"rois_series", @"xml"];
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        
        if( [[panel.URLs.lastObject pathExtension] isEqualToString:@"xml"])
            [imageView roiLoadFromXMLFiles:[panel.URLs valueForKeyPath:@"path"]];
        else if( [[panel.URLs.lastObject pathExtension] isEqualToString:@"rois_series"])
            [self roiLoadFromSeries:panel.URLs.lastObject.path];
        else
            [imageView roiLoadFromFilesArray:[panel.URLs valueForKeyPath:@"path"]];
    }];
}
```

which calls the function to appoprte to it's file type.

How `.xml` files are loaded - function available in `DCMView.m`:

```objective-c
- (IBAction) roiLoadFromXMLFiles: (NSArray*) filenames
{
    int	i;
    
    if ([[NSUserDefaults standardUserDefaults] integerForKey: @"ANNOTATIONS"] == annotNone)
    {
        [[NSUserDefaults standardUserDefaults] setInteger: annotGraphics forKey: @"ANNOTATIONS"];
        [DCMView setDefaults];
    }
    
    // Unselect all ROIs
    for( ROI *r in curRoiList) [r setROIMode: ROI_sleep];
    
    for( i = 0; i < [filenames count]; i++)
    {
        NSDictionary *xml = [NSDictionary dictionaryWithContentsOfFile: [filenames objectAtIndex:i]];
        NSArray* roiArray = [xml objectForKey: @"ROI array"];
        
        if( roiArray)
        {
            for( NSDictionary *x in roiArray)
                [self roiLoadFromXML: x];
        }
        else
            [self roiLoadFromXML: xml];
    }
    
    [self setNeedsDisplay:YES];
}
```

How `.roi_series` files are loaded - function avaiable in `ViewerController.m`:

```objective-c
- (void) roiLoadFromSeries: (NSString*) filename
{
    // Unselect all ROIs
    [self roiSelectDeselectAll: nil];
    
    NSArray *roisMovies = [NSUnarchiver unarchiveObjectWithFile: filename];
    
    for( int y = 0; y < maxMovieIndex; y++)
    {
        if( [roisMovies count] > y)
        {
            NSArray *roisSeries = [roisMovies objectAtIndex: y];
            
            for( int x = 0; x < [pixList[y] count]; x++)
            {
                DCMPix *pic = [pixList[ y] objectAtIndex: x];
                
                if( [roisSeries count] > x)
                {
                    NSArray *roisImages = [roisSeries objectAtIndex: x];
                    
                    for( ROI *r in roisImages)
                    {
                        //Correct the origin only if the orientation is the same
                        r.pix = pic;
                        
                        [r setOriginAndSpacing: pic.pixelSpacingX :pic.pixelSpacingY :[DCMPix originCorrectedAccordingToOrientation: pic]];
                        
                        [[roiList[ y] objectAtIndex: x] addObject: r];
                        [imageView roiSet: r];
                    }
                }
            }
        }
    }
    
    [imageView setIndex: [imageView curImage]];
}
```

How `.roi` files are loaded - function available in `DCMView.m`:

```objective-c
- (void) roiLoadFromFilesArray: (NSArray*) filenames
{
    // Unselect all ROIs
    for( ROI *r in curRoiList) [r setROIMode: ROI_sleep];
    
    for( NSString *path in filenames)
    {
        NSMutableArray*    roiArray = [NSUnarchiver unarchiveObjectWithFile: path];
        
        for( id loopItem1 in roiArray)
        {
            [loopItem1 setOriginAndSpacing:self.curDCM.pixelSpacingX :self.curDCM.pixelSpacingY :[DCMPix originCorrectedAccordingToOrientation:self.curDCM]];
            [loopItem1 setROIMode:ROI_selected];
            [loopItem1 setCurView:self];
            
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROISelectedNotification object: loopItem1 userInfo: nil];
        }
        
        if( [[NSUserDefaults standardUserDefaults] boolForKey: @"markROIImageAsKeyImage"])
        {
            if( [self is2DViewer] == YES && [self isKeyImage] == NO && [[self windowController] isPostprocessed] == NO)
                [[self windowController] setKeyImage: self];
        }
        
        [curRoiList addObjectsFromArray: roiArray];
    }
    
    [self setNeedsDisplay:YES];
}```


## Exporting

How ROI files are saved to `.roi` format is shown in `DCMView.m`:

```objective-c
- (IBAction) roiSaveSelected: (id) sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    
    NSMutableArray *selectedROIs = [NSMutableArray  array];
    
    for (ROI *r in curRoiList)
    {
        if ([r ROImode] == ROI_selected)
            [selectedROIs addObject:r];
    }
    
    if ([selectedROIs count] > 0)
    {
        [panel setCanSelectHiddenExtension:NO];
        panel.allowedFileTypes = @[@"roi"];
        panel.nameFieldStringValue = [[selectedROIs objectAtIndex:0] name];
        
        [panel beginWithCompletionHandler:^(NSInteger result) {
            if (result != NSFileHandlingPanelOKButton)
                return;
            
            [NSArchiver archiveRootObject:selectedROIs toFile:panel.URL.path];
        }];
    }
    else
        NSRunCriticalAlertPanel(NSLocalizedString(@"ROIs Save Error",nil), NSLocalizedString(@"No ROI(s) selected to save!",nil) , NSLocalizedString(@"OK",nil), nil, nil);
}
```

How ROI files are saved to `.roi_series` format is shown in `ViewerController.m`:

```objective-c
- (IBAction) roiSaveSeries: (id) sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    NSMutableArray *roisPerMovies = [NSMutableArray  array];
    BOOL rois = NO;
    
    for( int y = 0; y < maxMovieIndex; y++)
    {
        NSMutableArray  *roisPerSeries = [NSMutableArray  array];
        
        for( int x = 0; x < [pixList[ y] count]; x++)
        {
            NSMutableArray  *roisPerImages = [NSMutableArray  array];
            
            for( int i = 0; i < [[roiList[ y] objectAtIndex: x] count]; i++)
            {
                ROI	*curROI = [[roiList[ y] objectAtIndex: x] objectAtIndex: i];
                
                [roisPerImages addObject: curROI];
                
                rois = YES;
            }
            
            [roisPerSeries addObject: roisPerImages];
        }
        
        [roisPerMovies addObject: roisPerSeries];
    }
    
    if( rois > 0)
    {
        [panel setCanSelectHiddenExtension:NO];
        [panel setAllowedFileTypes:@[@"rois_series"]];
        panel.nameFieldStringValue = [[[self fileList] objectAtIndex:0] valueForKeyPath:@"series.name"];
        
        [panel beginWithCompletionHandler:^(NSInteger result) {
            if (result != NSFileHandlingPanelOKButton)
                return;
            [NSArchiver archiveRootObject: roisPerMovies toFile :panel.URL.path];
        }];
    }
    else
    {
        NSRunCriticalAlertPanel(NSLocalizedString(@"ROIs Save Error",nil), NSLocalizedString(@"No ROIs in this series!",nil) , NSLocalizedString(@"OK",nil), nil, nil);
    }
}
```


How ROI files are saved to XML format is shown in `ROIWindow.m`:

```objective-c
- (IBAction) exportData:(id) sender
{
	if([curROI type]==tPlain)
	{
		NSInteger confirm = NSRunInformationalAlertPanel(NSLocalizedString(@"Export to XML", @""), NSLocalizedString(@"Exporting this kind of ROI to XML will only export the contour line.", @""), NSLocalizedString(@"OK", @""), NSLocalizedString(@"Cancel", @""), nil);
		if(!confirm) return;
	}
	else if([curROI type]==tLayerROI)
	{
		NSRunAlertPanel(NSLocalizedString(@"Export to XML", @""), NSLocalizedString(@"This kind of ROI can not be exported to XML.", @""), NSLocalizedString(@"OK", @""), nil, nil);
		return;
	}
	
	NSSavePanel *panel = [NSSavePanel savePanel];
    panel.canSelectHiddenExtension = NO;
    panel.allowedFileTypes = @[@"xml"];
    panel.nameFieldStringValue = curROI.name;
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;

        NSMutableDictionary *xml = [NSMutableDictionary dictionary];
		
		if( [self allWithSameName])
		{
			NSArray *roiSeriesList = [curController roiList];
			NSMutableArray *roiArray = [NSMutableArray array];
			
			int i;			
			for ( i = 0; i < [roiSeriesList count]; i++ )
			{
				NSArray *roiImageList = [roiSeriesList objectAtIndex: i];
				
				for( ROI *roi in roiImageList )
				{
					if ( [[roi name] isEqualToString: [curROI name]])
					{
						NSMutableDictionary *roiData = [NSMutableDictionary dictionary];
						
                        [ROIWindow addROIValues: roi dictionary: roiData];
						[roiData setObject:[NSNumber numberWithInt: i + 1] forKey: @"Slice"];
						
						[roiArray addObject: roiData];
					}
				}
			}
			
			[xml setObject: roiArray forKey: @"ROI array"];
		}
		
		else // Output curROI only
            [ROIWindow addROIValues: curROI dictionary: xml];
		
		[xml writeToURL:panel.URL atomically:YES];
    }];
}```