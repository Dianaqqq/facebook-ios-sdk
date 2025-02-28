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

#import "FBSDKLogger.h"
#import "FBSDKLogger+Internal.h"

#import "FBSDKCoreKitBasicsImport.h"
#import "FBSDKInternalUtility+Internal.h"
#import "FBSDKSettings.h"

static NSUInteger g_serialNumberCounter = 1111;
static NSMutableDictionary<NSString *, id> *g_stringsToReplace = nil;
static NSMutableDictionary<NSNumber *, id> *g_startTimesWithTags = nil;

@interface FBSDKLogger ()

@property (nonatomic, readonly, strong) NSMutableString *internalContents;
@end

@implementation FBSDKLogger
NSUInteger _loggerSerialNumber;
FBSDKLoggingBehavior _loggingBehavior;
BOOL _active;

// Lifetime

- (instancetype)initWithLoggingBehavior:(NSString *)loggingBehavior
{
  if ((self = [super init])) {
    _active = [FBSDKSettings.loggingBehaviors containsObject:loggingBehavior];
    _loggingBehavior = loggingBehavior;
    if (_active) {
      _internalContents = [NSMutableString new];
      _loggerSerialNumber = [FBSDKLogger generateSerialNumber];
    }
  }

  return self;
}

// Public properties

- (NSString *)contents
{
  return _internalContents;
}

- (void)setContents:(NSString *)contents
{
  if (_active) {
    _internalContents = [NSMutableString stringWithString:contents];
  }
}

- (NSUInteger)loggerSerialNumber
{
  return _loggerSerialNumber;
}

- (FBSDKLoggingBehavior)loggingBehavior
{
  return _loggingBehavior;
}

- (BOOL)isActive
{
  return _active;
}

// Public instance methods

- (void)appendString:(NSString *)string
{
  if (_active) {
    [_internalContents appendString:string];
  }
}

- (void)appendFormat:(NSString *)formatString, ...
{
  if (_active) {
    va_list vaArguments;
    va_start(vaArguments, formatString);
    NSString *logString = [[NSString alloc] initWithFormat:formatString arguments:vaArguments];
    va_end(vaArguments);

    [self appendString:logString];
  }
}

- (void)appendKey:(NSString *)key value:(NSString *)value
{
  if (_active && value.length) {
    [_internalContents appendFormat:@"  %@:\t%@\n", key, value];
  }
}

- (void)emitToNSLog
{
  if (_active) {
    for (NSString *key in [g_stringsToReplace keyEnumerator]) {
      [_internalContents replaceOccurrencesOfString:key
                                         withString:g_stringsToReplace[key]
                                            options:NSLiteralSearch
                                              range:NSMakeRange(0, _internalContents.length)];
    }

    // Xcode 4.4 hangs on extremely long NSLog output (http://openradar.appspot.com/11972490).  Truncate if needed.
    const int MAX_LOG_STRING_LENGTH = 10000;
    NSString *logString = _internalContents;
    if (_internalContents.length > MAX_LOG_STRING_LENGTH) {
      logString = [NSString stringWithFormat:@"TRUNCATED: %@", [_internalContents substringToIndex:MAX_LOG_STRING_LENGTH]];
    }
    NSLog(@"FBSDKLog: %@", logString);

    [_internalContents setString:@""];
  }
}

// Public static methods

+ (NSUInteger)generateSerialNumber
{
  @synchronized(self) {
    return ++g_serialNumberCounter;
  }
}

+ (void)singleShotLogEntry:(NSString *)loggingBehavior
                  logEntry:(NSString *)logEntry
{
  FBSDKLogger *logger = [[FBSDKLogger alloc] initWithLoggingBehavior:loggingBehavior];
  [logger logEntry:logEntry];
}

- (void)logEntry:(NSString *)logEntry
{
  if ([FBSDKSettings.loggingBehaviors containsObject:_loggingBehavior]) {
    [self appendString:logEntry];
    [self emitToNSLog];
  }
}

+ (void)singleShotLogEntry:(NSString *)loggingBehavior
              timestampTag:(NSObject *)timestampTag
              formatString:(NSString *)formatString, ...
{
  if ([FBSDKSettings.loggingBehaviors containsObject:loggingBehavior]) {
    va_list vaArguments;
    va_start(vaArguments, formatString);
    NSString *logString = [[NSString alloc] initWithFormat:formatString arguments:vaArguments];
    va_end(vaArguments);

    // Start time of this "timestampTag" is stashed in the dictionary.
    // Treat the incoming object tag simply as an address, since it's only used to identify during lifetime.  If
    // we send in as an object, the dictionary will try to copy it.
    NSNumber *tagAsNumber = @((unsigned long)(__bridge void *)timestampTag);
    NSNumber *startTimeNumber = g_startTimesWithTags[tagAsNumber];

    // Only log if there's been an associated start time.
    if (startTimeNumber != nil) {
      uint64_t elapsed = [FBSDKInternalUtility.sharedUtility currentTimeInMilliseconds] - startTimeNumber.unsignedLongLongValue;
      [g_startTimesWithTags removeObjectForKey:tagAsNumber]; // served its purpose, remove

      // Log string is appended with "%d msec", with nothing intervening.  This gives the most control to the caller.
      logString = [NSString stringWithFormat:@"%@%llu msec", logString, elapsed];

      [self singleShotLogEntry:loggingBehavior logEntry:logString];
    }
  }
}

+ (void)registerCurrentTime:(NSString *)loggingBehavior
                    withTag:(NSObject *)timestampTag
{
  if ([FBSDKSettings.loggingBehaviors containsObject:loggingBehavior]) {
    if (!g_startTimesWithTags) {
      g_startTimesWithTags = [NSMutableDictionary new];
    }

    if (g_startTimesWithTags.count >= 1000) {
      [FBSDKLogger singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors logEntry:
       @"Unexpectedly large number of outstanding perf logging start times, something is likely wrong."];
    }

    uint64_t currTime = [FBSDKInternalUtility.sharedUtility currentTimeInMilliseconds];

    // Treat the incoming object tag simply as an address, since it's only used to identify during lifetime.  If
    // we send in as an object, the dictionary will try to copy it.
    unsigned long tagAsNumber = (unsigned long)(__bridge void *)timestampTag;
    [FBSDKTypeUtility dictionary:g_startTimesWithTags setObject:@(currTime) forKey:@(tagAsNumber)];
  }
}

+ (void)registerStringToReplace:(NSString *)replace
                    replaceWith:(NSString *)replaceWith
{
  // Strings sent in here never get cleaned up, but that's OK, don't ever expect too many.

  if (FBSDKSettings.loggingBehaviors.count > 0) { // otherwise there's no logging.
    if (!g_stringsToReplace) {
      g_stringsToReplace = [NSMutableDictionary new];
    }

    [g_stringsToReplace setValue:replaceWith forKey:replace];
  }
}

@end
