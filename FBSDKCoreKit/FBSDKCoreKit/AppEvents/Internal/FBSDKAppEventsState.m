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

#import "FBSDKAppEventsState.h"

#import "FBSDKCoreKitBasicsImport.h"

#define FBSDK_APPEVENTSTATE_ISIMPLICIT_KEY @"isImplicit"

#define FBSDK_APPEVENTSSTATE_MAX_EVENTS 1000

#define FBSDK_APPEVENTSSTATE_APPID_KEY @"appID"
#define FBSDK_APPEVENTSSTATE_EVENTS_KEY @"events"
#define FBSDK_APPEVENTSSTATE_NUMSKIPPED_KEY @"numSkipped"
#define FBSDK_APPEVENTSSTATE_TOKENSTRING_KEY @"tokenString"
#define FBSDK_APPEVENTSTATE_RECEIPTDATA_KEY @"receipt_data"
#define FBSDK_APPEVENTSTATE_RECEIPTID_KEY @"receipt_id"

static NSArray<id<FBSDKEventsProcessing>> *_eventProcessors;

@interface FBSDKAppEventsState ()

@property (nonatomic) NSMutableArray *mutableEvents;

@end

@implementation FBSDKAppEventsState

+ (void)configureWithEventProcessors:(nonnull NSArray<id<FBSDKEventsProcessing>> *)eventProcessors
{
  _eventProcessors = eventProcessors;
}

- (instancetype)initWithToken:(NSString *)tokenString appID:(NSString *)appID
{
  if ((self = [super init])) {
    _tokenString = [tokenString copy];
    _appID = [appID copy];
    _mutableEvents = [NSMutableArray array];
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
  FBSDKAppEventsState *copy = [[FBSDKAppEventsState allocWithZone:zone] initWithToken:_tokenString appID:_appID];
  if (copy) {
    [copy->_mutableEvents addObjectsFromArray:_mutableEvents];
    copy->_numSkipped = _numSkipped;
  }
  return copy;
}

#pragma mark - NSCoding

+ (BOOL)supportsSecureCoding
{
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
  NSString *appID = [decoder decodeObjectOfClass:NSString.class forKey:FBSDK_APPEVENTSSTATE_APPID_KEY];
  NSString *tokenString = [decoder decodeObjectOfClass:NSString.class forKey:FBSDK_APPEVENTSSTATE_TOKENSTRING_KEY];
  NSArray *events = [FBSDKTypeUtility arrayValue:[decoder decodeObjectOfClasses:
                                                  [NSSet setWithArray:@[NSArray.class, NSDictionary.class]]
                                                                         forKey:FBSDK_APPEVENTSSTATE_EVENTS_KEY]];
  NSUInteger numSkipped = [[decoder decodeObjectOfClass:NSNumber.class forKey:FBSDK_APPEVENTSSTATE_NUMSKIPPED_KEY] unsignedIntegerValue];

  if ((self = [self initWithToken:tokenString appID:appID])) {
    _mutableEvents = [NSMutableArray arrayWithArray:events];
    _numSkipped = numSkipped;
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_appID forKey:FBSDK_APPEVENTSSTATE_APPID_KEY];
  [encoder encodeObject:_tokenString forKey:FBSDK_APPEVENTSSTATE_TOKENSTRING_KEY];
  [encoder encodeObject:@(_numSkipped) forKey:FBSDK_APPEVENTSSTATE_NUMSKIPPED_KEY];
  [encoder encodeObject:_mutableEvents forKey:FBSDK_APPEVENTSSTATE_EVENTS_KEY];
}

#pragma mark - Implementation

- (NSArray *)events
{
  return [_mutableEvents copy];
}

- (void)addEventsFromAppEventState:(FBSDKAppEventsState *)appEventsState
{
  NSArray *toAdd = appEventsState->_mutableEvents;
  NSInteger excess = _mutableEvents.count + toAdd.count - FBSDK_APPEVENTSSTATE_MAX_EVENTS;
  if (excess > 0) {
    NSInteger range = FBSDK_APPEVENTSSTATE_MAX_EVENTS - _mutableEvents.count;
    toAdd = [toAdd subarrayWithRange:NSMakeRange(0, range)];
    _numSkipped += excess;
  }

  [_mutableEvents addObjectsFromArray:toAdd];
}

- (void)addEvent:(NSDictionary<NSString *, id> *)eventDictionary
      isImplicit:(BOOL)isImplicit
{
  if (_mutableEvents.count >= FBSDK_APPEVENTSSTATE_MAX_EVENTS) {
    _numSkipped++;
  } else {
    [FBSDKTypeUtility array:_mutableEvents addObject:@{
       @"event" : [eventDictionary mutableCopy],
       FBSDK_APPEVENTSTATE_ISIMPLICIT_KEY : @(isImplicit)
     }];
  }
}

- (NSString *)extractReceiptData
{
  NSMutableString *receipts_string = [NSMutableString string];
  NSInteger transactionId = 1;
  for (NSMutableDictionary<NSString *, id> *events in _mutableEvents) {
    NSMutableDictionary<NSString *, id> *event = events[@"event"];

    NSString *receipt = event[@"receipt_data"];
    // Add receipt id as the identifier for receipt data in event parameter.
    // Receipt data will be sent as post parameter rather than the event parameter
    if (receipt) {
      NSString *idKey = [NSString stringWithFormat:@"receipt_%ld", (long)transactionId];
      [FBSDKTypeUtility dictionary:event setObject:idKey forKey:FBSDK_APPEVENTSTATE_RECEIPTID_KEY];
      NSString *receiptWithId = [NSString stringWithFormat:@"%@::%@;;;", idKey, receipt];
      [receipts_string appendString:receiptWithId];
      transactionId++;
    }
  }
  return receipts_string;
}

- (BOOL)areAllEventsImplicit
{
  for (NSDictionary<NSString *, id> *event in _mutableEvents) {
    if (![[event valueForKey:FBSDK_APPEVENTSTATE_ISIMPLICIT_KEY] boolValue]) {
      return NO;
    }
  }
  return YES;
}

- (BOOL)isCompatibleWithAppEventsState:(FBSDKAppEventsState *)appEventsState
{
  return ([self isCompatibleWithTokenString:appEventsState.tokenString appID:appEventsState.appID]);
}

- (BOOL)isCompatibleWithTokenString:(NSString *)tokenString appID:(NSString *)appID
{
  // token strings can be nil (e.g., no user token) but appIDs should not.
  BOOL tokenCompatible = ([self.tokenString isEqualToString:tokenString]
    || (self.tokenString == nil && tokenString == nil));
  return (tokenCompatible
    && [self.appID isEqualToString:appID]);
}

- (NSString *)JSONStringForEventsIncludingImplicitEvents:(BOOL)includeImplicitEvents
{
  if (_eventProcessors != nil) {
    for (id<FBSDKEventsProcessing> processor in _eventProcessors) {
      [processor processEvents:_mutableEvents];
    }
  }
  NSMutableArray *events = [[NSMutableArray alloc] initWithCapacity:_mutableEvents.count];
  for (NSDictionary<NSString *, id> *eventAndImplicitFlag in _mutableEvents) {
    const BOOL isImplicitEvent = [eventAndImplicitFlag[FBSDK_APPEVENTSTATE_ISIMPLICIT_KEY] boolValue];
    if (!includeImplicitEvents && isImplicitEvent) {
      continue;
    }
    NSMutableDictionary<NSString *, id> *event = eventAndImplicitFlag[@"event"];
    NSAssert(event != nil, @"event cannot be nil");
    [event removeObjectForKey:FBSDK_APPEVENTSTATE_RECEIPTDATA_KEY];

    [FBSDKTypeUtility array:events addObject:event];
  }

  return [FBSDKBasicUtility JSONStringForObject:events error:NULL invalidObjectHandler:NULL];
}

#ifdef DEBUG
 #if FBTEST
+ (NSArray<id<FBSDKEventsProcessing>> *)eventProcessors
{
  return _eventProcessors;
}

 #endif
#endif

@end
