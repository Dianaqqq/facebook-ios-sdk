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

#import "FBSDKApplicationDelegate.h"

#import <objc/runtime.h>

#import "FBSDKAccessToken+Internal.h"
#import "FBSDKAccessTokenExpirer.h"
#import "FBSDKAppEvents+AppEventsConfiguring.h"
#import "FBSDKAppEvents+ApplicationActivating.h"
#import "FBSDKAppEvents+ApplicationLifecycleObserving.h"
#import "FBSDKAppEvents+ApplicationStateSetting.h"
#import "FBSDKAppEvents+EventLogging.h"
#import "FBSDKAppEvents+Internal.h"
#import "FBSDKAppEvents+SourceApplicationTracking.h"
#import "FBSDKAppEventsConfigurationManager.h"
#import "FBSDKAppEventsState.h"
#import "FBSDKAppEventsStateFactory.h"
#import "FBSDKAppEventsStateManager+AppEventsStatePersisting.h"
#import "FBSDKAppEventsUtility+AdvertiserIDProviding.h"
#import "FBSDKApplicationLifecycleObserving.h"
#import "FBSDKAtePublisherFactory.h"
#import "FBSDKAuthenticationStatusUtility.h"
#import "FBSDKAuthenticationToken+AuthenticationTokenProtocols.h"
#import "FBSDKAuthenticationToken+Internal.h"
#import "FBSDKBridgeAPI+ApplicationObserving.h"
#import "FBSDKButton+Subclass.h"
#import "FBSDKCoreKitBasicsImport.h"
#import "FBSDKCrashShield+Internal.h"
#import "FBSDKDynamicFrameworkLoader.h"
#import "FBSDKError+Internal.h"
#import "FBSDKErrorReport+ErrorReporting.h"
#import "FBSDKEventDeactivationManager+Protocols.h"
#import "FBSDKFeatureManager+FeatureChecking.h"
#import "FBSDKFeatureManager+FeatureDisabling.h"
#import "FBSDKGateKeeperManager.h"
#import "FBSDKGraphRequest.h"
#import "FBSDKGraphRequestFactory.h"
#import "FBSDKGraphRequestPiggybackManager+Internal.h"
#import "FBSDKInstrumentManager.h"
#import "FBSDKInternalUtility+Internal.h"
#import "FBSDKLogger+Logging.h"
#import "FBSDKPaymentObserver.h"
#import "FBSDKPaymentObserver+PaymentObserving.h"
#import "FBSDKProfileProtocols.h"
#import "FBSDKRestrictiveDataFilterManager+Protocols.h"
#import "FBSDKServerConfiguration.h"
#import "FBSDKServerConfigurationManager+ServerConfigurationProviding.h"
#import "FBSDKSettings+Internal.h"
#import "FBSDKSettings+SettingsLogging.h"
#import "FBSDKSettingsLogging.h"
#import "FBSDKSwizzler+Swizzling.h"
#import "FBSDKTimeSpentRecordingFactory.h"
#import "FBSDKTokenCache.h"
#import "NSNotificationCenter+Extensions.h"
#import "NSUserDefaults+FBSDKDataPersisting.h"

#if !TARGET_OS_TV
 #import "FBSDKAEMNetworker.h"
 #import "FBSDKAppLinkUtility+Internal.h"
 #import "FBSDKBackgroundEventLogger.h"
 #import "FBSDKBackgroundEventLogging.h"
 #import "FBSDKCodelessIndexer+Internal.h"
 #import "FBSDKContainerViewController.h"
 #import "FBSDKCoreKitAEMImport.h"
 #import "FBSDKFeatureExtractor.h"
 #import "FBSDKFeatureExtractor+Internal.h"
 #import "FBSDKMeasurementEventListener.h"
 #import "FBSDKMetadataIndexer+MetadataIndexing.h"
 #import "FBSDKModelManager.h"
 #import "FBSDKModelManager+RulesFromKeyProvider.h"
 #import "FBSDKProfile+Internal.h"
 #import "FBSDKSKAdNetworkReporter+AppEventsReporter.h"
 #import "FBSDKSKAdNetworkReporter+Internal.h"
 #import "FBSDKURLOpener.h"
 #import "FBSDKWebDialogView.h"
 #import "FBSDKWebViewFactory.h"
 #import "SKAdNetwork+ConversionValueUpdating.h"
 #import "UIApplication+URLOpener.h"
#endif

static NSString *const FBSDKAppLinkInboundEvent = @"fb_al_inbound";
static NSString *const FBSDKKitsBitmaskKey = @"com.facebook.sdk.kits.bitmask";
static BOOL hasInitializeBeenCalled = NO;
static UIApplicationState _applicationState;

@interface FBSDKApplicationDelegate ()

@property (nonnull, nonatomic, readonly) id<FBSDKFeatureChecking> featureChecker;
@property (nonnull, nonatomic, readonly) Class<FBSDKAccessTokenProviding, FBSDKAccessTokenSetting> tokenWallet;
@property (nonnull, nonatomic, readonly) id<FBSDKSettingsLogging, FBSDKSettings> settings;
@property (nonnull, nonatomic, readonly) id<FBSDKNotificationObserving> notificationObserver;
@property (nonnull, nonatomic, readonly) NSHashTable<id<FBSDKApplicationObserving>> *applicationObservers;
@property (nonnull, nonatomic, readonly) id<FBSDKSourceApplicationTracking, FBSDKAppEventsConfiguring, FBSDKApplicationLifecycleObserving, FBSDKApplicationActivating, FBSDKApplicationStateSetting, FBSDKEventLogging> appEvents;
@property (nonnull, nonatomic, readonly) id<FBSDKServerConfigurationProviding> serverConfigurationProvider;
@property (nonnull, nonatomic, readonly) id<FBSDKDataPersisting> store;
@property (nonnull, nonatomic, readonly) Class<FBSDKAuthenticationTokenProviding, FBSDKAuthenticationTokenSetting> authenticationTokenWallet;
@property (nonnull, nonatomic, readonly) FBSDKAccessTokenExpirer *accessTokenExpirer;

#if !TARGET_OS_TV
@property (nonnull, nonatomic, readonly) Class<FBSDKProfileProviding> profileProvider;
@property (nonnull, nonatomic, readonly) id<FBSDKBackgroundEventLogging> backgroundEventLogger;
@property (nonatomic) FBSDKSKAdNetworkReporter *skAdNetworkReporter;
#endif

@property (nonatomic) BOOL isAppLaunched;

@end

@implementation FBSDKApplicationDelegate

#pragma mark - Class Methods

+ (void)initializeSDK:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
  [self.sharedInstance initializeSDKWithLaunchOptions:launchOptions];
}

+ (FBSDKApplicationDelegate *)sharedInstance
{
  static FBSDKApplicationDelegate *_sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _sharedInstance = [self new];
  });
  return _sharedInstance;
}

#pragma mark - Object Lifecycle

- (instancetype)init
{
#if TARGET_OS_TV
  return [self initWithNotificationCenter:NSNotificationCenter.defaultCenter
                              tokenWallet:FBSDKAccessToken.class
                                 settings:FBSDKSettings.sharedSettings
                           featureChecker:FBSDKFeatureManager.shared
                                appEvents:FBSDKAppEvents.singleton
              serverConfigurationProvider:FBSDKServerConfigurationManager.shared
                                    store:NSUserDefaults.standardUserDefaults
                authenticationTokenWallet:FBSDKAuthenticationToken.class];
#else
  FBSDKBackgroundEventLogger *backgroundEventLogger = [[FBSDKBackgroundEventLogger alloc] initWithInfoDictionaryProvider:NSBundle.mainBundle
                                                                                                             eventLogger:FBSDKAppEvents.singleton];
  return [self initWithNotificationCenter:NSNotificationCenter.defaultCenter
                              tokenWallet:FBSDKAccessToken.class
                                 settings:FBSDKSettings.sharedSettings
                           featureChecker:FBSDKFeatureManager.shared
                                appEvents:FBSDKAppEvents.singleton
              serverConfigurationProvider:FBSDKServerConfigurationManager.shared
                                    store:NSUserDefaults.standardUserDefaults
                authenticationTokenWallet:FBSDKAuthenticationToken.class
                          profileProvider:FBSDKProfile.class
                    backgroundEventLogger:backgroundEventLogger];
#endif
}

#if TARGET_OS_TV
- (instancetype)initWithNotificationCenter:(id<FBSDKNotificationObserving, FBSDKNotificationPosting>)notificationCenter
                               tokenWallet:(Class<FBSDKAccessTokenProviding, FBSDKAccessTokenSetting>)tokenWallet
                                  settings:(id<FBSDKSettingsLogging, FBSDKSettings>)settings
                            featureChecker:(id<FBSDKFeatureChecking>)featureChecker
                                 appEvents:(id<FBSDKSourceApplicationTracking, FBSDKAppEventsConfiguring, FBSDKApplicationLifecycleObserving, FBSDKApplicationActivating, FBSDKApplicationStateSetting, FBSDKEventLogging>)appEvents
               serverConfigurationProvider:(id<FBSDKServerConfigurationProviding>)serverConfigurationProvider
                                     store:(id<FBSDKDataPersisting>)store
                 authenticationTokenWallet:(Class<FBSDKAuthenticationTokenProviding, FBSDKAuthenticationTokenSetting>)authenticationTokenWallet
{
  if ((self = [super init]) != nil) {
    _applicationObservers = [NSHashTable new];
    _notificationObserver = notificationCenter;
    _tokenWallet = tokenWallet;
    _settings = settings;
    _featureChecker = featureChecker;
    _appEvents = appEvents;
    _serverConfigurationProvider = serverConfigurationProvider;
    _store = store;
    _authenticationTokenWallet = authenticationTokenWallet;
    _accessTokenExpirer = [[FBSDKAccessTokenExpirer alloc] initWithNotificationCenter:notificationCenter];
  }
  return self;
}

#else
- (instancetype)initWithNotificationCenter:(id<FBSDKNotificationObserving, FBSDKNotificationPosting>)notificationCenter
                               tokenWallet:(Class<FBSDKAccessTokenProviding, FBSDKAccessTokenSetting>)tokenWallet
                                  settings:(id<FBSDKSettingsLogging, FBSDKSettings>)settings
                            featureChecker:(id<FBSDKFeatureChecking>)featureChecker
                                 appEvents:(id<FBSDKSourceApplicationTracking, FBSDKAppEventsConfiguring, FBSDKApplicationLifecycleObserving, FBSDKApplicationActivating, FBSDKApplicationStateSetting, FBSDKEventLogging>)appEvents
               serverConfigurationProvider:(id<FBSDKServerConfigurationProviding>)serverConfigurationProvider
                                     store:(id<FBSDKDataPersisting>)store
                 authenticationTokenWallet:(Class<FBSDKAuthenticationTokenProviding, FBSDKAuthenticationTokenSetting>)authenticationTokenWallet
                           profileProvider:(Class<FBSDKProfileProviding>)profileProvider
                     backgroundEventLogger:(id<FBSDKBackgroundEventLogging>)backgroundEventLogger
{
  if ((self = [super init]) != nil) {
    _applicationObservers = [NSHashTable new];
    _notificationObserver = notificationCenter;
    _tokenWallet = tokenWallet;
    _settings = settings;
    _featureChecker = featureChecker;
    _appEvents = appEvents;
    _serverConfigurationProvider = serverConfigurationProvider;
    _store = store;
    _authenticationTokenWallet = authenticationTokenWallet;
    _profileProvider = profileProvider;
    _backgroundEventLogger = backgroundEventLogger;
    _accessTokenExpirer = [[FBSDKAccessTokenExpirer alloc] initWithNotificationCenter:notificationCenter];
  }
  return self;
}

#endif

- (void)initializeSDK
{
  [self initializeSDKWithLaunchOptions:@{}];
}

- (void)initializeSDKWithLaunchOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
  if (hasInitializeBeenCalled) {
    return;
  } else {
    hasInitializeBeenCalled = YES;
  }

  //
  // DO NOT MOVE THIS CALL
  // Dependencies MUST be configured before they are invoked
  //
  [self configureDependencies];

  [self logInitialization];
  [self addObservers];
  [self.appEvents startObservingApplicationLifecycleNotifications];
  [self application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:launchOptions];
  [self handleDeferredActivationIfNeeded];
  [self enableInstrumentation];

#if !TARGET_OS_TV
  [self logBackgroundRefreshStatus];
  [self initializeAppLink];
#endif

  [self configureSourceApplicationWithLaunchOptions:launchOptions];
}

#if !TARGET_OS_TV
- (void)initializeAppLink
{
  [self initializeMeasurementListener];
  [self _logIfAutoAppLinkEnabled];
}

#endif

- (void)handleDeferredActivationIfNeeded
{
  // If sdk initialization is deferred until after the applicationDidBecomeActive notification is received, then we need to manually perform this work in case it hasn't happened at all.
  if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
    [self applicationDidBecomeActive:nil];
  }
}

- (void)configureSourceApplicationWithLaunchOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
  // Set the SourceApplication for time spent data. This is not going to update the value if the app has already launched.
  [self.appEvents setSourceApplication:launchOptions[UIApplicationLaunchOptionsSourceApplicationKey]
                               openURL:launchOptions[UIApplicationLaunchOptionsURLKey]];
  // Register on UIApplicationDidEnterBackgroundNotification events to reset source application data when app backgrounds.
  [self.appEvents registerAutoResetSourceApplication];
  [FBSDKInternalUtility.sharedUtility validateFacebookReservedURLSchemes];
}

#if !TARGET_OS_TV
- (void)initializeMeasurementListener
{
  // Register Listener for App Link measurement events
  [FBSDKMeasurementEventListener defaultListener];
}

#endif

#if !TARGET_OS_TV
- (void)logBackgroundRefreshStatus
{
  [self.backgroundEventLogger logBackgroundRefresStatus:[UIApplication.sharedApplication backgroundRefreshStatus]];
}

#endif

- (void)logInitialization
{
  id<FBSDKSettingsLogging> const settingsLogger = self.settings;
  [settingsLogger logWarnings];
  [settingsLogger logIfSDKSettingsChanged];
  [settingsLogger recordInstall];
}

- (void)enableInstrumentation
{
  [self.featureChecker checkFeature:FBSDKFeatureInstrument completionBlock:^(BOOL enabled) {
    if (enabled) {
      [FBSDKInstrumentManager.shared enable];
    }
  }];
}

- (void)addObservers
{
  id<FBSDKNotificationObserving> const observer = self.notificationObserver;
  [observer addObserver:self
               selector:@selector(applicationDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
  [observer addObserver:self
               selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
  [observer addObserver:self
               selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];
#if !TARGET_OS_TV
  [self addObserver:FBSDKBridgeAPI.sharedInstance];
#endif
}

- (void)dealloc
{
  [self.notificationObserver removeObserver:self];
}

#pragma mark - UIApplicationDelegate

#if __IPHONE_OS_VERSION_MAX_ALLOWED> __IPHONE_9_0
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
  return [self application:application
                    openURL:url
          sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                 annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];

  return NO;
}

#endif

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
  if (sourceApplication != nil && ![sourceApplication isKindOfClass:NSString.class]) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"Expected 'sourceApplication' to be NSString. Please verify you are passing in 'sourceApplication' from your app delegate (not the UIApplication* parameter). If your app delegate implements iOS 9's application:openURL:options:, you should pass in options[UIApplicationOpenURLOptionsSourceApplicationKey]. "
                                 userInfo:nil];
  }
  [self.appEvents setSourceApplication:sourceApplication openURL:url];

#if !TARGET_OS_TV
  [self.featureChecker checkFeature:FBSDKFeatureAEM completionBlock:^(BOOL enabled) {
    if (enabled) {
      [FBAEMReporter enable];
      [FBAEMReporter handleURL:url];
    }
  }];
#endif

  BOOL handled = NO;
  NSArray<id<FBSDKApplicationObserving>> *observers = [self.applicationObservers allObjects];
  for (id<FBSDKApplicationObserving> observer in observers) {
    if ([observer respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)]) {
      if ([observer application:application
                        openURL:url
              sourceApplication:sourceApplication
                     annotation:annotation]) {
        handled = YES;
      }
    }
  }

  if (handled) {
    return YES;
  }

  [self _logIfAppLinkEvent:url];

  return NO;
}

// MARK: Finish Launching

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<NSString *, id> *)launchOptions
{
  if (self.isAppLaunched) {
    return NO;
  }

  if (!hasInitializeBeenCalled) {
    [self initializeSDKWithLaunchOptions:launchOptions];
  }

  self.isAppLaunched = YES;

  [self initializeTokenCache];
  [self fetchServerConfiguration];

  if (self.settings.isAutoLogAppEventsEnabled) {
    [self _logSDKInitialize];
  }

#if !TARGET_OS_TV
  [self initializeProfile];
  [self checkAuthentication];
#endif

  return [self notifyLaunchObserversWithApplication:application
                                      launchOptions:launchOptions];
}

- (void)initializeTokenCache
{
  FBSDKAccessToken *cachedToken = [[self.tokenWallet tokenCache] accessToken];
  [self.tokenWallet setCurrentAccessToken:cachedToken];
}

- (void)fetchServerConfiguration
{
  [self.serverConfigurationProvider loadServerConfigurationWithCompletionBlock:NULL];
}

#if !TARGET_OS_TV
- (void)initializeProfile
{
  FBSDKProfile *cachedProfile = [self.profileProvider fetchCachedProfile];
  [self.profileProvider setCurrentProfile:cachedProfile];
}

#endif

#if !TARGET_OS_TV
- (void)checkAuthentication
{
  FBSDKAuthenticationToken *cachedAuthToken = [[self.authenticationTokenWallet tokenCache] authenticationToken];
  [self.authenticationTokenWallet setCurrentAuthenticationToken:cachedAuthToken];

  [FBSDKAuthenticationStatusUtility checkAuthenticationStatus];
}

#endif

- (BOOL)notifyLaunchObserversWithApplication:(UIApplication *)application
                               launchOptions:(NSDictionary<NSString *, id> *)launchOptions
{
  NSArray<id<FBSDKApplicationObserving>> *observers = [self.applicationObservers allObjects];
  BOOL someObserverHandledLaunch = NO;
  for (id<FBSDKApplicationObserving> observer in observers) {
    if ([observer respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
      if ([observer application:application didFinishLaunchingWithOptions:launchOptions]) {
        someObserverHandledLaunch = YES;
      }
    }
  }

  return someObserverHandledLaunch;
}

// MARK: Entering Background

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
  [self setApplicationState:UIApplicationStateBackground];
  NSArray<id<FBSDKApplicationObserving>> *observers = [self.applicationObservers allObjects];
  for (id<FBSDKApplicationObserving> observer in observers) {
    if ([observer respondsToSelector:@selector(applicationDidEnterBackground:)]) {
      [observer applicationDidEnterBackground:notification.object];
    }
  }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
  [self setApplicationState:UIApplicationStateActive];
  // Auto log basic events in case autoLogAppEventsEnabled is set
  if (self.settings.isAutoLogAppEventsEnabled) {
    [self.appEvents activateApp];
  }
#if !TARGET_OS_TV
  [self.skAdNetworkReporter checkAndRevokeTimer];
#endif

  NSArray<id<FBSDKApplicationObserving>> *observers = [self.applicationObservers copy];
  for (id<FBSDKApplicationObserving> observer in observers) {
    if ([observer respondsToSelector:@selector(applicationDidBecomeActive:)]) {
      [observer applicationDidBecomeActive:notification.object];
    }
  }
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
  [self setApplicationState:UIApplicationStateInactive];
  NSArray<id<FBSDKApplicationObserving>> *const observers = [self.applicationObservers copy];
  for (id<FBSDKApplicationObserving> observer in observers) {
    if ([observer respondsToSelector:@selector(applicationWillResignActive:)]) {
      [observer applicationWillResignActive:notification.object];
    }
  }
}

#pragma mark - Internal Methods

#pragma mark - FBSDKApplicationObserving

- (void)addObserver:(id<FBSDKApplicationObserving>)observer
{
  if (![self.applicationObservers containsObject:observer]) {
    [self.applicationObservers addObject:observer];
  }
}

- (void)removeObserver:(id<FBSDKApplicationObserving>)observer
{
  if ([self.applicationObservers containsObject:observer]) {
    [self.applicationObservers removeObject:observer];
  }
}

- (void)setApplicationState:(UIApplicationState)state
{
  _applicationState = state;
  [self.appEvents setApplicationState:state];
}

#pragma mark - Helper Methods

- (void)_logIfAppLinkEvent:(NSURL *)url
{
  if (!url) {
    return;
  }
  NSDictionary<NSString *, NSString *> *params = [FBSDKBasicUtility dictionaryWithQueryString:url.query];
  NSString *applinkDataString = params[@"al_applink_data"];
  if (!applinkDataString) {
    return;
  }

  NSDictionary<id, id> *applinkData = [FBSDKTypeUtility dictionaryValue:[FBSDKBasicUtility objectForJSONString:applinkDataString error:NULL]];
  if (!applinkData) {
    return;
  }

  NSString *targetURLString = applinkData[@"target_url"];
  NSURL *targetURL = [targetURLString isKindOfClass:NSString.class] ? [NSURL URLWithString:targetURLString] : nil;

  NSMutableDictionary<NSString *, id> *logData = [NSMutableDictionary new];
  [FBSDKTypeUtility dictionary:logData setObject:targetURL.absoluteString forKey:@"targetURL"];
  [FBSDKTypeUtility dictionary:logData setObject:targetURL.host forKey:@"targetURLHost"];

  NSDictionary<NSString *, id> *refererData = applinkData[@"referer_data"];
  if (refererData) {
    [FBSDKTypeUtility dictionary:logData setObject:refererData[@"target_url"] forKey:@"referralTargetURL"];
    [FBSDKTypeUtility dictionary:logData setObject:refererData[@"url"] forKey:@"referralURL"];
    [FBSDKTypeUtility dictionary:logData setObject:refererData[@"app_name"] forKey:@"referralAppName"];
  }
  [FBSDKTypeUtility dictionary:logData setObject:url.absoluteString forKey:@"inputURL"];
  [FBSDKTypeUtility dictionary:logData setObject:url.scheme forKey:@"inputURLScheme"];

  [self.appEvents logInternalEvent:FBSDKAppLinkInboundEvent
                        parameters:logData
                isImplicitlyLogged:YES];
}

- (void)_logSDKInitialize
{
  NSDictionary<NSString *, id> *metaInfo = @{
    @"FBSDKLoginManager" : @"login_lib_included",
    @"FBSDKAutoLog" : @"marketing_lib_included",
    @"FBSDKMessengerButton" : @"messenger_lib_included",
    @"FBSDKPlacesManager" : @"places_lib_included",
    @"FBSDKShareDialog" : @"share_lib_included",
    @"FBSDKTVInterfaceFactory" : @"tv_lib_included",
  };

  NSInteger bitmask = 0;
  NSInteger bit = 0;
  NSMutableDictionary<NSString *, NSNumber *> *params = NSMutableDictionary.new;
  [FBSDKTypeUtility dictionary:params setObject:@1 forKey:@"core_lib_included"];
  for (NSString *className in metaInfo.allKeys) {
    NSString *keyName = [FBSDKTypeUtility dictionary:metaInfo objectForKey:className ofType:NSObject.class];
    if (objc_lookUpClass([className UTF8String])) {
      [FBSDKTypeUtility dictionary:params setObject:@1 forKey:keyName];
      bitmask |= 1 << bit;
    }
    bit++;
  }

  NSInteger existingBitmask = [self.store integerForKey:FBSDKKitsBitmaskKey];
  if (existingBitmask != bitmask) {
    [self.store setInteger:bitmask forKey:FBSDKKitsBitmaskKey];
    [self.appEvents logInternalEvent:@"fb_sdk_initialize"
                          parameters:params
                  isImplicitlyLogged:NO];
  }
}

- (void)_logIfAutoAppLinkEnabled
{
#if !TARGET_OS_TV
  NSNumber *enabled = [NSBundle.mainBundle objectForInfoDictionaryKey:@"FBSDKAutoAppLinkEnabled"];
  if (enabled.boolValue) {
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary new];
    if (![FBSDKAppLinkUtility isMatchURLScheme:[NSString stringWithFormat:@"fb%@", self.settings.appID]]) {
      NSString *warning = @"You haven't set the Auto App Link URL scheme: fb<YOUR APP ID>";
      [FBSDKTypeUtility dictionary:params setObject:warning forKey:@"SchemeWarning"];
      NSLog(@"%@", warning);
    }
    [self.appEvents logInternalEvent:@"fb_auto_applink" parameters:params isImplicitlyLogged:YES];
  }
#endif
}

- (void)configureDependencies
{
  id<FBSDKGraphRequestProviding> graphRequestProvider = [FBSDKGraphRequestFactory new];
  id<FBSDKDataPersisting> store = NSUserDefaults.standardUserDefaults;
  id<FBSDKGraphRequestConnectionProviding> connectionProvider = [FBSDKGraphRequestConnectionFactory new];
  id<FBSDKSettings> sharedSettings = FBSDKSettings.sharedSettings;
  id<FBSDKServerConfigurationProviding> serverConfigurationProvider = FBSDKServerConfigurationManager.shared;

  [FBSDKSettings configureWithStore:store
     appEventsConfigurationProvider:FBSDKAppEventsConfigurationManager.class
             infoDictionaryProvider:NSBundle.mainBundle
                        eventLogger:FBSDKAppEvents.singleton];
  [FBSDKGraphRequest setCurrentAccessTokenStringProvider:FBSDKAccessToken.class];
  [FBSDKGraphRequest setSettings:sharedSettings];
  [FBSDKGraphRequestConnection setCanMakeRequests];
  [FBSDKGateKeeperManager configureWithSettings:FBSDKSettings.class
                                requestProvider:graphRequestProvider
                             connectionProvider:connectionProvider
                                          store:store];
  FBSDKTokenCache *tokenCache = [[FBSDKTokenCache alloc] initWithSettings:sharedSettings];
  [FBSDKAccessToken setTokenCache:tokenCache];
  [FBSDKAccessToken setConnectionFactory:connectionProvider];
  [FBSDKAuthenticationToken setTokenCache:tokenCache];
  FBSDKAtePublisherFactory *atePublisherFactory = [[FBSDKAtePublisherFactory alloc] initWithStore:store
                                                                              graphRequestFactory:graphRequestProvider
                                                                                         settings:sharedSettings];
  FBSDKTimeSpentRecordingFactory *timeSpentRecordingFactory
    = [[FBSDKTimeSpentRecordingFactory alloc] initWithEventLogger:self.appEvents
                                      serverConfigurationProvider:serverConfigurationProvider];
  FBSDKEventDeactivationManager *eventDeactivationManager = [FBSDKEventDeactivationManager new];
  FBSDKRestrictiveDataFilterManager *restrictiveDataFilterManager = [[FBSDKRestrictiveDataFilterManager alloc] initWithServerConfigurationProvider:serverConfigurationProvider];
  [FBSDKAppEventsState configureWithEventProcessors:@[eventDeactivationManager, restrictiveDataFilterManager]];
  [self.appEvents configureWithGateKeeperManager:FBSDKGateKeeperManager.class
                  appEventsConfigurationProvider:FBSDKAppEventsConfigurationManager.class
                     serverConfigurationProvider:serverConfigurationProvider
                            graphRequestProvider:graphRequestProvider
                                  featureChecker:self.featureChecker
                                           store:store
                                          logger:FBSDKLogger.class
                                        settings:sharedSettings
                                 paymentObserver:FBSDKPaymentObserver.shared
                        timeSpentRecorderFactory:timeSpentRecordingFactory
                             appEventsStateStore:FBSDKAppEventsStateManager.shared
             eventDeactivationParameterProcessor:eventDeactivationManager
         restrictiveDataFilterParameterProcessor:restrictiveDataFilterManager
                             atePublisherFactory:atePublisherFactory
                          appEventsStateProvider:[FBSDKAppEventsStateFactory new]
                                        swizzler:FBSDKSwizzler.class
                            advertiserIDProvider:FBSDKAppEventsUtility.shared];
  [FBSDKInternalUtility configureWithInfoDictionaryProvider:NSBundle.mainBundle];
  [FBSDKAppEventsConfigurationManager configureWithStore:store
                                                settings:sharedSettings
                                     graphRequestFactory:graphRequestProvider
                           graphRequestConnectionFactory:connectionProvider];
  [FBSDKGraphRequestPiggybackManager configureWithTokenWallet:FBSDKAccessToken.class
                                                     settings:sharedSettings
                                          serverConfiguration:serverConfigurationProvider
                                              requestProvider:graphRequestProvider];
  [FBSDKButton setApplicationActivationNotifier:self];
  [FBSDKError configureWithErrorReporter:FBSDKErrorReport.shared];
#if !TARGET_OS_TV
  [FBSDKModelManager.shared configureWithFeatureChecker:FBSDKFeatureManager.shared
                                    graphRequestFactory:graphRequestProvider
                                            fileManager:NSFileManager.defaultManager
                                                  store:store
                                               settings:sharedSettings
                                          dataExtractor:NSData.class];
  [FBSDKFeatureExtractor configureWithRulesFromKeyProvider:FBSDKModelManager.shared];
  [FBSDKAppLinkUtility configureWithRequestProvider:graphRequestProvider
                             infoDictionaryProvider:NSBundle.mainBundle];
  [FBSDKCodelessIndexer configureWithRequestProvider:graphRequestProvider
                         serverConfigurationProvider:serverConfigurationProvider
                                               store:store
                                  connectionProvider:connectionProvider
                                            swizzler:FBSDKSwizzler.class
                                            settings:sharedSettings
                                advertiserIDProvider:FBSDKAppEventsUtility.shared];
  [FBSDKCrashShield configureWithSettings:sharedSettings
                          requestProvider:[FBSDKGraphRequestFactory new]
                          featureChecking:FBSDKFeatureManager.shared];
  self.skAdNetworkReporter = nil;
  if (@available(iOS 11.3, *)) {
    self.skAdNetworkReporter = [[FBSDKSKAdNetworkReporter alloc] initWithRequestProvider:graphRequestProvider
                                                                                   store:store
                                                                conversionValueUpdatable:SKAdNetwork.class];
  }
  if (@available(iOS 14.0, *)) {
    [FBAEMReporter configureWithNetworker:[FBSDKAEMNetworker new]
                                    appID:[FBSDKSettings appID]
                                 reporter:self.skAdNetworkReporter];
  }
  [FBSDKProfile configureWithStore:store
               accessTokenProvider:FBSDKAccessToken.class
                notificationCenter:NSNotificationCenter.defaultCenter];
  [FBSDKWebDialogView configureWithWebViewProvider:[FBSDKWebViewFactory new]
                                         urlOpener:UIApplication.sharedApplication];
  [self.appEvents configureNonTVComponentsWithOnDeviceMLModelManager:FBSDKModelManager.shared
                                                     metadataIndexer:FBSDKMetadataIndexer.shared
                                                 skAdNetworkReporter:self.skAdNetworkReporter];
#endif
}

// MARK: - Testability

#if DEBUG
 #if FBTEST

+ (void)resetHasInitializeBeenCalled
{
  hasInitializeBeenCalled = NO;
}

- (void)resetApplicationObserverCache
{
  _applicationObservers = [NSHashTable new];
}

 #endif
#endif

@end
