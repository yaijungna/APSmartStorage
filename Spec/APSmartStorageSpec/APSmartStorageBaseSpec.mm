//
//  APSmartStorageBaseSpec.mm
//  APSmartStorageSpec
//
//  Created by Alexey Belkevich on 1/22/14.
//  Copyright (c) 2014 alterplay. All rights reserved.
//

#import "CedarAsync.h"
#import "APSmartStorage+Memory.h"
#import "OHHTTPStubs+AllRequests.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(APSmartStorageBaseSpec)

describe(@"APSmartStorage", ^
{
    __block APSmartStorage *storage;
    __block NSURL *objectURL;
    __block NSString *filePath;
    __block id responseObject;

    beforeEach((id)^
    {
        storage = [[APSmartStorage alloc] init];
        objectURL = [NSURL URLWithString:@"http://example.com/object_data"];
        responseObject = [@"APSmartStorage string" dataUsingEncoding:NSUTF8StringEncoding];
        // create dir
        NSArray *array = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dirPath = [array.firstObject stringByAppendingPathComponent:@"APSmartStorage"];
        [NSFileManager.defaultManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES
                                                 attributes:nil error:nil];
        // file path
        filePath = [dirPath stringByAppendingPathComponent:@"327fa8f97ba3bbd262a1768080d93f46"];
        // mocking network request
        [OHHTTPStubs stubAllRequestsWithResponseData:responseObject];
    });

    afterEach((id)^
    {
        [storage removeAllFromStorage];
        [OHHTTPStubs removeAllStubs];
    });

    it(@"should run callback on the same thread as method call", ^
    {
        __block NSThread *callbackThread;
        NSThread *currentThread = NSThread.currentThread;
        [storage loadObjectWithURL:objectURL completion:^(id object, NSError *error)
        {
            callbackThread = NSThread.currentThread;
        }];
        in_time([callbackThread isEqual:currentThread] ||
                callbackThread.isMainThread) should equal(YES);
    });

    it(@"should load object with URL from network", ^
    {
        // loading object
        __block id checkObject = nil;
        [storage loadObjectWithURL:objectURL completion:^(id object, NSError *error)
        {
            checkObject = object;
        }];
        in_time(checkObject) should_not be_nil;
        in_time(checkObject) should equal(responseObject);
    });

    it(@"should load object with URL from file", ^
    {
        // remove network mock
        [OHHTTPStubs removeAllStubs];
        [OHHTTPStubs stubAllRequestsWithNetworkDown];
        // mocking file
        NSURL *url = [NSURL fileURLWithPath:filePath];
        [responseObject writeToURL:url atomically:YES];
        // loading object
        __block id checkObject = nil;
        [storage loadObjectWithURL:objectURL completion:^(id object, NSError *error)
        {
            checkObject = object;
        }];
        in_time(checkObject) should_not be_nil;
        in_time(checkObject) should equal(responseObject);
    });

    it(@"should load object from memory storage", ^
    {
        __block id checkObject = nil;
        [storage loadObjectWithURL:objectURL completion:^(id object, NSError *error)
        {
            // remove network mock
            [OHHTTPStubs removeAllStubs];
            [OHHTTPStubs stubAllRequestsWithNetworkDown];
            // remove file
            [NSFileManager.defaultManager removeItemAtPath:filePath error:nil];
            // loading object from memory
            [storage objectFromMemoryWithURL:objectURL callback:^(id obj)
            {
                checkObject = obj;
            }];
        }];
        in_time(checkObject) should_not be_nil;
        in_time(checkObject) should equal(responseObject);
    });

    it(@"should load object from network write it to file and don't store it in memory", ^
    {
        __block id loadedObject = [[NSObject alloc] init];
        __block id memoryObject = [[NSObject alloc] init];
        __block BOOL fileExists = NO;
        [storage loadObjectWithURL:objectURL storeInMemory:NO completion:^(id object, NSError *error)
        {
            loadedObject = object;
            fileExists = [NSFileManager.defaultManager fileExistsAtPath:filePath];
            // loading object from memory
            [storage objectFromMemoryWithURL:objectURL callback:^(id obj)
            {
                memoryObject = obj;
            }];
        }];
        in_time(fileExists) should equal(YES);
        in_time(memoryObject) should be_nil;
        in_time(loadedObject) should equal(responseObject);
    });

    it(@"should load object and store it in memory if at least one call needs to store", ^
    {
        __block id memoryObject = [[NSObject alloc] init];
        [storage loadObjectWithURL:objectURL storeInMemory:NO completion:^(id object, NSError *error)
        {
            // loading object from memory
            [storage objectFromMemoryWithURL:objectURL callback:^(id obj)
            {
                memoryObject = obj;
            }];
        }];
        [storage loadObjectWithURL:objectURL storeInMemory:YES completion:nil];
        in_time(memoryObject) should equal(responseObject);
    });

    it(@"should parse loaded object with block", ^
    {
        // parsing block
        storage.parsingBlock = ^(NSData *data, NSURL *url)
        {
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        };
        // loading object
        __block id checkObject = nil;
        [storage loadObjectWithURL:objectURL completion:^(id object, NSError *error)
        {
            checkObject = object;
        }];
        in_time(checkObject) should_not be_nil;
        in_time(checkObject) should equal(@"APSmartStorage string");
    });

    it(@"should not throw exception if block returns nil", ^
    {
        // parsing block
        storage.parsingBlock = ^(NSData *data, NSURL *url)
        {
            return data ? nil : data;
        };
        // loading object
        __block BOOL isCallbackCalled = NO;
        [storage loadObjectWithURL:objectURL completion:^(id object, NSError *error)
        {
            isCallbackCalled = YES;
        }];
        in_time(isCallbackCalled) should equal(YES);
    });
});

SPEC_END