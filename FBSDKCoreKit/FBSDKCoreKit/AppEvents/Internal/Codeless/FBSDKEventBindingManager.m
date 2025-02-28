// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TargetConditionals.h"

#if !TARGET_OS_TV

 #import "FBSDKEventBindingManager.h"

 #import <UIKit/UIKit.h>

 #import <objc/runtime.h>

 #import "FBSDKCodelessPathComponent.h"
 #import "FBSDKCoreKitBasicsImport.h"
 #import "FBSDKEventBinding.h"
 #import "FBSDKEventLogging.h"
 #import "FBSDKSwizzling.h"
 #import "FBSDKViewHierarchy.h"
 #import "FBSDKViewHierarchyMacros.h"

 #define ReactNativeTargetKey          @"target"
 #define ReactNativeTouchEndEventName  @"touchEnd"

 #define ReactNativeClassRCTTextView   "RCTTextView"
 #define ReactNativeClassRCTImageView  "RCTImageView"
 #define ReactNativeClassRCTTouchEvent "RCTTouchEvent"
 #define ReactNativeClassRCTTouchHandler "RCTTouchHandler"

@interface FBSDKEventBindingManager ()

@property (nonnull, nonatomic) id<FBSDKEventLogging> eventLogger;
@property (nonnull, nonatomic) Class<FBSDKSwizzling> swizzler;
@property (nonatomic) BOOL isStarted;
@property (nullable, nonatomic) NSMutableDictionary<NSNumber *, id> *reactBindings;
@property (nonnull, nonatomic) NSSet *validClasses;
@property (nonatomic) BOOL hasReactNative;
@property (nullable, nonatomic) NSArray *eventBindings;

@end

@implementation FBSDKEventBindingManager

- (instancetype)initWithSwizzler:(Class<FBSDKSwizzling>)swizzling
                     eventLogger:(id<FBSDKEventLogging>)eventLogger;
{
  if ((self = [super init])) {
    _swizzler = swizzling;
    _eventLogger = eventLogger;
    _hasReactNative = NO;
    _isStarted = NO;
    _reactBindings = [NSMutableDictionary dictionary];

    NSMutableSet *classes = [NSMutableSet set];
    [classes addObject:UIControl.class];
    [classes addObject:UITableView.class];
    [classes addObject:UICollectionView.class];
    // ReactNative
    Class classRCTRootView = objc_lookUpClass(ReactNativeClassRCTRootView);
    if (classRCTRootView != nil) {
      _hasReactNative = YES;
      Class classRCTView = objc_lookUpClass(ReactNativeClassRCTView);
      Class classRCTTextView = objc_lookUpClass(ReactNativeClassRCTTextView);
      Class classRCTImageView = objc_lookUpClass(ReactNativeClassRCTImageView);
      if (classRCTView) {
        [classes addObject:classRCTView];
      }
      if (classRCTTextView) {
        [classes addObject:classRCTTextView];
      }
      if (classRCTImageView) {
        [classes addObject:classRCTImageView];
      }
    }
    _validClasses = [NSSet setWithSet:classes];
  }
  return self;
}

- (instancetype)initWithJSON:(NSDictionary<NSString *, id> *)dict
                    swizzler:(Class<FBSDKSwizzling>)swizzler
                 eventLogger:(id<FBSDKEventLogging>)eventLogger
{
  if ((self = [self initWithSwizzler:swizzler eventLogger:eventLogger])) {
    NSArray *eventBindingsDict = [FBSDKTypeUtility arrayValue:dict[@"event_bindings"]];
    NSMutableArray *bindings = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *d in eventBindingsDict) {
      FBSDKEventBinding *e = [[FBSDKEventBinding alloc] initWithJSON:d eventLogger:eventLogger];
      [FBSDKTypeUtility array:bindings addObject:e];
    }
    _eventBindings = [bindings copy];
  }
  return self;
}

- (NSArray *)parseArray:(NSArray *)array
{
  NSMutableArray *result = [NSMutableArray array];

  for (NSDictionary<NSString *, id> *json in array) {
    FBSDKEventBinding *binding = [[FBSDKEventBinding alloc] initWithJSON:json
                                                             eventLogger:self.eventLogger];
    [FBSDKTypeUtility array:result addObject:binding];
  }

  return [result copy];
}

 #pragma clang diagnostic push
 #pragma clang diagnostic ignored "-Wundeclared-selector"
- (void)start
{
  if (self.isStarted) {
    return;
  }

  if (0 == self.eventBindings.count) {
    return;
  }

  self.isStarted = YES;

  void (^blockToWindow)(id view) = ^(id view) {
    [self matchView:view delegate:nil];
  };

  [self.swizzler swizzleSelector:@selector(didMoveToWindow)
                         onClass:UIControl.class
                       withBlock:blockToWindow
                           named:@"map_control"];

  // ReactNative
  if (self.hasReactNative) { // If app is built via ReactNative
    Class classRCTView = objc_lookUpClass(ReactNativeClassRCTView);
    Class classRCTTextView = objc_lookUpClass(ReactNativeClassRCTTextView);
    Class classRCTImageView = objc_lookUpClass(ReactNativeClassRCTImageView);
    Class classRCTTouchHandler = objc_lookUpClass(ReactNativeClassRCTTouchHandler);

    // All react-native views would be added tp RCTRootView, so no need to check didMoveToWindow
    [self.swizzler swizzleSelector:@selector(didMoveToWindow)
                           onClass:classRCTView
                         withBlock:blockToWindow
                             named:@"match_react_native"];
    [self.swizzler swizzleSelector:@selector(didMoveToWindow)
                           onClass:classRCTTextView
                         withBlock:blockToWindow
                             named:@"match_react_native"];
    [self.swizzler swizzleSelector:@selector(didMoveToWindow)
                           onClass:classRCTImageView
                         withBlock:blockToWindow
                             named:@"match_react_native"];

    // RCTTouchHandler handles with touch events, like touchEnd and uses RCTEventDispather to dispatch events, so we can check _updateAndDispatchTouches to fire events
    [self.swizzler swizzleSelector:@selector(_updateAndDispatchTouches:eventName:)
                           onClass:classRCTTouchHandler
                         withBlock:^(id touchHandler, SEL command, id touches, id eventName) {
                           [self handleReactNativeTouchesWithHandler:touchHandler command:command touches:touches eventName:eventName];
                         }
                             named:@"dispatch_rn_event"];
  }

  // UITableView
  void (^tableViewBlock)(UITableView *tableView,
                         SEL cmd,
                         id<UITableViewDelegate> delegate) =
  ^(UITableView *tableView, SEL cmd, id<UITableViewDelegate> delegate) {
    if (!delegate) {
      return;
    }

    [self matchView:tableView delegate:delegate];
  };
  [self.swizzler swizzleSelector:@selector(setDelegate:)
                         onClass:UITableView.class
                       withBlock:tableViewBlock
                           named:@"match_table_view"];
  // UICollectionView
  void (^collectionViewBlock)(UICollectionView *collectionView,
                              SEL cmd,
                              id<UICollectionViewDelegate> delegate) =
  ^(UICollectionView *collectionView, SEL cmd, id<UICollectionViewDelegate> delegate) {
    if (nil == delegate) {
      return;
    }

    [self matchView:collectionView delegate:delegate];
  };
  [self.swizzler swizzleSelector:@selector(setDelegate:)
                         onClass:UICollectionView.class
                       withBlock:collectionViewBlock
                           named:@"handle_collection_view"];
}

- (void)rematchBindings
{
  if (0 == self.eventBindings.count) {
    return;
  }

  NSArray *windows = [UIApplication sharedApplication].windows;
  for (UIWindow *window in windows) {
    [self matchSubviewsIn:window];
  }
}

- (void)matchSubviewsIn:(UIView *)view
{
  if (!view) {
    return;
  }

  for (UIView *subview in view.subviews) {
    BOOL isValidClass = NO;
    for (Class cls in self.validClasses) {
      if ([subview isKindOfClass:cls]) {
        isValidClass = YES;
        break;
      }
    }

    if (isValidClass) {
      if ([subview isKindOfClass:UITableView.class]) {
        UITableView *tableView = (UITableView *)subview;
        if (tableView.delegate) {
          [self matchView:subview delegate:tableView.delegate];
        }
      } else if ([subview isKindOfClass:UICollectionView.class]) {
        UICollectionView *collectionView = (UICollectionView *)subview;
        if (collectionView.delegate) {
          [self matchView:subview delegate:collectionView.delegate];
        }
      } else {
        [self matchView:subview delegate:nil];
      }
    }

    if (![subview isKindOfClass:UIControl.class]) {
      [self matchSubviewsIn:subview];
    }
  }
}

// check if the view is matched to any event
- (void)matchView:(UIView *)view delegate:(id)delegate
{
  if (0 == self.eventBindings.count) {
    return;
  }

  __weak Class<FBSDKSwizzling> weakSwizzler = self.swizzler;
  __block BOOL hasReactNative = self.hasReactNative;
  fb_dispatch_on_main_thread(^{
    if (![view window]) {
      return;
    }

    NSArray *path = [FBSDKViewHierarchy getPath:view];

    void (^matchBlock)(void) = ^void () {
      if ([view isKindOfClass:UIControl.class]) {
        UIControl *control = (UIControl *)view;
        for (FBSDKEventBinding *binding in self->_eventBindings) {
          if ([FBSDKEventBinding isPath:binding.path matchViewPath:path]) {
            fb_dispatch_on_main_thread(^{
              [control addTarget:binding
                          action:@selector(trackEvent:)
                forControlEvents:UIControlEventTouchUpInside];
            });
            break;
          }
        }
      } else if (hasReactNative
                 && [view respondsToSelector:@selector(reactTag)]) {
        for (FBSDKEventBinding *binding in self->_eventBindings) {
          if ([FBSDKEventBinding isPath:binding.path matchViewPath:path]) {
            fb_dispatch_on_main_thread(^{
              if (view) {
                NSNumber *reactTag = [FBSDKViewHierarchy getViewReactTag:view];
                if (reactTag != nil) {
                  [FBSDKTypeUtility dictionary:self->_reactBindings setObject:binding forKey:reactTag];
                }
              }
            });
            break;
          }
        }
      } else if ([view isKindOfClass:UITableView.class]
                 && [delegate conformsToProtocol:@protocol(UITableViewDelegate)]) {
        void (^tableViewBlock)(void) = ^void () {
          NSMutableSet *matchedBindings = [NSMutableSet set];
          for (FBSDKEventBinding *binding in self->_eventBindings) {
            if (binding.path.count > 1) {
              NSArray *shortPath = [binding.path
                                    subarrayWithRange:NSMakeRange(0, binding.path.count - 1)];
              if ([FBSDKEventBinding isPath:shortPath matchViewPath:path]) {
                [matchedBindings addObject:binding];
              }
            }
          }

          if (matchedBindings.count > 0) {
            NSArray *bindings = matchedBindings.allObjects;
            void (^block)(id, SEL, id, id) = ^(id target, SEL command, UITableView *tableView, NSIndexPath *indexPath) {
              [self handleDidSelectRowWithBindings:bindings target:target command:command tableView:tableView indexPath:indexPath];
            };
            [weakSwizzler swizzleSelector:@selector(tableView:didSelectRowAtIndexPath:)
                                  onClass:[delegate class]
                                withBlock:block
                                    named:@"handle_table_view"];
          }
        };
      #if FBTEST
        tableViewBlock();
      #else
        fb_dispatch_on_default_thread(tableViewBlock);
      #endif
      } else if ([view isKindOfClass:UICollectionView.class]
                 && [delegate conformsToProtocol:@protocol(UICollectionViewDelegate)]) {
        void (^collectionViewBlock)(void) = ^void () {
          NSMutableSet *matchedBindings = [NSMutableSet set];
          for (FBSDKEventBinding *binding in self->_eventBindings) {
            if (binding.path.count > 1) {
              NSArray *shortPath = [binding.path
                                    subarrayWithRange:NSMakeRange(0, binding.path.count - 1)];
              if ([FBSDKEventBinding isPath:shortPath matchViewPath:path]) {
                [matchedBindings addObject:binding];
              }
            }
          }

          if (matchedBindings.count > 0) {
            NSArray *bindings = matchedBindings.allObjects;
            void (^block)(id, SEL, id, id) = ^(id target, SEL command, UICollectionView *collectionView, NSIndexPath *indexPath) {
              [self handleDidSelectItemWithBindings:bindings target:target command:command collectionView:collectionView indexPath:indexPath];
            };
            [weakSwizzler swizzleSelector:@selector(collectionView:didSelectItemAtIndexPath:)
                                  onClass:[delegate class]
                                withBlock:block
                                    named:@"handle_collection_view"];
          }
        };
      #if FBTEST
        collectionViewBlock();
      #else
        fb_dispatch_on_default_thread(collectionViewBlock);
      #endif
      }
    };

  #if FBTEST
    matchBlock();
  #else
    fb_dispatch_on_default_thread(matchBlock);
  #endif
  });
}

 #pragma clang diagnostic pop
- (void)updateBindings:(NSArray *)bindings
{
  if (self.eventBindings.count > 0 && self.eventBindings.count == bindings.count) {
    // Check whether event bindings are the same
    BOOL isSame = YES;
    for (int i = 0; i < self.eventBindings.count; i++) {
      if (![[FBSDKTypeUtility array:self.eventBindings objectAtIndex:i] isEqualToBinding:[FBSDKTypeUtility array:bindings objectAtIndex:i]]) {
        isSame = NO;
        break;
      }
    }

    if (isSame) {
      return;
    }
  }

  self.eventBindings = bindings;
  [self.reactBindings removeAllObjects];
  if (!self.isStarted) {
    [self start];
  }

  fb_dispatch_on_main_thread(^{
    [self rematchBindings];
  });
}

// MARK: Method Replacements

- (void)handleReactNativeTouchesWithHandler:(id)handler
                                    command:(SEL)command
                                    touches:(id)touches
                                  eventName:(id)eventName
{
  if ([touches isKindOfClass:NSSet.class] && [eventName isKindOfClass:NSString.class]) {
    @try {
      NSString *reactEventName = (NSString *)eventName;
      NSSet<UITouch *> *reactTouches = (NSSet<UITouch *> *)touches;
      if ([reactEventName isEqualToString:ReactNativeTouchEndEventName]) {
        for (UITouch *touch in reactTouches) {
          UIView *targetView = ((UITouch *)touch).view.superview;
          NSNumber *reactTag = nil;
          // Find the closest React-managed touchable view like RCTTouchHandler
          while (targetView) {
            reactTag = [FBSDKViewHierarchy getViewReactTag:targetView];
            if (reactTag != nil && targetView.userInteractionEnabled) {
              break;
            }
            targetView = targetView.superview;
          }
          FBSDKEventBinding *eventBinding = self->_reactBindings[reactTag];
          if (reactTag != nil && eventBinding != nil) {
            [eventBinding trackEvent:nil];
          }
        }
      }
    } @catch (NSException *exception) {
      // Catch exception here to prevent LytroKit from crashing app
    }
  }
};

- (void)handleDidSelectRowWithBindings:(NSArray<FBSDKEventBinding *> *)bindings
                                target:(nullable id)target
                               command:(nullable SEL)command
                             tableView:(UITableView *)tableView
                             indexPath:(NSIndexPath *)indexPath
{
  fb_dispatch_on_main_thread(^{
    for (FBSDKEventBinding *binding in bindings) {
      FBSDKCodelessPathComponent *component = binding.path.lastObject;
      if ((component.section == -1 || component.section == indexPath.section)
          && (component.row == -1 || component.row == indexPath.row)) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
          [binding trackEvent:cell];
        }
      }
    }
  });
}

- (void)handleDidSelectItemWithBindings:(NSArray<FBSDKEventBinding *> *)bindings
                                 target:(nullable id)target
                                command:(nullable SEL)command
                         collectionView:(UICollectionView *)collectionView
                              indexPath:(NSIndexPath *)indexPath
{
  fb_dispatch_on_main_thread(^{
    for (FBSDKEventBinding *binding in bindings) {
      FBSDKCodelessPathComponent *component = binding.path.lastObject;
      if ((component.section == -1 || component.section == indexPath.section)
          && (component.row == -1 || component.row == indexPath.row)) {
        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
        if (cell) {
          [binding trackEvent:cell];
        }
      }
    }
  });
}

- (NSSet *)validClasses
{
  return _validClasses;
}

 #if DEBUG
  #if FBTEST

- (void)setReactBindings:(NSMutableDictionary<NSNumber *, id> *)bindings
{
  _reactBindings = bindings;
}

  #endif
 #endif

@end

#endif
