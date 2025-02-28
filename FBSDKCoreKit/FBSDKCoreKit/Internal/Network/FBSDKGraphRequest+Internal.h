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

#import <Foundation/Foundation.h>

#import <FBSDKCoreKit/FBSDKGraphRequest.h>
#import <FBSDKCoreKit/FBSDKGraphRequestConnectionProviding.h>
#import <FBSDKCoreKit/FBSDKGraphRequestFlags.h>

@protocol FBSDKTokenStringProviding;
@protocol FBSDKSettings;

NS_ASSUME_NONNULL_BEGIN

@interface FBSDKGraphRequest (Internal)

@property (nonatomic, readonly, getter = isGraphErrorRecoveryDisabled) BOOL graphErrorRecoveryDisabled;
@property (nonatomic, readonly) BOOL hasAttachments;

- (instancetype)initWithGraphPath:(NSString *)graphPath
                       parameters:(nullable NSDictionary<NSString *, id> *)parameters
                      tokenString:(nullable NSString *)tokenString
                       HTTPMethod:(nullable NSString *)HTTPMethod
                            flags:(FBSDKGraphRequestFlags)flags
                connectionFactory:(id<FBSDKGraphRequestConnectionProviding>)factory;

- (instancetype)initWithGraphPath:(NSString *)graphPath
                       parameters:(NSDictionary<NSString *, id> *)parameters
                      tokenString:(NSString *)tokenString
                       HTTPMethod:(NSString *)method
                          version:(NSString *)version
                            flags:(FBSDKGraphRequestFlags)flags
                connectionFactory:(id<FBSDKGraphRequestConnectionProviding>)factory;

+ (BOOL)isAttachment:(id)item;
+ (NSString *)serializeURL:(NSString *)baseUrl
                    params:(nullable NSDictionary<NSString *, id> *)params
                httpMethod:(nullable NSString *)httpMethod
                  forBatch:(BOOL)forBatch;

+ (void)setCurrentAccessTokenStringProvider:(Class<FBSDKTokenStringProviding>)provider;
+ (void)setSettings:(id<FBSDKSettings>)settings;

@end

NS_ASSUME_NONNULL_END
