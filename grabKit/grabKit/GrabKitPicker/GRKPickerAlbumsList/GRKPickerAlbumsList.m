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

#import "GRKPickerViewController.h"
#import "GRKPickerViewController+privateMethods.h"
#import "GRKPickerAlbumsList.h"
#import "GRKServiceGrabberConnectionProtocol.h"
#import "GRKPickerPhotosList.h"
#import "GRKPickerAlbumsListCell.h"

#import "MBProgressHUD.h"

#import "GRKServiceGrabber+usernameAndProfilePicture.h"
#import "GRKDeviceGrabber.h"

#import <FacebookSDK/FacebookSDK.h>

#import "AsyncURLConnection.h"



static NSString *loadMoreCellIdentifier = @"loadMoreCell";

@interface GRKPickerAlbumsList()
    -(void)loadMoreAlbums;
    -(void)setState:(GRKPickerAlbumsListState)newState;
@end


NSUInteger kNumberOfAlbumsPerPage = 8;
NSUInteger kMaximumRetriesCount = 1;

@implementation GRKPickerAlbumsList

@synthesize tableView = _tableView;
@synthesize serviceName = _serviceName;

-(void) dealloc {
    
    for( GRKAlbum * album in _albums ){
        [album removeObserver:self forKeyPath:@"count"];
    }

}


-(id) initWithGrabber:(id)grabber andServiceName:(NSString *)serviceName {
    
    
    self = [super initWithNibName:@"GRKPickerAlbumsList" bundle:GRK_BUNDLE];
    if ( self ){
        _grabber = grabber;
        _serviceName = serviceName;
        _albums = [[NSMutableArray alloc] init];
        _lastLoadedPageIndex = 0;
        [self setState:GRKPickerAlbumsListStateInitial];
    }
    
    
    return self;
}

/*
 
 This state design-pattern must be used to update UI only.
 
 */
-(void) setState:(GRKPickerAlbumsListState)newState {
    
    
    state = newState;
    
    switch (newState) {
            
        case GRKPickerAlbumsListStateConnecting:
        {
            
            _needToConnectView.hidden = YES;
            
            INCREASE_OPERATIONS_COUNT
        }
            break;
           
            
        case GRKPickerAlbumsListStateNeedToConnect:
        {
            
            DECREASE_OPERATIONS_COUNT
            
            _needToConnectView.alpha = 0;
            _needToConnectView.hidden = NO;

            NSString * needToConnectString = GRK_i18n(@"GRK_ALBUMS_LIST_NEED_TO_CONNECT", @"You need to connect to %serviceName%");
            _needToConnectLabel.text = [needToConnectString stringByReplacingOccurrencesOfString:@"%serviceName%" withString:_grabber.serviceName];

            [_connectButton setTitle:GRK_i18n(@"GRK_ALBUMS_LIST_CONNECT_BUTTON",@"Login") forState:UIControlStateNormal];
            
            [UIView animateWithDuration:0.33 animations:^{

                _needToConnectView.alpha = 1;
                
            }];
            
            
        }
            break;
            
        case GRKPickerAlbumsListStateConnected:
        {
            DECREASE_OPERATIONS_COUNT
            
            if ( ! [_grabber isKindOfClass:[GRKDeviceGrabber class]]) {
                [self buildHeaderView];
            }
        }
            break;
            
            
        case GRKPickerAlbumsListStateDidNotConnect:
        {
            DECREASE_OPERATIONS_COUNT
            
            [self.navigationController popViewControllerAnimated:YES];
            
        }
            break;

        case GRKPickerAlbumsListStateConnectionFailed:
        {
            
            DECREASE_OPERATIONS_COUNT
            
            _needToConnectView.alpha = 0;
            _needToConnectView.hidden = NO;
            
            _needToConnectLabel.text = GRK_i18n(@"GRK_ALBUMS_LIST_ERROR_RETRY", @"An error occured. Please try again.");
            
            [UIView animateWithDuration:0.33 animations:^{
                
                _needToConnectView.alpha = 1;
                
            }];
            
            
        }
            break;
            
            
            
            
        case GRKPickerAlbumsListStateGrabbing:
        {
            INCREASE_OPERATIONS_COUNT
            
        }
            
            break;

            
        // When some albums are grabbed, reload the tableView    
        case GRKPickerAlbumsListStateAlbumsGrabbed:
        case GRKPickerAlbumsListStateAllAlbumsGrabbed:    
        {
            DECREASE_OPERATIONS_COUNT
            
            // If that's the first grab, then the tableView has not been added to the view yet.
            if ( self.tableView.hidden  ){
                
                //First Let's make the table view invisible
                self.tableView.alpha = 0;
                self.tableView.hidden = NO;
                
                // And animate the have a nice transition between the HUD and the tableView
                [UIView animateWithDuration:0.33 animations:^{
                    
                    self.tableView.alpha = 1;
                    
                }];
            }

            [self.tableView reloadData];
            
            
        }
            break;
        
        case GRKPickerAlbumsListStateGrabbingFailed:
        {
            DECREASE_OPERATIONS_COUNT
            
            NSIndexPath * loadMoreCellIndexPath = [NSIndexPath indexPathForRow:[_albums count] inSection:0];
            [self.tableView reloadRowsAtIndexPaths:@[loadMoreCellIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
            break;
            
        case GRKPickerAlbumsListStateDisconnecting:
        {
            INCREASE_OPERATIONS_COUNT
            
        }
            break;
            
            
        case GRKPickerAlbumsListStateDisconnected:
        {
             DECREASE_OPERATIONS_COUNT
            
             [self.navigationController popToRootViewControllerAnimated:YES];
         
        }
            break;
            
            
        case GRKPickerAlbumsListStateError:
        {
            DECREASE_OPERATIONS_COUNT
            
        }
            break;
            
        default:
            break;
    }
    
    
}

-(void) buildHeaderView {
    
    _headerView = [[GRK_BUNDLE loadNibNamed:@"GRKPickerCurrentUserView" owner:nil options:nil] objectAtIndex:0];
    _headerView.delegate = self;
    _headerView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, 50);
    self.tableView.tableHeaderView = _headerView;
    

        
    INCREASE_OPERATIONS_COUNT // increase, for the call on the grabber
    
    // Call this category method to load specific data about the logged user : username and profile picture
    [_grabber loadUsernameAndProfilePictureOfCurrentUserWithCompleteBlock:^(id result) {
        
        DECREASE_OPERATIONS_COUNT // decrease, for the call on the grabber
        
        // The result is a NSDictionary containing 2 objects ...
        NSString * username = [result objectForKey:kGRKUsernameKey];
        NSString * profilePictureURLstring = [result objectForKey:kGRKProfilePictureKey];
        
        
        // download the profile picture asynchronously
        __block AsyncURLConnection * urlConnection =
        [AsyncURLConnection connectionWithString:profilePictureURLstring
                                   responseBlock:nil
                                   progressBlock:nil
                                   completeBlock:^(NSData *data) {
                                       
                                       DECREASE_OPERATIONS_COUNT // decrease, for the AsyncURLConnection call
                                       
                                       // build an image with the data
                                       UIImage * profilePicture = [UIImage imageWithData:data];
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           // update the imageview on the main thread
                                           [_headerView showWithUsername:username andProfilePictureImage:profilePicture];
                                       });
                                       
                                       urlConnection = nil;
                                       
                                   } errorBlock:^(NSError *error) {
                                       
                                       DECREASE_OPERATIONS_COUNT // decrease, for the AsyncURLConnection call
                                       
                                       // Here, we can update the imageview with a default image for failed downloads
                                       
                                       urlConnection = nil;
                                       
                                   }];
        
        INCREASE_OPERATIONS_COUNT // increase, for the AsyncURLConnection call
        [urlConnection start];
        
        
    } andErrorBlock:^(NSError *error) {
        
        DECREASE_OPERATIONS_COUNT
        NSLog(@" error in load data for service header : %@ ", error);
        
    }];
    
    
    
}


#pragma mark GRKPickerCurrentUserViewDelegate methods

-(void) headerViewDidTouchLogoutButton:(id)headerView {
    
    
    [self setState:GRKPickerAlbumsListStateDisconnecting];
    
    // First, cancel all the running queries
    [_grabber cancelAllWithCompleteBlock:^(NSArray *results) {
        
            [(GRKServiceGrabber<GRKServiceGrabberConnectionProtocol> *)_grabber disconnectWithDisconnectionIsCompleteBlock:^(BOOL disconnected) {
            
            [self setState:GRKPickerAlbumsListStateDisconnected];
            
        } andErrorBlock:^(NSError *error) {
            
            NSLog(@" An error occured trying to disconnect the grabber %@", _grabber);
            NSLog(@" error : %@", error);
           
            // set to disconnected anyway, to fail silently
            [self setState:GRKPickerAlbumsListStateDisconnected];

            
        }];
        
    }];

    
}


-(void) didTouchCancelButton {
    
    [[GRKPickerViewController sharedInstance] dismiss];
    
}

-(IBAction)didTouchConnectButton {
    
    
    [self setState:GRKPickerAlbumsListStateConnecting];
    
    [(id<GRKServiceGrabberConnectionProtocol>)_grabber connectWithConnectionIsCompleteBlock:^(BOOL connected) {
    
        if ( connected ) {
            
            [self setState:GRKPickerAlbumsListStateConnected];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self loadMoreAlbums];
                
            });
            
        } else {
            
            [self setState:GRKPickerAlbumsListStateDidNotConnect];
            
        }
        
    } andErrorBlock:^(NSError *error) {
        
        [self setState:GRKPickerAlbumsListStateConnectionFailed];
        NSLog(@" an error occured trying to connect the grabber : %@", error);
        
        
    }];

    
    
}



- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
 
    self.tableView.rowHeight = 80.0;
 
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.title = _serviceName;
    
    if ( state != GRKPickerAlbumsListStateInitial )
        return;
    
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didTouchCancelButton)];
    
    
    [self setState:GRKPickerAlbumsListStateConnecting];

    
    // If the grabber needs to connect
    if ( _grabber.requiresConnection ){
        
        
        [(id<GRKServiceGrabberConnectionProtocol>)_grabber isConnected:^(BOOL connected) {
            
            if ( ! connected ){
                [self setState:GRKPickerAlbumsListStateNeedToConnect];
            
            } else {

                dispatch_async(dispatch_get_main_queue(), ^(void){

                    [self setState:GRKPickerAlbumsListStateConnected];
                    // start grabbing albums
                    [self loadMoreAlbums];   

                });

            }
            
        } errorBlock:^(NSError *error) {
            
            NSLog(@" an error occured trying to check if the grabber is connected : %@", error);
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                [self setState:GRKPickerAlbumsListStateConnectionFailed];
            
            });
            
        }];
                
    } else {
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            
            [self setState:GRKPickerAlbumsListStateConnected];
            // start grabbing albums ( we don't need to add the "log out" button, as the grabber doesn't need to connect ...)
            [self loadMoreAlbums];   
            
        });

    }
    

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [_grabber cancelAll];

    // Reset the operations count.
    // If the view disappears while something is (i.e. after a INCREASE_OPERATIONS_COUNT),
    //  the corresponding DECREASE_OPERATIONS_COUNT is not called, and the activity indicator remains spinning...
    RESET_OPERATIONS_COUNT
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return ( interfaceOrientation == UIInterfaceOrientationPortrait || UIInterfaceOrientationIsLandscape(interfaceOrientation) );
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    /* If the navigation bar is not translucent, then we don't need to animate anything during rotation
    If you don't understand why :
    _ comment the test below
    _ go to GRKPickerViewController.m 
    _ set the navigationBar.translucent to NO,
    _ Build and run the Demo app, select a service, and wait for the albums list to load
    _ Now, rotate from portrait to landscape, and scroll ...
    */
    if ( [[GRKPickerViewController sharedInstance] isPresentedInPopover] || ! self.navigationController.navigationBar.translucent ){
        return;
    }
    
    /* In order to have a beautiful rotation effect, we want :
        _ That the space reserved for the header view fits the header view ( i.e. update the tableView's contentInset to the navigationBar's height )
        _ If the tableView is scrolled at the top BEFORE the rotation begins, we want it to still be scrolled at the top AFTER the rotation.

    */
    
    CGFloat top; // The top value of the content inset
    BOOL shouldScrollToTop = NO;
    
    CGFloat navigationBarHeightLandscape = 32;
    CGFloat navigationBarHeightPortrait = 44;
    
    // If we are rotating to Landscape ...
    if (  UIInterfaceOrientationIsLandscape(toInterfaceOrientation)   ){
        top = navigationBarHeightLandscape;
        shouldScrollToTop = ( self.tableView.contentOffset.y ==  - navigationBarHeightPortrait );
        
    } else {
        top = navigationBarHeightPortrait;
        shouldScrollToTop = ( self.tableView.contentOffset.y ==  - navigationBarHeightLandscape );
        
    }
    
    [UIView animateWithDuration:duration animations:^{
        
        self.tableView.contentInset = UIEdgeInsetsMake(top, 0, 0, 0);
        if ( shouldScrollToTop ){
            self.tableView.contentOffset = CGPointMake(0, - top);
        }
        
    }];
    
    
}


-(void) prepareCell:(GRKPickerAlbumsListCell *)cell fromTableView:(UITableView*)tableView atIndexPath:(NSIndexPath*)indexPath withAlbum:(GRKAlbum*)album  {
    
    // This just sets the album name and the photos count.
    [cell setAlbum:album];
    
    
    if ( album.coverPhoto == nil && [album.coverPhoto.images count] == 0 )
        return;
    
    
    NSURL * thumbnailURL = nil;
    
    // Pick a GRKImage of the cover photo that fits the thumbnail.
    // The imageView for thumbnails is 75px wide, so we need images with both dimensions greater or equal to 2*75px, for a perfect result on retina displays
    NSUInteger minWidth = cell.thumbnail.frame.size.width * 2;
    NSUInteger minHeight = cell.thumbnail.frame.size.height * 2;
    
    NSArray * imagesSortedByHeight = [album.coverPhoto imagesSortedByHeight];
    for( GRKImage * image in imagesSortedByHeight ){
        
        if ( image.width >= minWidth && image.height >= minHeight ) {
            
            thumbnailURL = image.URL;
            // Once we have found the first thumbnail bigger than the thumbnail, break the loop
            break;
        }
    }
    
    // At this point, if the thumbnail is nil, it means the photo doesn't have an image bigger than 150x150 px
    // Then, take the biggest image of the photo instead.
    if ( thumbnailURL == nil ){
        thumbnailURL = ((GRKImage*)[imagesSortedByHeight lastObject]).URL;
    }
     
    [cell updateThumbnailImage:thumbnailURL];
}



#pragma mark - Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{

    return _albums.count + 1;
        
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = nil;
    
    // Handle the extra cell
    if ( indexPath.row >= [_albums count] ){
    
        cell = [tableView dequeueReusableCellWithIdentifier:loadMoreCellIdentifier];
        if (cell == nil) {
            cell = [[GRK_BUNDLE loadNibNamed:@"GRKPickerLoadMoreCell" owner:nil options:nil] objectAtIndex:0];
        }

        switch (state) {
            case GRKPickerAlbumsListStateGrabbingFailed:
                [(GRKPickerLoadMoreCell*)cell setToRetry];
                break;
            case GRKPickerAlbumsListStateAlbumsGrabbed:
                [(GRKPickerLoadMoreCell*)cell setToLoading];
                [self loadMoreAlbums];
                break;
            case GRKPickerAlbumsListStateAllAlbumsGrabbed:
                [(GRKPickerLoadMoreCell*)cell setToAllLoaded];
                break;
        }
        
    } else {
        
        static NSString *CellIdentifier = @"AlbumCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            
            cell = [[GRK_BUNDLE loadNibNamed:@"GRKPickerAlbumsListCell" owner:nil options:nil] objectAtIndex:0];
        }
        
        GRKAlbum * albumAtIndexPath = (GRKAlbum*)[_albums objectAtIndex:indexPath.row];

        [self prepareCell:(GRKPickerAlbumsListCell*)cell fromTableView:tableView atIndexPath:indexPath withAlbum:albumAtIndexPath];
        
        if ( albumAtIndexPath.count > 0 ){
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if ( indexPath.row <= [_albums count] -1 ) {
        
        GRKAlbum * albumAtIndexPath = [_albums objectAtIndex:indexPath.row];
        
        if ( albumAtIndexPath.count  > 0 ){
        
            GRKPickerPhotosList * photosList = [[GRKPickerPhotosList alloc] initWithNibName:@"GRKPickerPhotosList" bundle:GRK_BUNDLE andGrabber:_grabber andAlbum:albumAtIndexPath];
            [self.navigationController pushViewController:photosList animated:YES];
        }
        
    } else {
        UITableViewCell * loadMoreCell = [tableView cellForRowAtIndexPath:indexPath];
        
        if ( [loadMoreCell isKindOfClass:[GRKPickerLoadMoreCell class]] ){
            [(GRKPickerLoadMoreCell*)loadMoreCell setToLoading];
            
            [self loadMoreAlbums];
        }
    }
}


#pragma mark - 


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    
    if ( [keyPath isEqualToString:@"count"] ){
        
        NSInteger indexOfAlbum = [_albums indexOfObject:object];

        if ( indexOfAlbum != NSNotFound ){
            
            NSArray * indexPathsToReload = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:indexOfAlbum inSection:0]];
            [self.tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];    
        }
        
    }
    
}

-(void) loadCoverPhotoForAlbums:(NSArray*)albums {
    
    // First, filter to retreive only the albums without cover
    NSMutableArray * albumsWithoutCover = [NSMutableArray array];
    for( GRKAlbum * album in albums ){
        if ( album.coverPhoto == nil ){
            [albumsWithoutCover addObject:album];
        }
    }

    
    INCREASE_OPERATIONS_COUNT
    
    // Fill these albums with their cover photo
    [_grabber fillCoverPhotoOfAlbums:albumsWithoutCover withCompleteBlock:^(id result) {

        
        DECREASE_OPERATIONS_COUNT
        
        if ( state == GRKPickerAlbumsListStateGrabbing ){
            
            // Do no reload rows during a grab of data. 2 reloads on the tableView could generate a crash
            return;
        }
            
        
        // for each album filled, find its index in the _albums array, and build an NSIndexPath to reload the tableView
        
        NSMutableArray * indexPathsToReload = [NSMutableArray array];
        
        for( GRKAlbum * a in result ) {
            
            NSUInteger indexOfFilledAlbum = [_albums indexOfObject:a];
            if ( indexOfFilledAlbum != NSNotFound ){
                [indexPathsToReload addObject:[NSIndexPath indexPathForRow:indexOfFilledAlbum inSection:0]];
                
            }
            
        }
        
        [self.tableView reloadRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationNone];
        
        
    } andErrorBlock:^(NSError *error) {
        
        // Do nothing, fail silently.
        DECREASE_OPERATIONS_COUNT
        
    }];
    
    
}


-(void) loadMoreAlbums {

    if ( state == GRKPickerAlbumsListStateGrabbing)
        return;
    
    
    [self loadAlbumsAtPageIndex:_lastLoadedPageIndex withNumberOfAlbumsPerPage:kNumberOfAlbumsPerPage andNumberOfAllowedRetries:kMaximumRetriesCount];
    
}

-(void) loadAlbumsAtPageIndex:(NSUInteger)pageIndex withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage andNumberOfAllowedRetries:(NSUInteger)allowedRetriesCount {
    
    if ( state != GRKPickerAlbumsListStateGrabbing)
        [self setState:GRKPickerAlbumsListStateGrabbing];
    
    [_grabber
     albumsOfCurrentUserAtPageIndex:pageIndex
     withNumberOfAlbumsPerPage:numberOfAlbumsPerPage
     andCompleteBlock:^(NSArray *results) {
         
         _lastLoadedPageIndex+=1;
         [_albums addObjectsFromArray:results];
         
         for( GRKAlbum * newAlbum in results ){
             
             [newAlbum addObserver:self forKeyPath:@"count" options:NSKeyValueObservingOptionNew context:nil];
             
         }
         
         dispatch_async(dispatch_get_main_queue(), ^{
             [self loadCoverPhotoForAlbums:results];
         });
         
         
         // Update the state. the tableView is reloaded in this method.
         if ( [results count] < kNumberOfAlbumsPerPage ){
             [self setState:GRKPickerAlbumsListStateAllAlbumsGrabbed];
         } else {
             [self setState:GRKPickerAlbumsListStateAlbumsGrabbed];
             
         }
         
         
     } andErrorBlock:^(NSError *error) {
         
         NSLog(@" error ! %@", error);
         
         if ( allowedRetriesCount > 0 ){
             
             [self loadAlbumsAtPageIndex:pageIndex withNumberOfAlbumsPerPage:numberOfAlbumsPerPage andNumberOfAllowedRetries:allowedRetriesCount-1];
             
             return;
             
         } else {
             
             [self setState:GRKPickerAlbumsListStateGrabbingFailed];
             
         }
         
     }];
}



@end
