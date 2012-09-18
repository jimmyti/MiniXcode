//
//  OMMiniXcode.m
//  OMMiniXcode
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "OMMiniXcode.h"
#import "OMSchemeSelectionView.h"
#import "JTEditorSelectionView.h"

#define SCHEME_POPUP_BUTTON_CONTAINER_TAG   456
#define SCHEME_POPUP_BUTTON_TAG             457
#define BUILD_PROGRESS_SPINNER_TAG          458
#define EDITOR_CONTROL_CONTAINER_TAG        567
#define EDITOR_CONTROL_WIDTH                100
#define EDITOR_CONTROL_RIGHT_MARGIN         175
#define EDITOR_CONTROL_TOP_MARGIN           23

#define kOMMiniXcodeDisableSchemeSelectionInTitleBar	@"OMMiniXcodeDisableSchemeSelectionInTitleBar"
#define kOMMiniXcodeDisableEditorSelectionInTitleBar	@"OMMiniXcodeDisableEditorSelectionInTitleBar"

//TODO: Use the actual headers from class-dump

@interface NSObject (IDEKit)
- (void)setActiveRunContext:(id)arg1 andRunDestination:(id)arg2;
- (id)_bestDestinationForScheme:(id)arg1 previousDestination:(id)arg2;
- (id)activeRunDestination;
+ (id)workspaceWindowControllers;
@end


@implementation OMMiniXcode

@synthesize currentWindowController = _currentWindowController;


+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id sharedPlugin = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (id)init
{
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildProductsLocationDidChange:) name:@"IDEWorkspaceBuildProductsLocationDidChangeNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(splitViewDidResizeSubviews:) name:NSSplitViewDidResizeSubviewsNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidEndLiveResize:) name:NSWindowDidEndLiveResizeNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildWillStart:) name:@"IDEBuildOperationWillStartNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildDidStop:) name:@"IDEBuildOperationDidStopNotification" object:nil];
		
		NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
		if (viewMenuItem) {
			[[viewMenuItem submenu] addItem:[NSMenuItem separatorItem]];
			NSMenuItem *toggleSchemeInTitleBarItem = [[[NSMenuItem alloc] initWithTitle:@"Scheme Selection in Title Bar" action:@selector(toggleSchemeInTitleBar:) keyEquivalent:@""] autorelease];
			[toggleSchemeInTitleBarItem setTarget:self];
			[[viewMenuItem submenu] addItem:toggleSchemeInTitleBarItem];
            
			NSMenuItem *toggleEditorInTitleBarItem = [[[NSMenuItem alloc] initWithTitle:@"Editor Selection in Title Bar" action:@selector(toggleEditorInTitleBar:) keyEquivalent:@""] autorelease];
			[toggleEditorInTitleBarItem setTarget:self];
			[[viewMenuItem submenu] addItem:toggleEditorInTitleBarItem];
		}
		
		[NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *event) {
			unsigned short keyCode = [event keyCode];
			if ((keyCode == 26 || keyCode == 28) && [event modifierFlags] & NSControlKeyMask) {
				NSWindow *window = [NSApp keyWindow];
				OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
				NSPopUpButton *popUpButton = schemeView.popUpButton;
				BOOL toolbarVisible = [[window toolbar] isVisible];
				if (schemeView && !toolbarVisible) {
					NSMenuItem *selectedItem = [popUpButton selectedItem];
					if (keyCode == 28) {
						for (NSMenuItem *item in [[[popUpButton menu] itemArray] reverseObjectEnumerator]) {
							if (item.state == NSOnState) {
								selectedItem = item;
								break;
							}
						}
					}
					[[popUpButton menu] popUpMenuPositioningItem:selectedItem atLocation:NSMakePoint(-14, 2) inView:popUpButton];
				} else if (popUpButton) {
					@try {
						NSToolbar *toolbar = [window toolbar];
						if (toolbar.items.count >= 3) {
							NSToolbarItem *schemeItem = [toolbar.items objectAtIndex:2];
							NSView *schemeView = schemeItem.view;
							if (schemeView.subviews.count > 0) {
								NSPathControl *pathControl = (NSPathControl *)[schemeView.subviews objectAtIndex:0];
								if ([pathControl isKindOfClass:[NSPathControl class]] && [pathControl isKindOfClass:NSClassFromString(@"IDEPathControl")]) {
									NSArray *componentCells = [pathControl pathComponentCells];
									if (componentCells.count > 1) {
										NSPathComponentCell *cell = [componentCells objectAtIndex:(keyCode == 26 ? 0 : 1)];
										if ([pathControl respondsToSelector:@selector(popUpMenuForComponentCell:)]) {
											[pathControl performSelector:@selector(popUpMenuForComponentCell:) withObject:cell];
										}
									}
								}
							}
						}
					}
					@catch (NSException *exception) { }
				} else {
					NSBeep();
				}
				return nil;
			}
			return event;
		}];
	}
	return self;
}
	
- (void)toggleSchemeInTitleBar:(id)sender
{
	BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
	titleBarDisabled = !titleBarDisabled;
	[[NSUserDefaults standardUserDefaults] setBool:titleBarDisabled forKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
	
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
			BOOL toolbarVisible = [[window toolbar] isVisible];
			if (schemeView) {
				[schemeView setHidden:titleBarDisabled || toolbarVisible];
			}
		}
	}
	@catch (NSException *exception) { }
}

- (void)toggleEditorInTitleBar:(id)sender
{
	BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
	titleBarDisabled = !titleBarDisabled;
	[[NSUserDefaults standardUserDefaults] setBool:titleBarDisabled forKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
	
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			JTEditorSelectionView *editorView = [self editorSegmentedControlContainerForWindow:window];
			BOOL toolbarVisible = [[window toolbar] isVisible];
			if (editorView) {
				[editorView setHidden:titleBarDisabled || toolbarVisible];
			}
		}
	}
	@catch (NSException *exception) { }
}
	
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(toggleSchemeInTitleBar:)) {
		BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
		[menuItem setState:disabled ? NSOffState : NSOnState];
	}
    
    if ([menuItem action] == @selector(toggleEditorInTitleBar:)) {
		BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
		[menuItem setState:disabled ? NSOffState : NSOnState];
	}
    
    BOOL toolbarVisible = [[[NSApp keyWindow] toolbar] isVisible];
    if (toolbarVisible) {
        return NO;
    }
    
	return YES;
}

- (void)buildWillStart:(NSNotification *)notification
{
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
			if (schemeView) {
				[schemeView.spinner startAnimation:nil];
			}
		}
	}
	@catch (NSException *exception) { }
}

- (void)buildDidStop:(NSNotification *)notification
{
	@try {
		NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
		for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
			OMSchemeSelectionView *schemeView = [self schemePopUpButtonContainerForWindow:window];
			if (schemeView) {
				[schemeView.spinner stopAnimation:nil];
			}
		}
	}
	@catch (NSException *exception) { }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	NSSplitView *splitView = [notification object];
	//TODO: This is a bit fragile, is there a better way to detect the navigator split view?
	if (splitView.subviews.count == 3 && splitView.isVertical) {
		BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
		
		NSWindow *window = splitView.window;
        NSView *windowFrameView = [[window contentView] superview];
		NSView *schemeView = [self schemePopUpButtonContainerForWindow:window];
		if (schemeView) {
			BOOL toolbarVisible = [[window toolbar] isVisible];
			[schemeView setHidden:toolbarVisible || titleBarDisabled];
			NSView *leftMostView = [[splitView subviews] objectAtIndex:0];
			CGFloat leftMostWidth = leftMostView.bounds.size.width;
			if (leftMostWidth == 0) {
				leftMostWidth = 280.0; //use a default width if the navigator is hidden
			}
			NSView *titleView = [self windowTitleViewForWindow:window];
			if (titleView) {
				leftMostWidth = MIN(leftMostWidth, titleView.frame.origin.x - 20);
			}
			schemeView.frame = NSMakeRect(schemeView.frame.origin.x, schemeView.frame.origin.y, leftMostWidth - 80 + 20, schemeView.frame.size.height);
        }
        
        NSView *editorSelectionView = [self editorSegmentedControlContainerForWindow:window];
        if (editorSelectionView) {
            BOOL toolbarVisible = [[window toolbar] isVisible];
            BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
            [editorSelectionView setHidden:toolbarVisible || titleBarDisabled];
            editorSelectionView.frame = NSMakeRect(windowFrameView.bounds.size.width - EDITOR_CONTROL_RIGHT_MARGIN, windowFrameView.bounds.size.height - EDITOR_CONTROL_TOP_MARGIN, EDITOR_CONTROL_WIDTH, 20);
        }
	}
}

- (void)selectDestination:(id)sender
{
	NSDictionary *info = [sender representedObject];
	id destination = [info objectForKey:@"destination"];
	id context = [info objectForKey:@"context"];
	@try {
		id runContextManager = [[[NSApp keyWindow] windowController] valueForKeyPath:@"_workspace.runContextManager"];
		[runContextManager setActiveRunContext:context andRunDestination:destination];
	}
	@catch (NSException *exception) { }
}

- (void)selectRunContext:(id)sender
{
	NSDictionary *info = [sender representedObject];
	id context = [info objectForKey:@"context"];
	@try {
		id runContextManager = [[[NSApp keyWindow] windowController] valueForKeyPath:@"_workspace.runContextManager"];
		id bestDestination = [runContextManager _bestDestinationForScheme:context previousDestination:[runContextManager activeRunDestination]];
		[runContextManager setActiveRunContext:context andRunDestination:bestDestination];
	}
	@catch (NSException *exception) { }
}

- (void)windowDidEndLiveResize:(NSNotification *)notification
{
	NSWindow *window = [notification object];
	NSView *schemeView = [self schemePopUpButtonContainerForWindow:window];
	if (schemeView) {
		double delayInSeconds = 0.0;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			BOOL toolbarVisible = [[window toolbar] isVisible];
			BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
			[schemeView setHidden:toolbarVisible || titleBarDisabled];
		});
	}
    
    NSView *editorSelectionView = [self editorSegmentedControlContainerForWindow:window];
    if (editorSelectionView) {
        double delayInSeconds = 0.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            BOOL toolbarVisible = [[window toolbar] isVisible];
            BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
            [editorSelectionView setHidden:toolbarVisible || titleBarDisabled];
        });
    }
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSWindow *window = [notification object];
	if ([window isKindOfClass:NSClassFromString(@"IDEWorkspaceWindow")]) {
		@try {
			NSWindowController *windowController = [window windowController];
			if ([windowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
                self.currentWindowController = windowController;
				id workspace = [windowController valueForKey:@"_workspace"];
				NSNotification *dummyNotification = [NSNotification notificationWithName:@"IDEWorkspaceBuildProductsLocationDidChangeNotification" object:workspace];
				[self buildProductsLocationDidChange:dummyNotification];
			}
            
            NSView *editorSelectionView = [self editorSegmentedControlContainerForWindow:window];
            if (editorSelectionView) {
                double delayInSeconds = 0.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    BOOL toolbarVisible = [[window toolbar] isVisible];
                    BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
                    [editorSelectionView setHidden:toolbarVisible || titleBarDisabled];
                });
            }
		}
		@catch (NSException *exception) { }
	}
}

- (void)buildProductsLocationDidChange:(NSNotification *)notification
{
	@try {
		id workspace = [notification object];
		if ([workspace isKindOfClass:NSClassFromString(@"IDEWorkspace")]) {
			NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
			for (NSWindowController *workspaceWindowController in workspaceWindowControllers) {
				id workspaceForWindowController = [workspaceWindowController valueForKey:@"_workspace"];
				if (workspace == workspaceForWindowController) {
					NSPopUpButton *popUpButton = [self schemePopUpButtonForWindow:workspaceWindowController.window];
					NSMenu *menu = [[[NSMenu alloc] init] autorelease];
					[menu setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
					
					id runContextManager = [workspace valueForKey:@"runContextManager"];
					id activeDestination = [runContextManager valueForKey:@"_activeRunDestination"];
					id activeScheme = [runContextManager valueForKey:@"_activeRunContext"];
					NSArray *runContexts = [runContextManager performSelector:@selector(runContexts)];
					for (id scheme in runContexts) {
						NSMenuItem *schemeItem = [[[NSMenuItem alloc] initWithTitle:[scheme valueForKey:@"name"] action:@selector(selectRunContext:) keyEquivalent:@""] autorelease];
						NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:scheme, @"context", nil];
						[schemeItem setRepresentedObject:info];
						if (scheme == activeScheme) {
							[schemeItem setState:NSOnState];
							[schemeItem setTitle:[NSString stringWithFormat:@"%@ | %@", [scheme name], [activeDestination displayName]]];
						} else {
							[schemeItem setState:NSOffState];
						}
						NSArray *destinations = [scheme valueForKey:@"availableRunDestinations"];
						if (destinations.count > 0) {
							NSMenu *submenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
							[schemeItem setSubmenu:submenu];
							for (id destination in destinations) {
								NSMenuItem *destinationItem = [[[NSMenuItem alloc] initWithTitle:[destination valueForKey:@"fullDisplayName"] action:@selector(selectDestination:) keyEquivalent:@""] autorelease];
								NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:destination, @"destination", scheme, @"context", nil];
								[destinationItem setRepresentedObject:info];
								[destinationItem setTarget:self];
								[destinationItem setState:(destination == activeDestination) ? NSOnState : NSOffState];
								[submenu addItem:destinationItem];
							}
						}
						[schemeItem setTarget:self];
						[menu addItem:schemeItem];
					}
					[menu addItem:[NSMenuItem separatorItem]];
					NSArray *activeSchemeDestinations = [activeScheme valueForKey:@"availableRunDestinations"];
					for (id destination in activeSchemeDestinations) {
						NSMenuItem *destinationItem = [[[NSMenuItem alloc] initWithTitle:[destination valueForKey:@"fullDisplayName"] action:@selector(selectDestination:) keyEquivalent:@""] autorelease];
						NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:destination, @"destination", activeScheme, @"context", nil];
						[destinationItem setRepresentedObject:info];
						[destinationItem setTarget:self];
						[destinationItem setState:(destination == activeDestination) ? NSOnState : NSOffState];
						[menu addItem:destinationItem];
					}
					[popUpButton setMenu:menu];
				}
			}
		}
	}
	@catch (NSException *exception) {
		
	}
}

- (NSView *)windowTitleViewForWindow:(NSWindow *)window
{
	NSView *windowFrameView = [[window contentView] superview];
	for (NSView *view in windowFrameView.subviews) {
		if ([view isKindOfClass:NSClassFromString(@"DVTDualProxyWindowTitleView")]) {
			return view;
		}
	}
	return nil;
}

- (NSPopUpButton *)schemePopUpButtonForWindow:(NSWindow *)window
{
	OMSchemeSelectionView *container = [self schemePopUpButtonContainerForWindow:window];
	return container.popUpButton;
}

- (NSSegmentedControl *)editorSegmentedControlForWindow:(NSWindow *)window
{
	JTEditorSelectionView *container = [self editorSegmentedControlContainerForWindow:window];
	return container.editorSegmentedControl;
}

- (OMSchemeSelectionView *)schemePopUpButtonContainerForWindow:(NSWindow *)window
{
	if ([window isKindOfClass:NSClassFromString(@"IDEWorkspaceWindow")]) {
		NSView *windowFrameView = [[window contentView] superview];
		OMSchemeSelectionView *popUpContainerView = [windowFrameView viewWithTag:SCHEME_POPUP_BUTTON_CONTAINER_TAG];
		if (!popUpContainerView) {
			
			CGFloat buttonWidth = 200.0;
			NSView *titleView = [self windowTitleViewForWindow:window];
			if (titleView) {
				buttonWidth = MIN(buttonWidth, titleView.frame.origin.x - 10 - 80);
			}
			
			popUpContainerView = [[[OMSchemeSelectionView alloc] initWithFrame:NSMakeRect(80, windowFrameView.bounds.size.height - 22, buttonWidth + 20, 20)] autorelease];
			popUpContainerView.tag = SCHEME_POPUP_BUTTON_CONTAINER_TAG;
			popUpContainerView.autoresizingMask = NSViewMinYMargin;
			
			BOOL toolbarVisible = [[window toolbar] isVisible];
			BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableSchemeSelectionInTitleBar];
			
			[popUpContainerView setHidden:toolbarVisible || titleBarDisabled];
			[windowFrameView addSubview:popUpContainerView];
			
		}
		return popUpContainerView;
	}
	return nil;
}

- (JTEditorSelectionView *)editorSegmentedControlContainerForWindow:(NSWindow *)window
{
	if ([window isKindOfClass:NSClassFromString(@"IDEWorkspaceWindow")]) {
		NSView *windowFrameView = [[window contentView] superview];
		JTEditorSelectionView *controlContainerView = [windowFrameView viewWithTag:EDITOR_CONTROL_CONTAINER_TAG];
        
        if (self.currentWindowController) {
            @try {
                NSNumber *editorMode = [self.currentWindowController valueForKeyPath:@"editorArea.editorMode"];
                controlContainerView.editorSegmentedControl.selectedSegment = [editorMode integerValue];
            } @catch (NSException *exception) {}
        }
        
		if (!controlContainerView) {
            
			controlContainerView = [[[JTEditorSelectionView alloc] initWithFrame:NSMakeRect(windowFrameView.bounds.size.width - EDITOR_CONTROL_RIGHT_MARGIN, windowFrameView.bounds.size.height - EDITOR_CONTROL_TOP_MARGIN, EDITOR_CONTROL_WIDTH, 20)] autorelease];
			controlContainerView.tag = EDITOR_CONTROL_CONTAINER_TAG;
			controlContainerView.autoresizingMask = NSViewMinYMargin;
            
            [controlContainerView.editorSegmentedControl setTarget:self];
            [controlContainerView.editorSegmentedControl setAction:@selector(editorControllerSelected:)];
			
			BOOL toolbarVisible = [[window toolbar] isVisible];
			BOOL titleBarDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMMiniXcodeDisableEditorSelectionInTitleBar];
			
			[controlContainerView setHidden:toolbarVisible || titleBarDisabled];
			[windowFrameView addSubview:controlContainerView];
			
		}
		return controlContainerView;
	}
	return nil;
}

- (void)editorControllerSelected:(id)sender
{
    NSSegmentedControl *segmentedControl = sender;
    NSViewController *workspaceTabController = [self.currentWindowController valueForKeyPath:@"activeWorkspaceTabController"];
    if (segmentedControl.selectedSegment == 0) {
        [workspaceTabController performSelector:@selector(changeToStandardEditor:) withObject:nil];
    } else if (segmentedControl.selectedSegment == 1) {
        [workspaceTabController performSelector:@selector(changeToGeniusEditor:) withObject:nil];
    } else if (segmentedControl.selectedSegment == 2) {
        [workspaceTabController performSelector:@selector(changeToVersionEditor:) withObject:nil];
    }
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

@end
