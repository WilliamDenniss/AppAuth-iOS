/*! @file OIDRPProfileCode.m
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2017 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import "OIDRPProfileCode.h"

#import <XCTest/XCTest.h>
#import "AppAuth.h"

static NSString *const kRedirectURI = @"com.example.app:/oauth2redirect/example-provider";

static NSString *const kTestURIBase =
    @"https://rp.certification.openid.net:8080/appauth-ios-macos/";

/*! @brief A UI Coordinator for testing, has no user agent and doesn't support user interaction.
        Simply performs the authorization request as a GET request, and looks for a redirect in
        the response.
 */
@interface OIDAuthorizationUICoordinatorNonInteractive () <NSURLSessionTaskDelegate>
@end

@implementation OIDAuthorizationUICoordinatorNonInteractive

- (BOOL)presentAuthorizationWithURL:(NSURL *)URL session:(id<OIDAuthorizationFlowSession>)session {
  _session = session;
  NSMutableURLRequest *URLRequest = [[NSURLRequest requestWithURL:URL] mutableCopy];
  NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
  _urlSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
  [[_urlSession dataTaskWithRequest:URLRequest
              completionHandler:^(NSData *_Nullable data,
                                  NSURLResponse *_Nullable response,
                                  NSError *_Nullable error) {
    NSDictionary* headers = [(NSHTTPURLResponse *)response allHeaderFields];
    NSString *location = [headers objectForKey:@"Location"];
    NSURL *url = [NSURL URLWithString:location];
    [session resumeAuthorizationFlowWithURL:url];
  }] resume];

  return YES;
}

- (void)dismissAuthorizationAnimated:(BOOL)animated completion:(void (^)(void))completion {
  if (completion) completion();
}

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *))completionHandler {
  // Disables HTTP redirection in the NSURLSession
  completionHandler(NULL);
}
@end

@interface OIDAuthorizationFlowSessionImplementation : NSObject<OIDAuthorizationFlowSession>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRequest:(OIDAuthorizationRequest *)request
    NS_DESIGNATED_INITIALIZER;

@end

@interface OIDRPProfileCode ()

typedef void (^PostRegistrationCallback)(OIDServiceConfiguration *configuration,
                                         OIDRegistrationResponse *registrationResponse,
                                         NSError *error
                                         );

@end

@implementation OIDRPProfileCode

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)doRegistrationWithIssuer:(NSURL *)issuer callback:(PostRegistrationCallback)callback {
  NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];

  // discovers endpoints
  [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer
      completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {

    if (!configuration) {
      callback(nil, nil, error);
      return;
    }

    OIDRegistrationRequest *request =
        [[OIDRegistrationRequest alloc] initWithConfiguration:configuration
                                                 redirectURIs:@[ redirectURI ]
                                                responseTypes:nil
                                                   grantTypes:nil
                                                  subjectType:nil
                                      tokenEndpointAuthMethod:@"client_secret_basic"
                                         additionalParameters:nil];
    // performs registration request
    [OIDAuthorizationService performRegistrationRequest:request
        completion:^(OIDRegistrationResponse *_Nullable regResp, NSError *_Nullable error) {
      if (regResp) {
        callback(configuration, regResp, nil);
      } else {
        callback(nil, nil, error);
      }
    }];
  }];
}


- (void)testRP_response_type_code {
  [self codeFlowWithExchangeForTest:@"rp-response_type-code"];
}
- (void)codeFlowWithExchangeForTest:(NSString *)test {

  [kTestURIBase stringByAppendingString:test];

  NSString *issuerString = [kTestURIBase stringByAppendingString:test];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Discovery and registration should complete."];

  XCTestExpectation *auth_complete =
      [self expectationWithDescription:@"Authorization should complete."];

  XCTestExpectation *token_exchange =
      [self expectationWithDescription:@"Token Exchange should complete."];

  NSURL *issuer = [NSURL URLWithString:issuerString];

  [self doRegistrationWithIssuer:issuer callback:^(OIDServiceConfiguration *configuration,
                                                   OIDRegistrationResponse *registrationResponse,
                                                   NSError *error) {
    [expectation fulfill];
    XCTAssertNotNil(configuration);
    XCTAssertNotNil(registrationResponse);
    XCTAssertNil(error);

    NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];
    // builds authentication request
    OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:registrationResponse.clientID
                                                  clientSecret:registrationResponse.clientSecret
                                                        scopes:@[ OIDScopeOpenID, OIDScopeProfile ]
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];

  _coordinator = [[OIDAuthorizationUICoordinatorNonInteractive alloc] init];

  [OIDAuthorizationService
      presentAuthorizationRequest:request
                    UICoordinator:_coordinator
                         callback:^(OIDAuthorizationResponse *_Nullable authorizationResponse,
                                   NSError *error) {
      [auth_complete fulfill];
      XCTAssertNotNil(authorizationResponse);
      XCTAssertNil(error);

      OIDTokenRequest *tokenExchangeRequest = [authorizationResponse tokenExchangeRequest];
      [OIDAuthorizationService
         performTokenRequest:tokenExchangeRequest
                    callback:^(OIDTokenResponse *_Nullable tokenResponse,
                               NSError *_Nullable tokenError) {

                      [token_exchange fulfill];
                      XCTAssertNotNil(tokenResponse);
                      XCTAssertNil(tokenError);

                      // testRP_id_token_sig_none
                      XCTAssertNotNil(tokenResponse.idToken);
                    }];
    }];

  }];
  [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testRP_id_token_sig_none {
  [self codeFlowWithExchangeForTest:@"rp-id_token-sig-none"];
}

- (void)testRP_token_endpoint_client_secret_basic {
  [self codeFlowWithExchangeForTest:@"rp-token_endpoint-client_secret_basic"];
}

- (void)testRP_id_token_aud {
  [self codeFlowWithExchangeInvalidIDToken:@"rp-id_token-aud"];
}
- (void)testRP_id_token_iat {
  [self codeFlowWithExchangeInvalidIDToken:@"rp-id_token-iat"];
}
- (void)testRP_id_token_sub {
  [self codeFlowWithExchangeInvalidIDToken:@"rp-id_token-sub"];
}
- (void)testRP_id_token_issuer_mismatch {
  [self codeFlowWithExchangeInvalidIDToken:@"rp-id_token-issuer-mismatch"];
}
//

- (void)codeFlowWithExchangeInvalidIDToken:(NSString*) testName {

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Discovery and registration should complete."];

  XCTestExpectation *auth_complete =
      [self expectationWithDescription:@"Authorization should complete."];

  XCTestExpectation *token_exchange =
      [self expectationWithDescription:@"Token Exchange should complete."];

  NSString *issuerString = [kTestURIBase stringByAppendingString:testName];

  NSURL *issuer = [NSURL URLWithString:issuerString];

  [self doRegistrationWithIssuer:issuer callback:^(OIDServiceConfiguration *configuration,
                                                   OIDRegistrationResponse *registrationResponse,
                                                   NSError *error) {
    [expectation fulfill];
    XCTAssertNotNil(configuration);
    XCTAssertNotNil(registrationResponse);
    XCTAssertNil(error);

    NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];
    // builds authentication request
    OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:registrationResponse.clientID
                                                  clientSecret:registrationResponse.clientSecret
                                                        scopes:@[ OIDScopeOpenID, OIDScopeProfile ]
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];

  _coordinator = [[OIDAuthorizationUICoordinatorNonInteractive alloc] init];

  [OIDAuthorizationService
      presentAuthorizationRequest:request
                    UICoordinator:_coordinator
                         callback:^(OIDAuthorizationResponse *_Nullable authorizationResponse,
                                   NSError *error) {
      [auth_complete fulfill];
      XCTAssertNotNil(authorizationResponse);
      XCTAssertNil(error);

      OIDTokenRequest *tokenExchangeRequest = [authorizationResponse tokenExchangeRequest];
      [OIDAuthorizationService
         performTokenRequest:tokenExchangeRequest
                    callback:^(OIDTokenResponse *_Nullable tokenResponse,
                               NSError *_Nullable tokenError) {

                      [token_exchange fulfill];
                      XCTAssertNil(tokenResponse);
                      XCTAssertNotNil(tokenError);
                    }];
    }];

  }];
  [self waitForExpectationsWithTimeout:20 handler:nil];
}

@end


