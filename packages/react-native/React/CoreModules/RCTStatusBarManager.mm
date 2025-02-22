/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTStatusBarManager.h"
#import "CoreModulesPlugins.h"

#import <React/RCTEventDispatcherProtocol.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import <FBReactNativeSpec/FBReactNativeSpec.h>

@implementation RCTConvert (UIStatusBar)

+ (UIStatusBarStyle)UIStatusBarStyle:(id)json RCT_DYNAMIC
{
  static NSDictionary *mapping;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    mapping = @{
      @"default" : @(UIStatusBarStyleDefault),
      @"light-content" : @(UIStatusBarStyleLightContent),
      @"dark-content" : @(UIStatusBarStyleDarkContent)
    };
  });
  return _RCT_CAST(
      UIStatusBarStyle,
      [RCTConvertEnumValue("UIStatusBarStyle", mapping, @(UIStatusBarStyleDefault), json) integerValue]);
}

RCT_ENUM_CONVERTER(
    UIStatusBarAnimation,
    (@{
      @"none" : @(UIStatusBarAnimationNone),
      @"fade" : @(UIStatusBarAnimationFade),
      @"slide" : @(UIStatusBarAnimationSlide),
    }),
    UIStatusBarAnimationNone,
    integerValue);

@end

@interface RCTStatusBarManager () <NativeStatusBarManagerIOSSpec>
@end

@implementation RCTStatusBarManager

static BOOL RCTViewControllerBasedStatusBarAppearance()
{
  static BOOL value;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    value =
        [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"]
                ?: @YES boolValue];
  });

  return value;
}

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[ @"statusBarFrameDidChange", @"statusBarFrameWillChange" ];
}

- (void)startObserving
{
#if !TARGET_OS_VISION
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(applicationDidChangeStatusBarFrame:)
             name:UIApplicationDidChangeStatusBarFrameNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(applicationWillChangeStatusBarFrame:)
             name:UIApplicationWillChangeStatusBarFrameNotification
           object:nil];
#endif
}

- (void)stopObserving
{
#if !TARGET_OS_VISION
  [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
}

- (void)emitEvent:(NSString *)eventName forNotification:(NSNotification *)notification
{
#if !TARGET_OS_VISION
  CGRect frame = [notification.userInfo[UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
  NSDictionary *event = @{
    @"frame" : @{
      @"x" : @(frame.origin.x),
      @"y" : @(frame.origin.y),
      @"width" : @(frame.size.width),
      @"height" : @(frame.size.height),
    },
  };
  [self sendEventWithName:eventName body:event];
#endif
}

- (void)applicationDidChangeStatusBarFrame:(NSNotification *)notification
{
  [self emitEvent:@"statusBarFrameDidChange" forNotification:notification];
}

- (void)applicationWillChangeStatusBarFrame:(NSNotification *)notification
{
  [self emitEvent:@"statusBarFrameWillChange" forNotification:notification];
}

RCT_EXPORT_METHOD(getHeight : (RCTResponseSenderBlock)callback)
{
#if !TARGET_OS_VISION
  callback(@[ @{
    @"height" : @(RCTSharedApplication().statusBarFrame.size.height),
  } ]);
#else
    callback(@[ @{
    @"height" : @(RCTUIStatusBarManager().statusBarFrame.size),
    } ]);
#endif
}

RCT_EXPORT_METHOD(setStyle : (NSString *)style animated : (BOOL)animated)
{
#if !TARGET_OS_VISION
  dispatch_async(dispatch_get_main_queue(), ^{
    UIStatusBarStyle statusBarStyle = [RCTConvert UIStatusBarStyle:style];
    if (RCTViewControllerBasedStatusBarAppearance()) {
      RCTLogError(@"RCTStatusBarManager module requires that the \
                UIViewControllerBasedStatusBarAppearance key in the Info.plist is set to NO");
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [RCTSharedApplication() setStatusBarStyle:statusBarStyle animated:animated];
  }
#pragma clang diagnostic pop
  });
#endif
}

RCT_EXPORT_METHOD(setHidden : (BOOL)hidden withAnimation : (NSString *)withAnimation)
{
#if !TARGET_OS_VISION
  dispatch_async(dispatch_get_main_queue(), ^{
    UIStatusBarAnimation animation = [RCTConvert UIStatusBarAnimation:withAnimation];
    if (RCTViewControllerBasedStatusBarAppearance()) {
      RCTLogError(@"RCTStatusBarManager module requires that the \
                UIViewControllerBasedStatusBarAppearance key in the Info.plist is set to NO");
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [RCTSharedApplication() setStatusBarHidden:hidden withAnimation:animation];
#pragma clang diagnostic pop
    }
  });
#endif
}

RCT_EXPORT_METHOD(setNetworkActivityIndicatorVisible : (BOOL)visible)
{
#if !TARGET_OS_VISION
    RCTSharedApplication().networkActivityIndicatorVisible = visible;
#endif
}

- (facebook::react::ModuleConstants<JS::NativeStatusBarManagerIOS::Constants>)getConstants
{
  __block facebook::react::ModuleConstants<JS::NativeStatusBarManagerIOS::Constants> constants;
  RCTUnsafeExecuteOnMainQueueSync(^{
    constants = facebook::react::typedConstants<JS::NativeStatusBarManagerIOS::Constants>({
#if TARGET_OS_VISION
        .HEIGHT = RCTUIStatusBarManager().statusBarFrame.size.height,
#else
        .HEIGHT = RCTSharedApplication().statusBarFrame.size.height,
#endif
        .DEFAULT_BACKGROUND_COLOR = std::nullopt,
    });
  });

  return constants;
}

- (facebook::react::ModuleConstants<JS::NativeStatusBarManagerIOS::Constants>)constantsToExport
{
  return (facebook::react::ModuleConstants<JS::NativeStatusBarManagerIOS::Constants>)[self getConstants];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeStatusBarManagerIOSSpecJSI>(params);
}

@end

Class RCTStatusBarManagerCls(void)
{
  return RCTStatusBarManager.class;
}
