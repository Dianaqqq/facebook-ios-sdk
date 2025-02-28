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

 #import "FBSDKGameRequestFrictionlessRecipientCache.h"

 #import "FBSDKCoreKitBasicsImportForShareKit.h"
 #import "FBSDKCoreKitImport.h"

@interface FBSDKGameRequestFrictionlessRecipientCache ()
@property (nonatomic) NSSet *recipientIDs;
@end

@implementation FBSDKGameRequestFrictionlessRecipientCache

 #pragma mark - Object Lifecycle

- (instancetype)init
{
  if ((self = [super init])) {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(_accessTokenDidChangeNotification:)
                                               name:FBSDKAccessTokenDidChangeNotification
                                             object:nil];
    [self _updateCache];
  }
  return self;
}

- (void)dealloc
{
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

 #pragma mark - Public API

- (BOOL)recipientsAreFrictionless:(id)recipients
{
  if (!recipients) {
    return NO;
  }
  NSArray *recipientIDArray = [FBSDKTypeUtility arrayValue:recipients];
  if (!recipientIDArray && [recipients isKindOfClass:NSString.class]) {
    recipientIDArray = [recipients componentsSeparatedByString:@","];
  }
  if (recipientIDArray) {
    NSSet *recipientIDs = [[NSSet alloc]
                           initWithArray:recipientIDArray];
    return [recipientIDs isSubsetOfSet:_recipientIDs];
  } else {
    return NO;
  }
}

- (void)updateWithResults:(NSDictionary<NSString *, id> *)results
{
  if ([FBSDKTypeUtility boolValue:results[@"updated_frictionless"]]) {
    [self _updateCache];
  }
}

 #pragma mark - Helper Methods

- (void)_accessTokenDidChangeNotification:(NSNotification *)notification
{
  if (![notification.userInfo[FBSDKAccessTokenDidChangeUserIDKey] boolValue]) {
    return;
  }
  _recipientIDs = nil;
  [self _updateCache];
}

- (void)_updateCache
{
  if (![FBSDKAccessToken currentAccessToken]) {
    _recipientIDs = nil;
    return;
  }
  FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/apprequestformerrecipients"
                                                                 parameters:@{@"fields" : @""}
                                                                      flags:(FBSDKGraphRequestFlagDoNotInvalidateTokenOnError
                                                                        | FBSDKGraphRequestFlagDisableErrorRecovery)];
  [request startWithCompletion:^(id<FBSDKGraphRequestConnecting> connection, id result, NSError *error) {
    if (!error) {
      NSArray *items = [FBSDKTypeUtility arrayValue:result[@"data"]];
      NSArray *recipientIDs = [items valueForKey:@"recipient_id"];
      self->_recipientIDs = [[NSSet alloc] initWithArray:recipientIDs];
    }
  }];
}

@end

#endif
