//
//  OMMiniXcode.h
//  OMMiniXcode
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class OMSchemeSelectionView;
@class JTEditorSelectionView;

@interface OMMiniXcode : NSObject {
	NSWindowController *_currentWindowController;
}

@property (assign) NSWindowController *currentWindowController;

- (OMSchemeSelectionView *)schemePopUpButtonContainerForWindow:(NSWindow *)window;
- (NSPopUpButton *)schemePopUpButtonForWindow:(NSWindow *)window;
- (JTEditorSelectionView *)editorSegmentedControlContainerForWindow:(NSWindow *)window;
- (NSSegmentedControl *)editorSegmentedControlForWindow:(NSWindow *)window;

@end

