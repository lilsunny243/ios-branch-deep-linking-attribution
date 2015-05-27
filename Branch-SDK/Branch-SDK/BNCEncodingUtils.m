//
//  BNCEncodingUtils.m
//  Branch
//
//  Created by Graham Mueller on 3/31/15.
//  Copyright (c) 2015 Branch Metrics. All rights reserved.
//

#import "BNCEncodingUtils.h"
#import "BNCPreferenceHelper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation BNCEncodingUtils

#pragma mark - Base 64 encoding

// BASE 64 encoding brought to you by http://ios-dev-blog.com/base64-encodingdecoding/

static const char _base64EncodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const short _base64DecodingTable[256] = {
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -2, -1, -1, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, 62, -2, -2, -2, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -2, -2, -2, -2, -2, -2,
    -2,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -2, -2, -2, -2, -2,
    -2, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2
};

+ (NSString *)base64EncodeStringToString:(NSString *)strData {
    return [self base64EncodeData:[strData dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSString *)base64DecodeStringToString:(NSString *)strData {
    return [[NSString alloc] initWithData:[BNCEncodingUtils base64DecodeString:strData] encoding:NSUTF8StringEncoding];
}

+ (NSString *)base64EncodeData:(NSData *)objData {
    const unsigned char * objRawData = [objData bytes];
    char * objPointer;
    char * strResult;
    
    // Get the Raw Data length and ensure we actually have data
    long intLength = [objData length];
    if (intLength == 0) return nil;
    
    // Setup the String-based Result placeholder and pointer within that placeholder
    strResult = (char *)calloc(((intLength + 2) / 3) * 4, sizeof(char));
    objPointer = strResult;
    
    // Iterate through everything
    while (intLength > 2) { // keep going until we have less than 24 bits
        *objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
        *objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
        *objPointer++ = _base64EncodingTable[((objRawData[1] & 0x0f) << 2) + (objRawData[2] >> 6)];
        *objPointer++ = _base64EncodingTable[objRawData[2] & 0x3f];
        
        // we just handled 3 octets (24 bits) of data
        objRawData += 3;
        intLength -= 3;
    }
    
    // now deal with the tail end of things
    if (intLength != 0) {
        *objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
        if (intLength > 1) {
            *objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
            *objPointer++ = _base64EncodingTable[(objRawData[1] & 0x0f) << 2];
            *objPointer++ = '=';
        } else {
            *objPointer++ = _base64EncodingTable[(objRawData[0] & 0x03) << 4];
            *objPointer++ = '=';
            *objPointer++ = '=';
        }
    }
    
    // Terminate the string-based result
    *objPointer = '\0';
    
    NSString *retString = [NSString stringWithCString:strResult encoding:NSASCIIStringEncoding];
    free(strResult);
    
    // Return the results as an NSString object
    return retString;
}

+ (NSData *)base64DecodeString:(NSString *)strBase64 {
    const char * objPointer = [strBase64 cStringUsingEncoding:NSASCIIStringEncoding];
    long intLength = strlen(objPointer);
    int intCurrent;
    int i = 0, j = 0, k;
    
    char * objResult;
    objResult = calloc(intLength, sizeof(char));
    
    // Run through the whole string, converting as we go
    while ( ((intCurrent = *objPointer++) != '\0') && (intLength-- > 0) ) {
        if (intCurrent == '=') {
            if (*objPointer != '=' && ((i % 4) == 1)) {// || (intLength > 0)) {
                // the padding character is invalid at this point -- so this entire string is invalid
                free(objResult);
                return nil;
            }
            continue;
        }
        
        intCurrent = _base64DecodingTable[intCurrent];
        if (intCurrent == -1) {
            // we're at a whitespace -- simply skip over
            continue;
        } else if (intCurrent == -2) {
            // we're at an invalid character
            free(objResult);
            return nil;
        }
        
        switch (i % 4) {
            case 0:
                objResult[j] = intCurrent << 2;
                break;
                
            case 1:
                objResult[j++] |= intCurrent >> 4;
                objResult[j] = (intCurrent & 0x0f) << 4;
                break;
                
            case 2:
                objResult[j++] |= intCurrent >>2;
                objResult[j] = (intCurrent & 0x03) << 6;
                break;
                
            case 3:
                objResult[j++] |= intCurrent;
                break;
        }
        i++;
    }
    
    // mop things up if we ended on a boundary
    k = j;
    if (intCurrent == '=') {
        switch (i % 4) {
            case 1:
                // Invalid state
                free(objResult);
                return nil;
                
            case 2:
                k++;
                // flow through
            case 3:
                objResult[k] = 0;
        }
    }
    
    // Cleanup and setup the return NSData
    NSData * objData = [[NSData alloc] initWithBytes:objResult length:j] ;
    free(objResult);
    return objData;
}


#pragma mark - MD5 methods

+ (NSString *)md5Encode:(NSString *)input {
    if (!input) {
        return @"";
    }

    const char *cStr = [input UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return  output;
}


#pragma mark - Param Encoding methods

+ (NSString *)iso8601StringFromDate:(NSDate *)date {
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]; // POSIX to avoid weird issues
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    });
    
    return [dateFormatter stringFromDate:date];
}

+ (NSString *)sanitizedStringFromString:(NSString *)dirtyString {
    NSString *cleanString = [[[[dirtyString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
                                            stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]
                                            stringByReplacingOccurrencesOfString:@"’" withString:@"'"]
                                            stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];

    return cleanString;
}

+ (NSData *)encodeDictionaryToJsonData:(NSDictionary *)dictionary {
    return [[BNCEncodingUtils encodeDictionaryToJsonString:dictionary] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *)encodeDictionaryToJsonString:(NSDictionary *)dictionary {
    return [BNCEncodingUtils encodeDictionaryToJsonString:dictionary needSource:YES];
}

+ (NSString *)encodeDictionaryToJsonString:(NSDictionary *)dictionary needSource:(BOOL)source {
    NSMutableString *encodedDictionary = [[NSMutableString alloc] initWithString:@"{"];
    for (NSString *key in dictionary) {
        NSString *value = nil;
        BOOL string = YES;
        
        id obj = dictionary[key];
        if ([obj isKindOfClass:[NSString class]]) {
            value = [BNCEncodingUtils sanitizedStringFromString:obj];
        }
        else if ([obj isKindOfClass:[NSURL class]]) {
            value = [obj absoluteString];
        }
        else if ([obj isKindOfClass:[NSDate class]]) {
            value = [BNCEncodingUtils iso8601StringFromDate:obj];
        }
        else if ([obj isKindOfClass:[NSArray class]]) {
            value = [BNCEncodingUtils encodeArrayToJsonString:obj];
            string = NO;
        }
        else if ([obj isKindOfClass:[NSDictionary class]]) {
            value = [BNCEncodingUtils encodeDictionaryToJsonString:obj needSource:NO]; // Sub dictionaries have no need for source
            string = NO;
        }
        else if ([obj isKindOfClass:[NSNumber class]]) {
            value = [obj stringValue];
            string = NO;
        }
        else if ([obj isKindOfClass:[NSNull class]]) {
            value = @"null";
            string = NO;
        }
        else {
            // If this type is not a known type, don't attempt to encode it.
            NSLog(@"Cannot encode value for key %@, type is in list of accepted types", key);
            continue;
        }
        
        [encodedDictionary appendFormat:@"\"%@\":", [BNCEncodingUtils sanitizedStringFromString:key]];
        
        // If this is a "string" object, wrap it in quotes
        if (string) {
            [encodedDictionary appendFormat:@"\"%@\",", value];
        }
        // Otherwise, just add the raw value after the colon
        else {
            [encodedDictionary appendFormat:@"%@,", value];
        }
    }
    
    if (source) {
        [encodedDictionary appendString:@"\"source\":\"ios\"}"];
    }
    else {
        // Delete the trailing comma. Not necessary for an empty dictionary
        if (encodedDictionary.length > 1) {
            [encodedDictionary deleteCharactersInRange:NSMakeRange([encodedDictionary length] - 1, 1)];
        }

        [encodedDictionary appendString:@"}"];
    }
    
    if ([BNCPreferenceHelper isDebug]) {
        NSLog(@"encoded dictionary : %@", encodedDictionary);
    }
    
    return encodedDictionary;
}

+ (NSString *)encodeArrayToJsonString:(NSArray *)array {
    // Empty array
    if (![array count]) {
        return @"[]";
    }

    NSMutableString *encodedArray = [[NSMutableString alloc] initWithString:@"["];
    for (id obj in array) {
        NSString *value = nil;
        BOOL string = YES;
        
        if ([obj isKindOfClass:[NSString class]]) {
            value = [BNCEncodingUtils sanitizedStringFromString:obj];
        }
        else if ([obj isKindOfClass:[NSURL class]]) {
            value = [obj absoluteString];
        }
        else if ([obj isKindOfClass:[NSDate class]]) {
            value = [BNCEncodingUtils iso8601StringFromDate:obj];
        }
        else if ([obj isKindOfClass:[NSArray class]]) {
            value = [BNCEncodingUtils encodeArrayToJsonString:obj];
            string = NO;
        }
        else if ([obj isKindOfClass:[NSDictionary class]]) {
            value = [BNCEncodingUtils encodeDictionaryToJsonString:obj needSource:NO]; // Sub dictionaries have no need for source
            string = NO;
        }
        else if ([obj isKindOfClass:[NSNumber class]]) {
            value = [obj stringValue];
            string = NO;
        }
        else if ([obj isKindOfClass:[NSNull class]]) {
            value = @"null";
            string = NO;
        }
        else {
            // If this type is not a known type, don't attempt to encode it.
            NSLog(@"Cannot encode value %@, type is not in list of accepted types", obj);
            continue;
        }
        
        // If this is a "string" object, wrap it in quotes
        if (string) {
            [encodedArray appendFormat:@"\"%@\",", value];
        }
        // Otherwise, just add the raw value after the colon
        else {
            [encodedArray appendFormat:@"%@,", value];
        }
    }
    
    // Delete the trailing comma
    [encodedArray deleteCharactersInRange:NSMakeRange([encodedArray length] - 1, 1)];
    [encodedArray appendString:@"]"];
    
    if ([BNCPreferenceHelper isDebug]) {
        NSLog(@"encoded array : %@", encodedArray);
    }

    return encodedArray;
}

+ (NSString *)urlEncodedString:(NSString *)string {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, CFSTR("!*'\"();:@&=+$,/?%#[]% "), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)));
}

+ (NSString *)encodeDictionaryToQueryString:(NSDictionary *)dictionary {
    NSMutableString *queryString = [[NSMutableString alloc] initWithString:@"?"];

    for (NSString *key in [dictionary allKeys]) {
        // No empty keys, please.
        if (key.length) {
            id obj = dictionary[key];
            NSString *value;
            
            if ([obj isKindOfClass:[NSString class]]) {
                value = [BNCEncodingUtils urlEncodedString:obj];
            }
            else if ([obj isKindOfClass:[NSURL class]]) {
                value = [BNCEncodingUtils urlEncodedString:[obj absoluteString]];
            }
            else if ([obj isKindOfClass:[NSDate class]]) {
                value = [BNCEncodingUtils iso8601StringFromDate:obj];
            }
            else if ([obj isKindOfClass:[NSNumber class]]) {
                value = [obj stringValue];
            }
            else {
                // If this type is not a known type, don't attempt to encode it.
                NSLog(@"Cannot encode value %@, type is in not list of accepted types", obj);
                continue;
            }
            
            [queryString appendFormat:@"%@=%@&", [BNCEncodingUtils urlEncodedString:key], value];
        }
    }

    // Delete last character (either trailing & or ? if no params present)
    [queryString deleteCharactersInRange:NSMakeRange(queryString.length - 1, 1)];
    
    return queryString;
}

#pragma mark - Param Decoding methods
+ (NSDictionary *)decodeJsonDataToDictionary:(NSData *)jsonData {
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return [BNCEncodingUtils decodeJsonStringToDictionary:jsonString];
}

+ (NSDictionary *)decodeJsonStringToDictionary:(NSString *)jsonString {
    // Nothing to do with this guy, just return an empty dictionary
    if ([jsonString isEqualToString:NO_STRING_VALUE]) {
        return @{};
    }
    
    // Just a basic decode, easy enough
    NSData *tempData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!tempData) {
        return @{};
    }
    NSDictionary *plainDecodedDictionary = [NSJSONSerialization JSONObjectWithData:tempData options:NSJSONReadingMutableContainers error:nil];
    if (plainDecodedDictionary) {
        return plainDecodedDictionary;
    }

    // If the first decode failed, it could be because the data was encoded. Try decoding first.
    NSString *decodedVersion = [BNCEncodingUtils base64DecodeStringToString:jsonString];
    tempData = [decodedVersion dataUsingEncoding:NSUTF8StringEncoding];
    if (!tempData) {
        return @{};
    }
    NSDictionary *base64DecodedDictionary = [NSJSONSerialization JSONObjectWithData:tempData options:NSJSONReadingMutableContainers error:nil];
    if (base64DecodedDictionary) {
        return base64DecodedDictionary;
    }

    // Apparently this data was not parsible into a dictionary, so we'll just return an empty one
    return @{};
}

+ (NSDictionary *)decodeQueryStringToDictionary:(NSString *)queryString {
    NSArray *pairs = [queryString componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];

    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count > 1) { // If this key has a value (so, not foo&bar=...)
            NSString *key = kv[0];
            NSString *val = [kv[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
            // Don't add empty items
            if (val.length) {
                params[key] = val;
            }
        }
    }

    return params;
}

@end
