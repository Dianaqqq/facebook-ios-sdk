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

@import FBSDKCoreKit;

@interface FBSDKLoginManager (Testing)

@property (nonatomic) FBSDKLoginManagerLoginResultBlock handler;
@property (nonatomic) FBSDKLoginConfiguration *configuration;
@property (nonatomic) id<FBSDKKeychainStore> keychainStore;
@property (nonatomic) Class<FBSDKAccessTokenProviding, FBSDKAccessTokenSetting> tokenWallet;
@property (nonatomic) Class<FBSDKAuthenticationTokenProviding, FBSDKAuthenticationTokenSetting> authenticationToken;
@property (nonatomic) Class<FBSDKProfileProviding> profile;
@property (nonatomic)  id<FBSDKGraphRequestConnectionProviding> connectionProvider;
@property (nonatomic) id<FBSDKURLHosting, FBSDKAppURLSchemeProviding, FBSDKAppAvailabilityChecker> internalUtility;

- (NSDictionary<NSString *, id> *)logInParametersFromURL:(NSURL *)url;

- (NSString *)loadExpectedNonce;

- (void)storeExpectedNonce:(NSString *)nonceExpected keychainStore:(FBSDKKeychainStore *)keychainStore;

- (FBSDKLoginConfiguration *)configuration;

- (void)storeExpectedNonce:(NSString *)nonceExpected;

- (NSSet<FBSDKPermission *> *)recentlyGrantedPermissionsFromGrantedPermissions:(NSSet<FBSDKPermission *> *)grantedPermissions;

- (NSSet<FBSDKPermission *> *)recentlyDeclinedPermissionsFromDeclinedPermissions:(NSSet<FBSDKPermission *> *)declinedPermissions;

- (void)validateReauthenticationWithGraphRequestConnectionProvider:(id<FBSDKGraphRequestConnectionProviding>)connectionProvider
                                                         withToken:(FBSDKAccessToken *)currentToken
                                                        withResult:(FBSDKLoginManagerLoginResult *)loginResult;

- (NSDictionary<NSString *, id> *)logInParametersWithConfiguration:(FBSDKLoginConfiguration *)configuration;

- (void)logInWithPermissions:(NSArray<NSString *> *)permissions
          fromViewController:(UIViewController *)viewController
                     handler:(FBSDKLoginManagerLoginResultBlock)handler;

- (instancetype)initWithInternalUtility:(id<FBSDKURLHosting, FBSDKAppURLSchemeProviding, FBSDKAppAvailabilityChecker>)internalUtility
                   keychainStoreFactory:(id<FBSDKKeychainStoreProviding>)keychainStoreFactory
                            tokenWallet:(Class<FBSDKAccessTokenProviding, FBSDKAccessTokenSetting>)tokenWallet
                     connectionProvider:(id<FBSDKGraphRequestConnectionProviding>)connectionProvider
                    authenticationToken:(Class<FBSDKAuthenticationTokenProviding, FBSDKAuthenticationTokenSetting>)authenticationToken
                                profile:(Class<FBSDKProfileProviding>)profile;

@end
