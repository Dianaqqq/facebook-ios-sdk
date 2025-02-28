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

#import <UIKit/UIKit.h>

#ifdef BUCK
 #import <FBSDKCoreKit/FBSDKCoreKit.h>
#else
@import FBSDKCoreKit;
#endif

#import <XCTest/XCTest.h>

#import "FBSDKShareLinkContent.h"
#import "FBSDKShareModelTestUtility.h"
#import "FBSDKShareUtility.h"

@interface FBSDKShareLinkContentTests : XCTestCase
@end

@implementation FBSDKShareLinkContentTests

- (void)testProperties
{
  FBSDKShareLinkContent *content = [FBSDKShareModelTestUtility linkContent];
  XCTAssertEqualObjects(content.contentURL, [FBSDKShareModelTestUtility contentURL]);
  XCTAssertEqualObjects(content.hashtag, [FBSDKShareModelTestUtility hashtag]);
  XCTAssertEqualObjects(content.peopleIDs, [FBSDKShareModelTestUtility peopleIDs]);
  XCTAssertEqualObjects(content.placeID, [FBSDKShareModelTestUtility placeID]);
  XCTAssertEqualObjects(content.ref, [FBSDKShareModelTestUtility ref]);
  XCTAssertEqualObjects(content.quote, [FBSDKShareModelTestUtility quote]);
}

- (void)testCopy
{
  FBSDKShareLinkContent *content = [FBSDKShareModelTestUtility linkContent];
  XCTAssertEqualObjects([content copy], content);
}

- (void)testCoding
{
  FBSDKShareLinkContent *content = [FBSDKShareModelTestUtility linkContent];
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:content];
  NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
  [unarchiver setRequiresSecureCoding:YES];
  FBSDKShareLinkContent *unarchivedObject = [unarchiver decodeObjectOfClass:FBSDKShareLinkContent.class
                                                                     forKey:NSKeyedArchiveRootObjectKey];
  XCTAssertEqualObjects(unarchivedObject, content);
}

- (void)testWithInvalidPeopleIDs
{
  FBSDKShareLinkContent *content = [FBSDKShareLinkContent new];
  NSArray *array = @[
    @"one",
    @2,
    @"three",
  ];
  XCTAssertThrowsSpecificNamed([content setPeopleIDs:array], NSException, NSInvalidArgumentException);
}

- (void)testValidationWithValidContent
{
  NSError *error;
  XCTAssertTrue(
    [FBSDKShareUtility validateShareContent:[FBSDKShareModelTestUtility linkContent]
                              bridgeOptions:FBSDKShareBridgeOptionsDefault
                                      error:&error]
  );
  XCTAssertNil(error);
}

- (void)testValidationWithNilContent
{
  NSError *error;
  XCTAssertFalse([FBSDKShareUtility validateShareContent:nil bridgeOptions:FBSDKShareBridgeOptionsDefault error:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual(error.code, FBSDKErrorInvalidArgument);
  XCTAssertEqualObjects(error.userInfo[FBSDKErrorArgumentNameKey], @"shareContent");
  XCTAssertNil(error.userInfo[FBSDKErrorArgumentValueKey]);
}

@end
