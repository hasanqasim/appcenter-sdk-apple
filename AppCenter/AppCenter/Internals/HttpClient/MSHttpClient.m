// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSHttpClient.h"
#import "MSAppCenterInternal.h"
#import "MSConstants+Internal.h"
#import "MSHttpCall.h"
#import "MSHttpClientPrivate.h"
#import "MSHttpUtil.h"
#import "MSLoggerInternal.h"
#import "MSUtility+StringFormatting.h"
#import "MS_Reachability.h"

@implementation MSHttpClient

#define DEFAULT_RETRY_INTERVALS @[ @10, @(5 * 60), @(20 * 60) ]

- (instancetype)init {
  return [self initWithMaxHttpConnectionsPerHost:nil
                                  retryIntervals:DEFAULT_RETRY_INTERVALS
                                    reachability:[MS_Reachability reachabilityForInternetConnection]];
}

- (instancetype)initWithMaxHttpConnectionsPerHost:(int)maxHttpConnectionsPerHost {
  return [self initWithMaxHttpConnectionsPerHost:@(maxHttpConnectionsPerHost)
                                  retryIntervals:DEFAULT_RETRY_INTERVALS
                                    reachability:[MS_Reachability reachabilityForInternetConnection]];
}

- (instancetype)initWithMaxHttpConnectionsPerHost:(NSNumber *)maxHttpConnectionsPerHost
                                   retryIntervals:(NSArray *)retryIntervals
                                     reachability:(MS_Reachability *)reachability {
  if ((self = [super init])) {
    _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    if (maxHttpConnectionsPerHost) {
      _sessionConfiguration.HTTPMaximumConnectionsPerHost = [maxHttpConnectionsPerHost intValue];
    }
    _session = [NSURLSession sessionWithConfiguration:_sessionConfiguration];
    _pendingCalls = [NSMutableSet new];
    _retryIntervals = [NSArray arrayWithArray:retryIntervals];
    _enabled = YES;
    _paused = NO;
    _reachability = reachability;

    // Add listener to reachability.
    [MS_NOTIFICATION_CENTER addObserver:self selector:@selector(networkStateChanged:) name:kMSReachabilityChangedNotification object:nil];
    [self.reachability startNotifier];
  }
  return self;
}

- (void)sendAsync:(NSURL *)url
               method:(NSString *)method
              headers:(nullable NSDictionary<NSString *, NSString *> *)headers
                 data:(nullable NSData *)data
    completionHandler:(MSHttpRequestCompletionHandler)completionHandler {
  MSHttpCall *call = [[MSHttpCall alloc] initWithUrl:url
                                              method:method
                                             headers:headers
                                                data:data
                                      retryIntervals:self.retryIntervals
                                   completionHandler:completionHandler];
  [self sendCallAsync:call];
}

- (void)sendCallAsync:(MSHttpCall *)call {
  @synchronized(self) {
    if (!self.enabled) {
      return;
    }
    [self.pendingCalls addObject:call];
    if (self.paused) {
      return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:call.url];
    request.HTTPBody = call.data;
    request.HTTPMethod = call.method;
    request.allHTTPHeaderFields = call.headers;

    // Always disable cookies.
    [request setHTTPShouldHandleCookies:NO];

    // Don't lose time pretty printing headers if not going to be printed.
    if ([MSLogger currentLogLevel] <= MSLogLevelVerbose) {
      MSLogVerbose([MSAppCenter logTag], @"URL: %@", request.URL);
      MSLogVerbose([MSAppCenter logTag], @"Headers: %@", [self prettyPrintHeaders:request.allHTTPHeaderFields]);
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                   [self requestCompletedWithHttpCall:call data:data response:response error:error];
                                                 }];
    [task resume];
  }
}

- (void)requestCompletedWithHttpCall:(MSHttpCall *)httpCall data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
  NSHTTPURLResponse *httpResponse;
  @synchronized(self) {

    // Handle NSError (low level error where we don't even get a HTTP response).
    BOOL internetIsDown = [MSHttpUtil isNoInternetConnectionError:error];
    BOOL couldNotEstablishSecureConnection = [MSHttpUtil isSSLConnectionError:error];
    if (error) {
      if (internetIsDown || couldNotEstablishSecureConnection) {

        // Reset the retry count, will retry once the (secure) connection is established again.
        [httpCall resetRetry];
        NSString *logMessage = internetIsDown ? @"Internet connection is down." : @"Could not establish secure connection.";
        MSLogInfo([MSAppCenter logTag], @"HTTP call failed with error: %@", logMessage);
      } else {
        MSLogError([MSAppCenter logTag], @"HTTP request error with code: %td, domain: %@, description: %@", error.code, error.domain,
                   error.localizedDescription);
      }
    }

    // Handle HTTP error.
    else {
      httpResponse = (NSHTTPURLResponse *)response;
      if ([MSHttpUtil isRecoverableError:httpResponse.statusCode] && ![httpCall hasReachedMaxRetries]) {
        [httpCall startRetryTimerWithStatusCode:httpResponse.statusCode
                                          event:^{
                                            [self sendCallAsync:httpCall];
                                          }];
        return;
      }

      // Don't lose time pretty printing if not going to be printed.
      if ([MSAppCenter logLevel] <= MSLogLevelVerbose) {
        NSString *payload = [MSUtility prettyPrintJson:data];
        MSLogVerbose([MSAppCenter logTag], @"HTTP response received with status code: %tu, payload:\n%@", httpResponse.statusCode, payload);
      }
    }
    [self.pendingCalls removeObject:httpCall];
  }

  // Unblock the caller now with the outcome of the call.
  httpCall.completionHandler(data, httpResponse, error);
}

- (void)networkStateChanged:(__unused NSNotificationCenter *)notification {
  if ([self.reachability currentReachabilityStatus] == NotReachable) {
    MSLogInfo([MSAppCenter logTag], @"Internet connection is down.");
    [self pause];
  } else {
    MSLogInfo([MSAppCenter logTag], @"Internet connection is up.");
    [self resume];
  }
}

- (void)pause {
  @synchronized(self) {
    if (self.paused) {
      return;
    }
    MSLogInfo([MSAppCenter logTag], @"Pause HTTP client.");
    self.paused = YES;

    // Reset retry for all calls.
    for (MSHttpCall *call in self.pendingCalls) {
      [call resetRetry];
    }
  }
}

- (void)resume {
  @synchronized(self) {

    // Resume only while enabled.
    if (self.paused && self.enabled) {
      MSLogInfo([MSAppCenter logTag], @"Resume HTTP client.");
      self.paused = NO;

      // Resume calls.
      for (MSHttpCall *call in self.pendingCalls) {
        [self sendCallAsync:call];
      }
    }
  }
}

- (void)setEnabled:(BOOL)isEnabled {
  @synchronized(self) {
    if (self.enabled != isEnabled) {
      _enabled = isEnabled;
      if (isEnabled) {
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration];
        [self.reachability startNotifier];
        [self resume];
      } else {
        [self.reachability stopNotifier];
        [self pause];

        // Cancel all the tasks and invalidate current session to free resources.
        [self.session invalidateAndCancel];
        self.session = nil;

        // Remove pending calls.
        [self.pendingCalls removeAllObjects];
      }
    }
  }
}

- (NSString *)obfuscateHeaderValue:(NSString *)value forKey:(NSString *)key {
  if ([key isEqualToString:kMSAuthorizationHeaderKey]) {
    return [MSHttpUtil hideAuthToken:value];
  } else if ([key isEqualToString:kMSHeaderAppSecretKey]) {
    return [MSHttpUtil hideSecret:value];
  }
  return value;
}

- (NSString *)prettyPrintHeaders:(NSDictionary<NSString *, NSString *> *)headers {
  NSMutableArray<NSString *> *flattenedHeaders = [NSMutableArray<NSString *> new];
  for (NSString *headerKey in headers) {
    [flattenedHeaders
        addObject:[NSString stringWithFormat:@"%@ = %@", headerKey, [self obfuscateHeaderValue:headers[headerKey] forKey:headerKey]]];
  }
  return [flattenedHeaders componentsJoinedByString:@", "];
}

- (void)dealloc {
  [self.reachability stopNotifier];
  [MS_NOTIFICATION_CENTER removeObserver:self name:kMSReachabilityChangedNotification object:nil];
  [self.session finishTasksAndInvalidate];
}

@end
