//
//  JTEditorSelectionView.h
//  OMMiniXcode
//
//  Created by Jimmy Ti on 17/09/12.
//
//

#import <Cocoa/Cocoa.h>

@interface JTEditorSelectionView : NSView {
    NSSegmentedControl *_editorSegmentedControl;
	NSInteger _tag;
}

@property (nonatomic, retain) NSSegmentedControl *editorSegmentedControl;
@property (nonatomic, assign) NSInteger tag;
@end
