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

 #import "FBSDKLikeDialog.h"

 #import "FBSDKCoreKitBasicsImportForShareKit.h"
 #import "FBSDKCoreKitImport.h"
 #import "FBSDKShareConstants.h"
 #import "FBSDKShareDefines.h"

@implementation FBSDKLikeDialog

 #define FBSDK_LIKE_METHOD_MIN_VERSION @"20140410"
 #define FBSDK_LIKE_METHOD_NAME @"like"
 #define FBSDK_SHARE_RESULT_COMPLETION_GESTURE_VALUE_LIKE @"like"
 #define FBSDK_SHARE_RESULT_COMPLETION_GESTURE_VALUE_UNLIKE @"unlike"

 #pragma mark - Class Methods

+ (instancetype)likeWithObjectID:(NSString *)objectID
                      objectType:(FBSDKLikeObjectType)objectType
                        delegate:(id<FBSDKLikeDialogDelegate>)delegate
{
  FBSDKLikeDialog *dialog = [self new];
  dialog.objectID = objectID;
  dialog.objectType = objectType;
  dialog.delegate = delegate;
  [dialog like];
  return dialog;
}

 #pragma mark - Public Methods

- (BOOL)canLike
{
  return YES;
}

- (BOOL)like
{
  NSError *error;
  if (![self canLike]) {
    error = [FBSDKError errorWithDomain:FBSDKShareErrorDomain
                                   code:FBSDKShareErrorDialogNotAvailable
                                message:@"Like dialog is not available."];
    [_delegate likeDialog:self didFailWithError:error];
    return NO;
  }
  if (![self validateWithError:&error]) {
    [_delegate likeDialog:self didFailWithError:error];
    return NO;
  }

  NSMutableDictionary<NSString *, id> *parameters = [NSMutableDictionary new];
  [FBSDKTypeUtility dictionary:parameters setObject:self.objectID forKey:@"object_id"];
  [FBSDKTypeUtility dictionary:parameters
                     setObject:NSStringFromFBSDKLikeObjectType(self.objectType)
                        forKey:@"object_type"];
  FBSDKBridgeAPIRequest *webRequest = [FBSDKBridgeAPIRequest bridgeAPIRequestWithProtocolType:FBSDKBridgeAPIProtocolTypeWeb
                                                                                       scheme:FBSDK_SHARE_JS_DIALOG_SCHEME
                                                                                   methodName:FBSDK_LIKE_METHOD_NAME
                                                                                methodVersion:nil
                                                                                   parameters:parameters
                                                                                     userInfo:nil];
  FBSDKBridgeAPIResponseBlock completionBlock = ^(FBSDKBridgeAPIResponse *response) {
    [self _handleCompletionWithDialogResults:response.responseParameters error:response.error];
  };

  BOOL useSafariViewController = [[FBSDKShareDialogConfiguration new]
                                  shouldUseSafariViewControllerForDialogName:FBSDKDialogConfigurationNameLike];
  if ([self _canLikeNative]) {
    FBSDKBridgeAPIRequest *nativeRequest = [FBSDKBridgeAPIRequest bridgeAPIRequestWithProtocolType:FBSDKBridgeAPIProtocolTypeNative
                                                                                            scheme:FBSDK_CANOPENURL_FACEBOOK
                                                                                        methodName:FBSDK_LIKE_METHOD_NAME
                                                                                     methodVersion:FBSDK_LIKE_METHOD_MIN_VERSION
                                                                                        parameters:parameters
                                                                                          userInfo:nil];
    void (^networkCompletionBlock)(FBSDKBridgeAPIResponse *) = ^(FBSDKBridgeAPIResponse *response) {
      if (response.error.code == FBSDKErrorAppVersionUnsupported) {
        [[FBSDKBridgeAPI sharedInstance] openBridgeAPIRequest:webRequest
                                      useSafariViewController:useSafariViewController
                                           fromViewController:self.fromViewController
                                              completionBlock:completionBlock];
      } else {
        completionBlock(response);
      }
    };
    [[FBSDKBridgeAPI sharedInstance] openBridgeAPIRequest:nativeRequest
                                  useSafariViewController:useSafariViewController
                                       fromViewController:self.fromViewController
                                          completionBlock:networkCompletionBlock];
  } else {
    [[FBSDKBridgeAPI sharedInstance] openBridgeAPIRequest:webRequest
                                  useSafariViewController:useSafariViewController
                                       fromViewController:self.fromViewController
                                          completionBlock:completionBlock];
  }

  return YES;
}

- (BOOL)validateWithError:(NSError *__autoreleasing *)errorRef
{
  if (!self.objectID.length) {
    if (errorRef != NULL) {
      *errorRef = [FBSDKError requiredArgumentErrorWithDomain:FBSDKShareErrorDomain
                                                         name:@"objectID"
                                                      message:nil];
    }
    return NO;
  }
  if (errorRef != NULL) {
    *errorRef = nil;
  }
  return YES;
}

 #pragma mark - Helper Methods

- (BOOL)_canLikeNative
{
  BOOL useNativeDialog = [[FBSDKShareDialogConfiguration new] shouldUseNativeDialogForDialogName:FBSDKDialogConfigurationNameLike];
  return (useNativeDialog && [FBSDKInternalUtility.sharedUtility isFacebookAppInstalled]);
}

- (void)_handleCompletionWithDialogResults:(NSDictionary<NSString *, id> *)results error:(NSError *)error
{
  if (!_delegate) {
    return;
  }
  NSString *completionGesture = results[FBSDK_SHARE_RESULT_COMPLETION_GESTURE_KEY];
  if (completionGesture && !error) {
    [_delegate likeDialog:self didCompleteWithResults:[results copy]];
  } else {
    [_delegate likeDialog:self didFailWithError:error];
  }
}

@end

#endif
