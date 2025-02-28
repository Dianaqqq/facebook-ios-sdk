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

#import "FBSDKGraphRequestBody.h"

#import "FBSDKConstants.h"
#import "FBSDKCoreKitBasicsImport.h"
#import "FBSDKCrypto.h"
#import "FBSDKGraphRequestDataAttachment.h"
#import "FBSDKLogger.h"
#import "FBSDKLogger+Internal.h"
#import "FBSDKSettings.h"

#define kNewline @"\r\n"

@implementation FBSDKGraphRequestBody
{
  NSMutableData *_data;
  NSMutableDictionary<NSString *, id> *_json;
  NSString *_stringBoundary;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _stringBoundary = [FBSDKCrypto randomString:32];
    _data = [NSMutableData new];
    _json = [NSMutableDictionary dictionary];
    _requiresMultipartDataFormat = NO;
  }

  return self;
}

- (NSString *)mimeContentType
{
  if (self.requiresMultipartDataFormat) {
    return [NSString stringWithFormat:@"multipart/form-data; boundary=%@", _stringBoundary];
  } else {
    return @"application/json";
  }
}

- (void)appendUTF8:(NSString *)utf8
{
  if (!_data.length) {
    NSString *headerUTF8 = [NSString stringWithFormat:@"--%@%@", _stringBoundary, kNewline];
    NSData *headerData = [headerUTF8 dataUsingEncoding:NSUTF8StringEncoding];
    [_data appendData:headerData];
  }
  NSData *data = [utf8 dataUsingEncoding:NSUTF8StringEncoding];
  [_data appendData:data];
}

- (void)appendWithKey:(NSString *)key
            formValue:(NSString *)value
               logger:(FBSDKLogger *)logger
{
  [self _appendWithKey:key filename:nil contentType:nil contentBlock:^{
    [self appendUTF8:value];
  }];
  if (key && value) {
    [FBSDKTypeUtility dictionary:_json setObject:value forKey:key];
  }
  [logger appendFormat:@"\n    %@:\t%@", key, (NSString *)value];
}

- (void)appendWithKey:(NSString *)key
           imageValue:(UIImage *)image
               logger:(FBSDKLogger *)logger
{
  NSData *data = UIImageJPEGRepresentation(image, [FBSDKSettings JPEGCompressionQuality]);
  [self _appendWithKey:key filename:key contentType:@"image/jpeg" contentBlock:^{
    [self->_data appendData:data];
  }];
  self.requiresMultipartDataFormat = YES;
  [logger appendFormat:@"\n    %@:\t<Image - %lu kB>", key, (unsigned long)(data.length / 1024)];
}

- (void)appendWithKey:(NSString *)key
            dataValue:(NSData *)data
               logger:(FBSDKLogger *)logger
{
  [self _appendWithKey:key filename:key contentType:@"content/unknown" contentBlock:^{
    [self->_data appendData:data];
  }];
  self.requiresMultipartDataFormat = YES;
  [logger appendFormat:@"\n    %@:\t<Data - %lu kB>", key, (unsigned long)(data.length / 1024)];
}

- (void)appendWithKey:(NSString *)key
  dataAttachmentValue:(FBSDKGraphRequestDataAttachment *)dataAttachment
               logger:(FBSDKLogger *)logger
{
  NSString *filename = dataAttachment.filename ?: key;
  NSString *contentType = dataAttachment.contentType ?: @"content/unknown";
  NSData *data = dataAttachment.data;
  [self _appendWithKey:key filename:filename contentType:contentType contentBlock:^{
    [self->_data appendData:data];
  }];
  self.requiresMultipartDataFormat = YES;
  [logger appendFormat:@"\n    %@:\t<Data - %lu kB>", key, (unsigned long)(data.length / 1024)];
}

- (NSData *)data
{
  if (self.requiresMultipartDataFormat) {
    return [_data copy];
  } else {
    NSData *jsonData;
    if (_json.allKeys.count > 0) {
      jsonData = [FBSDKTypeUtility dataWithJSONObject:_json options:0 error:nil];
    } else {
      jsonData = [NSData data];
    }

    return jsonData;
  }
}

- (void)_appendWithKey:(NSString *)key
              filename:(NSString *)filename
           contentType:(NSString *)contentType
          contentBlock:(FBSDKCodeBlock)contentBlock
{
  NSMutableArray *disposition = [NSMutableArray new];
  [FBSDKTypeUtility array:disposition addObject:@"Content-Disposition: form-data"];
  if (key) {
    [FBSDKTypeUtility array:disposition addObject:[[NSString alloc] initWithFormat:@"name=\"%@\"", key]];
  }
  if (filename) {
    [FBSDKTypeUtility array:disposition addObject:[[NSString alloc] initWithFormat:@"filename=\"%@\"", filename]];
  }
  [self appendUTF8:[[NSString alloc] initWithFormat:@"%@%@", [disposition componentsJoinedByString:@"; "], kNewline]];
  if (contentType) {
    [self appendUTF8:[[NSString alloc] initWithFormat:@"Content-Type: %@%@", contentType, kNewline]];
  }
  [self appendUTF8:kNewline];
  if (contentBlock != NULL) {
    contentBlock();
  }
  [self appendUTF8:[[NSString alloc] initWithFormat:@"%@--%@%@", kNewline, _stringBoundary, kNewline]];
}

- (NSData *)compressedData
{
  if (!self.data.length || ![[self mimeContentType] isEqualToString:@"application/json"]) {
    return nil;
  }

  return [FBSDKBasicUtility gzip:self.data];
}

@end
