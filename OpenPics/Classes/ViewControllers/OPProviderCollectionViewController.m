//
//  OPCollectionViewController.m
//  OpenPics
//
//  Created by PJ Gray on 3/22/14.
//  Copyright (c) 2014 Say Goodnight Software. All rights reserved.
//

#import "OPProviderCollectionViewController.h"
#import "OPProviderListViewController.h"
#import "OPImageCollectionViewController.h"
#import "SVProgressHUD.h"
#import "OPNavigationControllerDelegate.h"
#import "OPImageItem.h"
#import "OPContentCell.h"
#import "OPProviderController.h"
#import "OPProvider.h"
#import "OPCollectionViewDataSource.h"

@interface OPProviderCollectionViewController () <UINavigationControllerDelegate,OPProviderListDelegate,UISearchBarDelegate,OPContentCellDelegate,UICollectionViewDelegateFlowLayout> {
    UISearchBar* _searchBar;
    UIBarButtonItem* _sourceButton;
    UIToolbar* _toolbar;
    UIPopoverController* _popover;
}

@end

@implementation OPProviderCollectionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    OPCollectionViewDataSource* dataSource = (OPCollectionViewDataSource*) self.collectionView.dataSource;
    dataSource.delegate = self;

    [[OPProviderController shared] selectFirstProvider];
    OPProvider* selectedProvider = [[OPProviderController shared] getSelectedProvider];

    self.navigationController.delegate = [OPNavigationControllerDelegate shared];
        
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 1024.0f, 44.0f)];
    _searchBar.delegate = self;
    _sourceButton = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Source: %@", selectedProvider.providerShortName]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(sourceTapped)],

    self.navigationItem.titleView = _searchBar;
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        CGRect frame, remain;
        CGRectDivide(self.view.bounds, &frame, &remain, 44, CGRectMaxYEdge);
        _toolbar = [[UIToolbar alloc] initWithFrame:frame];
        [_toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
        _toolbar.items = @[
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                          _sourceButton,
                          [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]
                          ];
        [self.view addSubview:_toolbar];
    } else {
        self.navigationItem.rightBarButtonItem = _sourceButton;
    }
    
    [self doInitialSearch];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [self.view bringSubviewToFront:_toolbar];
}

#pragma mark - Loading Data Helper Functions

- (void) doInitialSearch {
    OPProvider* selectedProvider = [[OPProviderController shared] getSelectedProvider];
    
    if (selectedProvider.supportsInitialSearching) {
        [SVProgressHUD showWithStatus:@"Searching..." maskType:SVProgressHUDMaskTypeClear];

        OPCollectionViewDataSource* dataSource = (OPCollectionViewDataSource*) self.collectionView.dataSource;
        [dataSource doInitialSearchWithSuccess:^(NSArray *items, BOOL canLoadMore) {
#warning do i really need the items/canloadmore here?
            [SVProgressHUD dismiss];
            [self.collectionView scrollRectToVisible:CGRectMake(0.0, 0.0, 1, 1) animated:NO];
            [self.collectionView reloadData];
        } failure:^(NSError *error) {
            [SVProgressHUD showErrorWithStatus:@"Search failed."];
        }];
    }
}


- (void) getMoreItems {
    OPCollectionViewDataSource* dataSource = (OPCollectionViewDataSource*) self.collectionView.dataSource;
    
    [dataSource getMoreItemsWithSuccess:^(NSArray *indexPaths) {
        [SVProgressHUD dismiss];
        if (indexPaths) {
            [self.collectionView insertItemsAtIndexPaths:indexPaths];
        } else {
            [self.collectionView scrollRectToVisible:CGRectMake(0.0, 0.0, 1, 1) animated:NO];
            [self.collectionView reloadData];
        }
    } failure:^(NSError *error) {
        [SVProgressHUD showErrorWithStatus:@"Search failed."];        
    }];
}
#pragma mark - actions

- (void) sourceTapped {
    if (_popover) {
        [_popover dismissPopoverAnimated:YES];
    }
    
    UIStoryboard *storyboard = self.storyboard;
    OPProviderListViewController* providerListViewController =
    [storyboard instantiateViewControllerWithIdentifier:@"OPProviderListViewController"];
    providerListViewController.delegate = self;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self presentViewController:providerListViewController animated:YES completion:nil];
    } else {
        _popover = [[UIPopoverController alloc] initWithContentViewController:providerListViewController];
        [_popover presentPopoverFromBarButtonItem:_sourceButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    OPImageCollectionViewController* imageVC = (OPImageCollectionViewController*) segue.destinationViewController;
    imageVC.useLayoutToLayoutNavigationTransitions = YES;
}

#pragma mark OPContentCellDelegate

- (void) singleTappedCell {
    if ([self.navigationController.topViewController isKindOfClass:[OPImageCollectionViewController class]]) {
        OPImageCollectionViewController* imageVC = (OPImageCollectionViewController*) self.navigationController.topViewController;
        [imageVC toggleUIHidden];
    }
}

#pragma mark - UICollectionViewDelegate

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    OPContentCell* cell = (OPContentCell*) [collectionView cellForItemAtIndexPath:indexPath];
    [cell setupForSingleImageLayoutAnimated:YES];
}

#pragma mark - OPProviderListDelegate

- (void)tappedProvider:(OPProvider *)provider {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [_popover dismissPopoverAnimated:YES];
    }
    
    _sourceButton.title = [NSString stringWithFormat:@"Source: %@", provider.providerShortName];
    
    [[OPProviderController shared] selectProvider:provider];
    
    OPCollectionViewDataSource* dataSource = [[OPCollectionViewDataSource alloc] init];
    dataSource.delegate = self;
    self.collectionView.dataSource = dataSource;
    [self.collectionView reloadData];
    [self doInitialSearch];    
}

#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
}

#pragma mark Notifications

- (void) keyboardDidHide:(id) note {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    OPCollectionViewDataSource* dataSource = (OPCollectionViewDataSource*) self.collectionView.dataSource;
    dataSource.currentQueryString = _searchBar.text;
    [dataSource clearData];
    [self.collectionView reloadData];
    
    [SVProgressHUD showWithStatus:@"Searching..." maskType:SVProgressHUDMaskTypeClear];
    [self getMoreItems];
}

#pragma mark - DERPIN

-(void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake ) {
        [self.view endEditing:YES];
        
        NSUserDefaults *currentDefaults = [NSUserDefaults standardUserDefaults];
        NSNumber* uprezMode = [currentDefaults objectForKey:@"uprezMode"];
        if (uprezMode && uprezMode.boolValue) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"BOOM!"
                                                            message:@"Exiting full uprez mode."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [currentDefaults setObject:[NSNumber numberWithBool:NO] forKey:@"uprezMode"];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"BOOM!"
                                                            message:@"Entering full uprez mode."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [currentDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"uprezMode"];
        }
        [currentDefaults synchronize];
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    OPCollectionViewDataSource* dataSource = (OPCollectionViewDataSource*) self.collectionView.dataSource;
    
    return [dataSource collectionView:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:indexPath];
}

@end