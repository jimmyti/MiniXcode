//
//  JTEditorSelectionView.m
//  OMMiniXcode
//
//  Created by Jimmy Ti on 17/09/12.
//
//

#import "JTEditorSelectionView.h"

@implementation JTEditorSelectionView

@synthesize editorSegmentedControl = _editorSegmentedControl, tag=_tag;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        _editorSegmentedControl = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 20)];
        [[_editorSegmentedControl cell] setControlSize:NSSmallControlSize];
        [_editorSegmentedControl setSegmentStyle:NSSegmentStyleTexturedSquare];
        [_editorSegmentedControl setSegmentCount:3];
        
        NSString *imageFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TB_ViewSegment-Basic" ofType:@"png"];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:imageFilePath];
        [_editorSegmentedControl setImage:image forSegment:0];
        [_editorSegmentedControl setImageScaling:NSImageScaleProportionallyDown forSegment:0];
        imageFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TB_ViewSegment-Assistant" ofType:@"png"];
        image = [[NSImage alloc] initWithContentsOfFile:imageFilePath];
        [_editorSegmentedControl setImage:image forSegment:1];
        [_editorSegmentedControl setImageScaling:NSImageScaleProportionallyDown forSegment:1];
        imageFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TB_ViewSegment-Versions" ofType:@"png"];
        image = [[NSImage alloc] initWithContentsOfFile:imageFilePath];
        [_editorSegmentedControl setImage:image forSegment:2];
        [_editorSegmentedControl setImageScaling:NSImageScaleProportionallyDown forSegment:2];
        [self addSubview:_editorSegmentedControl];
    }
    
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
	[super resizeSubviewsWithOldSize:oldBoundsSize];
	self.editorSegmentedControl.frame = NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height);
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)dealloc
{
	[_editorSegmentedControl release];
	[super dealloc];
}

@end
