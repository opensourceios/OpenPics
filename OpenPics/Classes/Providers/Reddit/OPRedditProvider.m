//
//  OPRedditProvider.m
//  OpenPics
//
//  Created by PJ Gray on 6/11/14.
//  Copyright (c) 2014 Say Goodnight Software. All rights reserved.
//

#import "OPRedditProvider.h"
#import "OPImageItem.h"
#import "OPProviderTokens.h"
#import "AFHTTPSessionManager.h"

@interface OPRedditProvider ()

// Reddit API uses 'after' hashes rather than page numbers, this is a mapping
@property (strong, nonatomic) NSMutableDictionary* pageNumberAfters;

@end

@implementation OPRedditProvider

- (id) initWithProviderType:(NSString*) providerType {
    self = [super initWithProviderType:providerType];
    if (self) {
        self.pageNumberAfters = @{}.mutableCopy;
    }
    return self;
}

- (BOOL) isConfigured {
    return YES;
}

- (void) doInitialSearchWithSubreddit:(NSString*) subreddit
                              success:(void (^)(NSArray* items, BOOL canLoadMore))success
                              failure:(void (^)(NSError* error))failure {
    [self getItemsWithQuery:@""
             withPageNumber:@1
              withSubreddit:subreddit
                    success:success
                    failure:failure];
}

- (void) getItemsWithQuery:(NSString*) queryString
            withPageNumber:(NSNumber*) pageNumber
             withSubreddit:(NSString*) subreddit
                   success:(void (^)(NSArray* items, BOOL canLoadMore))success
                   failure:(void (^)(NSError* error))failure {
    
    NSString* path = [NSString stringWithFormat:@"/r/%@.json", subreddit];
    
    NSDictionary* parameters = nil;
    
    if (pageNumber.integerValue > 1) {
        NSString* thisPageAfter = self.pageNumberAfters[pageNumber];
        if (thisPageAfter) {
            parameters = @{@"after" : thisPageAfter};
        }
    }

    NSURL* baseUrl = [[NSURL alloc] initWithString:@"http://www.reddit.com"];
    AFHTTPSessionManager* manager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseUrl];
    [manager GET:path parameters:parameters success:^(NSURLSessionDataTask *task, id responseObject) {
        
        
        NSDictionary* dataDict = responseObject[@"data"];
        NSString* after = dataDict[@"after"];
        if (after) {
            self.pageNumberAfters[@(pageNumber.integerValue+1)] = after;
        }
        
        NSMutableArray* retArray = [NSMutableArray array];
        NSArray* childrenArray = dataDict[@"children"];
        for (NSDictionary* itemDict in childrenArray) {
            NSDictionary* itemDataDict = itemDict[@"data"];
            
            NSString* urlString = itemDataDict[@"url"];
            NSString* domain = itemDataDict[@"domain"];
            if (domain && [domain isEqualToString:@"imgur.com"] && ![urlString hasSuffix:@".jpg"]) {
                urlString = [urlString stringByAppendingString:@".jpg"];
            }
            
            if ([urlString hasSuffix:@".jpg"]) {
                NSMutableDictionary* opImageDict = @{
                                                     @"imageUrl":[NSURL URLWithString:urlString],
                                                     @"title" : itemDataDict[@"title"],
                                                     @"providerType": self.providerType,
                                                     @"providerSpecific": itemDataDict,
                                                     }.mutableCopy;
                
                
                OPImageItem* item = [[OPImageItem alloc] initWithDictionary:opImageDict];
                [retArray addObject:item];                
            }
        }
        
        BOOL returnCanLoadMore = NO;
        if (after) {
            returnCanLoadMore = YES;
        }
        
        if (success) {
            success(retArray,returnCanLoadMore);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        if (failure) {
            failure(error);
        }
        NSLog(@"ERROR: %@\n%@\n%@", error.localizedDescription,error.localizedFailureReason,error.localizedRecoverySuggestion);
    }];
}

- (void) upRezItem:(OPImageItem *) item withCompletion:(void (^)(NSURL *uprezImageUrl, OPImageItem* item))completion {
}

@end