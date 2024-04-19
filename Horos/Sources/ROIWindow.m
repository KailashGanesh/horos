/*=========================================================================
 This file is part of the Horos Project (www.horosproject.org)
 
 Horos is free software: you can redistribute it and/or modify
 it under the terms of the GNU Lesser General Public License as published by
 the Free Software Foundation,  version 3 of the License.
 
 The Horos Project was based originally upon the OsiriX Project which at the time of
 the code fork was licensed as a LGPL project.  However, not all of the the source-code
 was properly documented and file headers were not all updated with the appropriate
 license terms. The Horos Project, originally was licensed under the  GNU GPL license.
 However, contributors to the software since that time have agreed to modify the license
 to the GNU LGPL in order to be conform to the changes previously made to the
 OsiriX Project.
 
 Horos is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY EXPRESS OR IMPLIED, INCLUDING ANY WARRANTY OF
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE OR USE.  See the
 GNU Lesser General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public License
 along with Horos.  If not, see http://www.gnu.org/licenses/lgpl.html
 
 Prior versions of this file were published by the OsiriX team pursuant to
 the below notice and licensing protocol.
 ============================================================================
 Program:   OsiriX
  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.
     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
 ============================================================================*/




#import "ROIWindow.h"
#import "HistogramWindow.h"
#import "PlotWindow.h"
#import "DCMView.h"
#import "DCMPix.h"
#import "Notifications.h"

@implementation ROIWindow

- (void)comboBoxWillPopUp:(NSNotification *)notification
{
	NSLog(@"will display...");
	roiNames = [curController generateROINamesArray];
	[[notification object] setDataSource: self];
	
	[[notification object] noteNumberOfItemsChanged];
	[[notification object] reloadData];
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)aString
{
	if( roiNames == nil) roiNames = [curController generateROINamesArray];
	
	long i;
	
	for(i = 0; i < [roiNames count]; i++)
	{
		if( [[roiNames objectAtIndex: i] isEqualToString: aString]) return i;
	}
	
	return NSNotFound;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
	if( roiNames == nil) roiNames = [curController generateROINamesArray];
	return [roiNames count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    if ( index > -1 )
    {
		if( roiNames == nil) roiNames = [curController generateROINamesArray];
		return [roiNames objectAtIndex: index];
    }
    
    return nil;
}


- (IBAction) roiSaveCurrent: (id) sender
{
	NSSavePanel     *panel = [NSSavePanel savePanel];
	
	NSMutableArray  *selectedROIs = [NSMutableArray  arrayWithObject:curROI];
	
	[panel setCanSelectHiddenExtension:NO];
	[panel setAllowedFileTypes:@[@"roi"]];
	
    panel.nameFieldStringValue = [[selectedROIs objectAtIndex:0] name];
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        
        [NSArchiver archiveRootObject: selectedROIs toFile:panel.URL.path];
    }];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
	[previousName release];
	previousName = nil;
	
	[super dealloc];
}

- (void) CloseViewerNotification :(NSNotification*) note
{
	if( [note object] == curController)
	{
		[self windowWillClose: nil];
	}
}

- (void) removeROI :(NSNotification*) note
{
	if( [note object] == curROI)
	{
		[self windowWillClose: nil];
	}
}

- (IBAction) recalibrate:(id) sender
{
    int		modalVal;
	float	pixels;
	float   newResolution;
	
    [NSApp beginSheet:recalibrateWindow 
            modalForWindow: [self window]
            modalDelegate:self 
            didEndSelector:NULL 
            contextInfo:NULL];
	
	[recalibrateValue setStringValue: [NSString stringWithFormat:@"%0.3f", (float) [curROI MesureLength :&pixels]] ];
	
    modalVal = [NSApp runModalForWindow:recalibrateWindow];
	
	if( modalVal)
	{
		newResolution = [recalibrateValue floatValue] / pixels;
		newResolution *= 10.0;
		
		for( DCMPix *pix in [curController pixList])
		{
			float previousX = [pix pixelSpacingX];
			
			[pix setPixelSpacingX: newResolution];
			
			if( previousX)
				[pix setPixelSpacingY: [pix pixelSpacingY] * newResolution / previousX];
			else
				[pix setPixelSpacingY: newResolution];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName: OsirixRecomputeROINotification object:curController userInfo: nil];
	}
	
    [NSApp endSheet:recalibrateWindow];
    [recalibrateWindow orderOut:NULL];   
}

- (IBAction)acceptSheet:(id)sender
{
    [NSApp stopModalWithCode: [sender tag]];
}

- (BOOL) allWithSameName
{
	return [allWithSameName state]==NSOnState;
}

- (void) setROI: (ROI*) iroi :(ViewerController*) c
{
	if( curROI == iroi) return;
	
	[curROI setComments: [NSString stringWithString: [comments string]]];	// stringWithString is very important - see NSText string !
	[curROI setName: [name stringValue]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];

	curController = c;
	curROI = iroi;
	
	RGBColor	rgb = [curROI rgbcolor];
	NSColor		*color = [NSColor colorWithDeviceRed:rgb.red/65535. green: rgb.green/65535. blue:rgb.blue/65535. alpha:1.0];
	
	[colorButton setColor: color];
	
	[thicknessSlider setFloatValue: [curROI thickness]];
	[opacitySlider setFloatValue: [curROI opacity]];
	
	[name setStringValue:[curROI name]];
	[name selectText: self];
	[comments setString:[curROI comments]];
		
	if( [curROI type] == tMesure) [recalibrate setEnabled: YES];
	else [recalibrate setEnabled: NO];
	
	if( [curROI type] == tMesure) [xyPlot setEnabled: YES];
	else [xyPlot setEnabled: NO];

	if( [curROI type] == tLayerROI) [exportToXMLButton setEnabled:NO];
	else [exportToXMLButton setEnabled:YES];
}

- (void)roiChange:(NSNotification*)notification;
{
//	ROI* roi = [notification object];
//	[comments setString:[roi comments]];
//	[name setStringValue:[roi name]];
}

- (void) getName:(NSTimer*)theTimer
{
	if( [[name stringValue] isEqualToString: previousName] == NO)
	{
		[self setTextData: name];
		[previousName release];
		previousName = [[name stringValue] retain];
	}
}

- (id) initWithROI: (ROI*) iroi :(ViewerController*) c
{
	self = [super initWithWindowNibName:@"ROI"];
	
	[[self window] setFrameAutosaveName:@"ROIInfoWindow"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roiChange:) name:OsirixROIChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(removeROI:) name: OsirixRemoveROINotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(CloseViewerNotification:) name: OsirixCloseViewerNotification object: nil];
	
	getName = [[NSTimer scheduledTimerWithTimeInterval: 0.1 target:self selector:@selector(getName:) userInfo:0 repeats: YES] retain];
	
	roiNames = nil;
	
	[self setROI: iroi :c];
		
	return self;
}

- (void) windowWillClose:(NSNotification *)notification
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	
	[getName invalidate];
	[getName release];
	getName = nil;
	
	[ROI saveDefaultSettings];
	
	[curROI setComments: [NSString stringWithString: [comments string]]]; 	// stringWithString is very important - see NSText string !
	[curROI setName: [name stringValue]];
	curROI = nil;
	
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];
	
	[self autorelease];
}

- (void) setAllMatchingROIsToSameParamsAs: (ROI*) iROI withNewName: (NSString*) newName
{	
	NSArray *roiSeriesList = [curController roiList];	
	
	for ( NSArray *roiImageList in roiSeriesList )
	{
		for ( ROI *roi in roiImageList )
		{
			if ( roi == curROI ) continue;
			
			if ( [[roi name] isEqualToString: [iROI name]] )
			{
				[roi setColor: [iROI rgbcolor]];
				[roi setThickness: [iROI thickness]];
				[roi setOpacity: [iROI opacity]];
				if ( newName ) [roi setName: newName];
				[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:roi userInfo: nil];
			}
		}
	}
}

- (void) removeAllROIsWithName: (NSString*) roiName
{		
	NSArray *roiSeriesList = [curController roiList];	
	
	for ( NSMutableArray *roiImageList in roiSeriesList )
	{
		int j;
		
		for ( j = 0; j < [roiImageList count]; j++ )
		{
			ROI *roi = [roiImageList objectAtIndex: j ];
			
			if ( [[roi name] isEqualToString: roiName] )
			{
				[roiImageList removeObjectAtIndex: j];
				j--;
			}
		}
	}
	[[curController imageView] setNeedsDisplay: YES];
	
	[self windowWillClose: nil];
}

- (IBAction) setTextData:(id) sender
{
	if ( [self allWithSameName] ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [sender stringValue]];
	
	[curROI setName: [sender stringValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];
}

- (IBAction) setThickness:(NSSlider*) sender
{
	[curROI setThickness: [sender floatValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];
	
	if ( [self allWithSameName] ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [curROI name]];
}

- (IBAction) setOpacity:(NSSlider*) sender
{
	[curROI setOpacity: [sender floatValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];
	
	if ( [self allWithSameName] ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [curROI name]];
}

- (IBAction) setColor:(NSColorWell*) sender
{
//	if( loaded == NO) return;
	
	CGFloat r, g, b;
	
	[[[sender color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace] getRed:&r green:&g blue:&b alpha:nil];
	
	RGBColor c;
	
	c.red = r * 65535.;
	c.green = g * 65535.;
	c.blue = b * 65535.;
	
	[curROI setColor:c];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];
	
	if ( [self allWithSameName] ) [self setAllMatchingROIsToSameParamsAs: curROI withNewName: [curROI name]];

	[comments setTextColor:nil];
}

+ (void) addROIValues: (ROI*) r dictionary: (NSMutableDictionary*) d
{
    if( r.name.length)
        [d setObject: r.name forKey:@"Name"];
    
    if( r.comments.length)
        [d setObject: r.comments forKey:@"Comments"];
    
    NSMutableArray *ROIPoints = [NSMutableArray array];
    for( MyPoint *p in [r points])
        [ROIPoints addObject: NSStringFromPoint( [p point])];
    
    [d setObject: ROIPoints forKey:@"ROIPoints"];
    
    if( [r dataString])
        [d setObject:[r dataString] forKey:@"DataSummary"];
    
    if( [r dataValues])
        [d setObject:[r dataValues] forKey:@"DataValues"];
}

- (NSArray *)roiLoadSimpleFromSeries:(NSString *)filename {
    NSMutableArray *allROIsWithSlices = [NSMutableArray array];
    NSArray *roisMovies = [NSUnarchiver unarchiveObjectWithFile:filename];
    if (!roisMovies) {
        NSLog(@"Failed to unarchive ROIs from file: %@", filename);
        return allROIsWithSlices; // Return the empty array or handle the error as appropriate
    }

    // Iterate through each series (considered as slices)
    for (NSInteger sliceIndex = 0; sliceIndex < [roisMovies count]; sliceIndex++) {
        NSArray *roisSeries = [roisMovies objectAtIndex:sliceIndex];
        
        // Ensuring to check each inner array for ROIs
        for (NSInteger i = 0; i < [roisSeries count]; i++) {
            NSArray *roisImages = [roisSeries objectAtIndex:i];
            if ([roisImages count] > 0) {
                for (ROI *roi in roisImages) {
                    NSMutableDictionary *roiWithSliceInfo = [NSMutableDictionary dictionary];
                    [ROIWindow addROIValues:roi dictionary:roiWithSliceInfo];
                    [roiWithSliceInfo setObject:[NSNumber numberWithInteger:i + 1] forKey:@"Slice"];
                    [allROIsWithSlices addObject:roiWithSliceInfo];
                }
            }
        }
    }
    
    return allROIsWithSlices;
}




- (IBAction)exportData:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowedFileTypes = @[@"roi", @"rois_series"];
    openPanel.prompt = NSLocalizedString(@"Open ROI File", @"");

    if ([openPanel runModal] != NSModalResponseOK) return;

    NSString *filePath = openPanel.URL.path;
    NSString *fileExtension = [filePath pathExtension];
    NSArray *roiDataArray = nil;

    if ([fileExtension isEqualToString:@"roi"]) {
        roiDataArray = [NSUnarchiver unarchiveObjectWithFile:filePath];
        // Assuming the .roi files return ROI objects, not dictionaries
        NSMutableArray *xmlArray = [NSMutableArray array];
        for (ROI *roi in roiDataArray) {
            NSMutableDictionary *roiDict = [NSMutableDictionary dictionary];
            [ROIWindow addROIValues:roi dictionary:roiDict];
            [xmlArray addObject:roiDict];
        }
        roiDataArray = xmlArray; // Update roiDataArray with the processed dictionaries
    } else if ([fileExtension isEqualToString:@"rois_series"]) {
        // Use the simplified loading method
        roiDataArray = [self roiLoadSimpleFromSeries:filePath];
        // Assuming these are already dictionaries, no further transformation needed
    }

    if (!roiDataArray || roiDataArray.count == 0) {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), NSLocalizedString(@"No ROIs found or unsupported file type.", @""), NSLocalizedString(@"OK", @""), nil, nil);
        return;
    }

    NSString *xmlPath = [[filePath stringByDeletingPathExtension] stringByAppendingString:@".xml"];
    NSDictionary *xmlDict = @{@"ROIArray": roiDataArray};
    BOOL success = [xmlDict writeToURL:[NSURL fileURLWithPath:xmlPath] atomically:YES];

    if (success) {
        NSRunInformationalAlertPanel(NSLocalizedString(@"Export Successful", @""), @"%@", [NSString stringWithFormat:NSLocalizedString(@"XML file saved as %@", @""), xmlPath], NSLocalizedString(@"OK", @""), nil, nil);
    } else {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), NSLocalizedString(@"Failed to save the XML file.", @""), NSLocalizedString(@"OK", @""), nil, nil);
    }
}




- (IBAction) histogram:(id) sender
{
	NSArray *winList = [NSApp windows];
	BOOL	found = NO;
	
	for( id loopItem in winList)
	{
		if( [[[loopItem windowController] windowNibName] isEqualToString:@"Histogram"])
		{
			if( [[loopItem windowController] curROI] == curROI)
			{
				found = YES;
				[[[loopItem windowController] window] makeKeyAndOrderFront:self];
			}
		}
	}
	
	if( found == NO)
	{
		if( [[curROI points] count] > 0)
		{
			HistoWindow* roiWin = [[HistoWindow alloc] initWithROI: curROI];
			[roiWin showWindow:self];
		}
		else NSRunAlertPanel(NSLocalizedString(@"Error", nil), NSLocalizedString(@"Cannot create an histogram from this ROI.", nil), nil, nil, nil);
	}
}

- (IBAction) plot:(id) sender
{
	NSArray *winList = [NSApp windows];
	BOOL	found = NO;
	
	for( id loopItem in winList)
	{
		if( [[[loopItem windowController] windowNibName] isEqualToString:@"Plot"])
		{
			if( [[loopItem windowController] curROI] == curROI)
			{
				found = YES;
				[[[loopItem windowController] window] makeKeyAndOrderFront:self];
			}
		}
	}
	
	if( found == NO)
	{
		PlotWindow* roiWin = [[PlotWindow alloc] initWithROI: curROI];
		[roiWin showWindow:self];
	}
}

-(ROI*) curROI {return curROI;}

@end
