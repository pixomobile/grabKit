/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2013 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */


#import "GRKConstants.h"
#import "GRKFacebookConnector.h"
#import "GRKFacebookQuery.h"

#import "GRKConnectorsDispatcher.h"
#import "GRKServiceGrabber.h"

#import "GRKFacebookSingleton.h"
#import "GRKTokenStore.h"


static NSString * accessTokenKey = @"AccessTokenKey";
static NSString * expirationDateKey = @"ExpirationDateKey";


@implementation GRKFacebookConnector

-(id) initWithGrabberType:(NSString *)type;
{
    
    if ((self = [super initWithGrabberType:type]) != nil){
        
        connectionIsCompleteBlock = nil;
        connectionDidFailBlock = nil;
        
        _isConnecting = NO;
        
    }     
    
    return self;
}


/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) connectWithConnectionIsCompleteBlock:(GRKGrabberConnectionIsCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    connectionIsCompleteBlock = completeBlock;
    connectionDidFailBlock = errorBlock;
    
    // The Facebook SDK keeps internal values allowing to test, at any moment, if the session is valid or not.   
    if ( ! [FBSDKAccessToken currentAccessToken] ) {
        
        
        [[GRKConnectorsDispatcher sharedInstance] registerServiceConnectorAsConnecting:self];
        _applicationDidEnterBackground = NO;
    
        FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
        NSArray * permissions = @[@"user_photos", @"user_photo_video_tags"];
        
        [login logInWithReadPermissions:permissions handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
            if (error) {
                // Process error
                 errorBlock(error);
            } else if (result.isCancelled) {
                // Handle cancellations
                completeBlock(NO);
            } else {
                // If you ask for multiple permissions at once, you
                // should check if specific permissions missing
                if ([result.grantedPermissions containsObject:@"email"]) {
                    // Do work
                }
                dispatch_async_on_main_queue(completeBlock, YES);
            }
        }];
        
    } else  {
        
        GRKFacebookQuery * query = nil;
        query = [GRKFacebookQuery queryWithGraphPath:@"me" 
                                         withParams:nil 
                                  withHandlingBlock:^(GRKFacebookQuery *query, id result) {
        
                                      // Store the locale
                                      [GRKFacebookSingleton sharedInstance].userLocale = [result objectForKey:@"locale"];
                                      
                                      if (completeBlock != nil ){
    	                                  completeBlock(YES);
	                                  }
                                      
                                      [_queries removeObject:query];
                                      
                                  } andErrorBlock:^(NSError *error) {
                                      
                                     	// if we got an error trying to make a basic query, 
                                    	//  but as the session is supposed to be valid, 
                                      	// Then the user may have removed the application on Facebook.
                                  		
                                      // then, remove the store data about the session
                                      [GRKTokenStore removeTokenWithName:accessTokenKey forGrabberType:grabberType];
                                      [GRKTokenStore removeTokenWithName:expirationDateKey forGrabberType:grabberType];

                                      errorBlock(error);
                                      
                                      [_queries removeObject:query];
                                  
                                  }];

        [_queries addObject:query];
        [query perform];

            
        
    }
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void)disconnectWithDisconnectionIsCompleteBlock:(GRKGrabberDisconnectionIsCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
   
    [[[FBSDKLoginManager alloc] init] logOut];
    
    [self isConnected:^(BOOL connected) {
        if ( completeBlock != nil ){
            completeBlock(connected);
        }
    } errorBlock:^(NSError * error){
        if ( errorBlock != nil ){
            errorBlock(error);
        }
    }];
}

-(void) cancelAll {
    
    for ( GRKFacebookQuery * query in _queries ){
        [query cancel];
    }
    
    [_queries removeAllObjects];
    
}


/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock errorBlock:(GRKErrorBlock)errorBlock;
{
    if ( ! [FBSDKAccessToken currentAccessToken] ){
    
        dispatch_async_on_main_queue(connectedBlock, NO);
        
        return;
    }
    
    // let's test the connection. The user may have revoked the access to the application from his facebook account,
    // or may have changed his password, thus invalidating the session.
    
    
    __weak __block GRKFacebookQuery * query = nil;
    query = [GRKFacebookQuery queryWithGraphPath:@"me?fields=locale" // let's ask for a restricted set of data ...
                                      withParams:nil
                               withHandlingBlock:^(GRKFacebookQuery *query, id result) {

                                   // Store the locale
                                   [GRKFacebookSingleton sharedInstance].userLocale = [result objectForKey:@"locale"];
                                   
                                   if (connectedBlock != nil ){
                                       connectedBlock(YES);
                                   }
                                   
                                   [_queries removeObject:query];
                                   query = nil;
                                   
                               } andErrorBlock:^(NSError *error) {
                    
                                   if (connectedBlock != nil ){
                                       connectedBlock(NO);
                                   }
                                   
                                   [_queries removeObject:query];
                                   query = nil;
                                   
                               }];
    
    [_queries addObject:query];
    [query perform];

    
}

-(void) applicationDidEnterBackground {
    
    _applicationDidEnterBackground = YES;
    
}

/*  @see refer to GRKServiceConnectorProtocol documentation
 */
-(void) didNotCompleteConnection;{
   
    /*
        this method is called when the app becomes active.
        this code below needs to be performed only if the app entered background first.
        The app can "become active" without entering background first in one peculiar case :
            When de FB sdk attempts to log in from ACAccountStore, an UIAlertView is displayed 
            to ask the user if he allows to give access to his FB account.
            Whether the users allows or refuses, the [UIApplicationDelegate applicationDidBecomeActive] 
            method is called when the UIAlertView dissmisses.
     
    */

    if ( _applicationDidEnterBackground ){
    
        if (connectionIsCompleteBlock != nil ){
            dispatch_async(dispatch_get_main_queue(), ^{
                connectionIsCompleteBlock(NO);
                connectionIsCompleteBlock = nil;
            });
        
        }
    }
    
}

/*  @see refer to GRKServiceConnectorProtocol documentation
 */
-(BOOL) canHandleURL:(NSURL*)url;
{
    // in FB SDK, you need to do it in AppDelegate, don't try to do it inside GrabKit
    return NO;
    
}

/*  @see refer to GRKServiceConnectorProtocol documentation
 */
-(void) handleOpenURL:(NSURL*)url; 
{
    // don't do anything here.  do it manually in AppDelegate to handle FB SDK URL
}


@end
