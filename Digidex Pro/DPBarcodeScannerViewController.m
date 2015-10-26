//
//  DPBarcodeScannerViewController.m
//  Digidex Pro
//
//  Created by Avery Pierce on 8/16/15.
//  Copyright (c) 2015 Avery Pierce. All rights reserved.
//

#import "DigidexKit.h"
#import "DPBarcodeScannerViewController.h"
#import "DPDetailTableViewController.h"
#import "DPCreateCardTableViewController.h"

#import "DKManagedCard.h"


@interface DPBarcodeScannerViewController () {
    BOOL _tryingURL;
	
	
	UIView *_scannedInfoView;
	UIActivityIndicatorView *_scannedInfoActivityIndicatorView;
	UILabel *_scannedInfoLabel;
	UIImageView *_scannedInfoImageView;
	
	// This variable will be animated when the a scanned info view appears.
	// The scanned info view starts outside of the scanner preview, then jumps
	// in like toast coming out of a toaster.
	NSLayoutConstraint *_scannedInfoViewVerticalOffsetConstraint;
	
	// These variables are used to track whether or not a URL should be processed.
	NSString *_activeToken;
	NSDate *_lastScan;
	
	// These variables represent the currently loaded item, whether it's a card or a URL.
	DKManagedCard *_loadedCard;
	NSURL *_loadedAltURL;
}

@property AVCaptureDevice *device;
@property AVCaptureDeviceInput *input;
@property AVCaptureSession *session;
@property AVCaptureMetadataOutput *output;
@property AVCaptureVideoPreviewLayer *preview;

@end









@implementation DPBarcodeScannerViewController


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


// This view controller should not include a navigation bar.
// These two methods will cause the navigation bar to appear on child view controllers.
- (void)viewWillAppear:(BOOL)animated {
	[self.navigationController setNavigationBarHidden:YES animated:animated];
	[super viewWillAppear:animated];
}
- (void)viewWillDisappear:(BOOL)animated {
	[self.navigationController setNavigationBarHidden:NO animated:animated];
	[super viewWillDisappear:animated];
}

// The content of this view controller should be visisble beneath the status bar.
- (UIStatusBarStyle)preferredStatusBarStyle;
{
	return UIStatusBarStyleLightContent;
}


- (IBAction)dismiss;
{
	[self.session stopRunning];
	[self.navigationController popViewControllerAnimated:YES];
	[self dismissViewControllerAnimated:YES completion:^{
	}];
}







#pragma mark - Initialization

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tryingURL = NO;
	_lastScan = [NSDate distantPast];
	
#if TARGET_IPHONE_SIMULATOR
	[self.debugItemButton setHidden:NO];
	[self.debugItemButton setEnabled:YES];
#endif
	
//    [self setupScanner];
	
	self.edgesForExtendedLayout = UIRectEdgeNone;
	
	
	
	AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
	switch (authStatus) {
		case AVAuthorizationStatusAuthorized:
			// Immediately start the scanner
			[self setupScanner];
			break;
		case AVAuthorizationStatusDenied:
			// TODO: Indicate that the user has denied access
			break;
		case AVAuthorizationStatusRestricted:
			// TODO: Indicate that the camera access is restricted
			break;
		case AVAuthorizationStatusNotDetermined:
			// TODO: Instruct the user to tap the ask permission
			break;
		default:
			break;
	}
}








#pragma mark - Camera Setup

- (IBAction)activateScanner:(id)sender {
	
	if ([self setupScanner]) {
		
		
		self.backButton.enabled = NO;
		self.preview.opacity = 0.0;
		
		// Animate the scanner into the full screen
		[UIView animateWithDuration:0.4 animations:^{
			
			self.preview.frame = self.scannerView.bounds;
			self.preview.opacity = 1.0;
			
			// Fade out the auxillery controls
			self.backButton.alpha = 0.0;
			self.tapToScanLabel.alpha = 0.0;

			
		} completion:^(BOOL finished) {
			
		}];
	}
}

- (IBAction)deactivateScanner:(id)sender;
{
	[self.session stopRunning];
	
	
	// Animate the scanner out of full screen
	[UIView animateWithDuration:0.4 animations:^{
		
		// Fade out the auxillery controls
		self.backButton.alpha = 1.0;
		self.tapToScanLabel.alpha = 1.0;
		self.preview.opacity = 0.0;
		

		// If there is any scanned info, get it off the screen.
		if (_scannedInfoViewVerticalOffsetConstraint != nil) {
			_scannedInfoViewVerticalOffsetConstraint.constant = -50;
		}
		
		[self.view layoutIfNeeded];
		
	} completion:^(BOOL finished) {
		
		self.backButton.enabled = YES;
		
		if (_scannedInfoView != nil) {
			[_scannedInfoView removeFromSuperview];
			_scannedInfoView = nil;
			_scannedInfoViewVerticalOffsetConstraint = nil;
		}
		
		
		
		[self.preview removeFromSuperlayer];
		
	}];
}

- (BOOL)setupScanner;
{
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
	
	// If there is no input device, then we fail.
	if (!self.input) {
		return NO;
	}
	
    self.session = [[AVCaptureSession alloc] init];
    
    self.output = [[AVCaptureMetadataOutput alloc] init];
    [self.session addOutput:self.output];
    [self.session addInput:self.input];
    
    [self.output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    self.output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.preview.frame = self.scannerView.bounds;
    
    AVCaptureConnection *con = self.preview.connection;
    con.videoOrientation = [self videoOrientationForCurrentDeviceOrientation];
    
    [self.scannerView.layer insertSublayer:self.preview atIndex:0];
    self.scannerView.layer.masksToBounds = YES;
    
    [self.session startRunning];
	return YES;
	
}

// When the user interface rotates, be sure to update the orientation of the preview.
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;
{
	if (self.preview && self.preview.connection)
		self.preview.connection.videoOrientation = [self videoOrientationForCurrentDeviceOrientation];
}

- (AVCaptureVideoOrientation)videoOrientationForCurrentDeviceOrientation;
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    AVCaptureVideoOrientation videoOrientation;
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeLeft:
            videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
    }
	
    return videoOrientation;
}









#pragma mark - User Inputs

// This method is called when the camera detects a QR code.
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection;
{
	// If the last scan was less than 3 seconds ago, ignore this data.
	if ([[NSDate date] timeIntervalSinceDate:_lastScan] < 3)
		return;
	
	NSLog(@"metadataObjectsL %@", metadataObjects);
	for (AVMetadataMachineReadableCodeObject *metadataObject in metadataObjects) {
		
		// Capture the URL
		NSURL *url = [NSURL URLWithString:metadataObject.stringValue];
		if (url != nil) {
			
			// Set the last scan to now.
			_lastScan = [NSDate date];
			[self captureURL:url];
		}
	}
}


// This is called from the text field
- (IBAction)submitURL:(id)sender {
	
	// Get the URL from the text field, and load it.
	NSURL *enteredURL = [NSURL URLWithString:self.URLTextField.text];
    [self processURL:enteredURL token:[self generateToken]];
}







#pragma mark - URL Processing

- (void)captureURL:(NSURL*)url;
{
	if (_scannedInfoView != nil) {
		[_scannedInfoView removeFromSuperview];
		_scannedInfoView = nil;
	}
	
	// Display a view that shows a progress spinner and the scanned URL
	_scannedInfoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
	_scannedInfoView.translatesAutoresizingMaskIntoConstraints = NO;
	_scannedInfoView.backgroundColor = [UIColor whiteColor];
	_scannedInfoView.layer.cornerRadius = 6;
	
	_scannedInfoView.layer.masksToBounds = NO;
	_scannedInfoView.layer.shadowOffset = CGSizeMake(0, -1.0);
	_scannedInfoView.layer.shadowRadius = 2.0;
	_scannedInfoView.layer.shadowOpacity = 0.1;
	
	[self.scannerView addSubview:_scannedInfoView];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_scannedInfoView]-|" options:kNilOptions metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoView)]];
	
	NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_scannedInfoView(==44)]-(-50)-|" options:kNilOptions metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoView)];
	for (NSLayoutConstraint *verticalConstraint in verticalConstraints) {
		// The vertical positioning constraint is -50. If this constraint has a constant of -50, then this is the offset constraint.
		if (verticalConstraint.constant == -50) {
			_scannedInfoViewVerticalOffsetConstraint = verticalConstraint;
			break;
		}
	}
	[self.view addConstraints:verticalConstraints];
	
	
	
	// Add a progress indicator to the scanned view...
	_scannedInfoActivityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	_scannedInfoActivityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
	[_scannedInfoView addSubview:_scannedInfoActivityIndicatorView];
	

	_scannedInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
	_scannedInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
	_scannedInfoLabel.text = [url absoluteString];
	_scannedInfoLabel.font = [UIFont systemFontOfSize:14];
	_scannedInfoLabel.textAlignment = NSTextAlignmentLeft;
	_scannedInfoLabel.textColor = [UIColor grayColor];
	[_scannedInfoView addSubview:_scannedInfoLabel];
	
	
	_scannedInfoImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
	_scannedInfoImageView.translatesAutoresizingMaskIntoConstraints = NO;
	_scannedInfoImageView.contentMode = UIViewContentModeScaleAspectFit;
	[_scannedInfoView addSubview:_scannedInfoImageView];
	
	
	[_scannedInfoView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(12)-[_scannedInfoActivityIndicatorView]-(8)-[_scannedInfoLabel]-(>=8)-|" options:kNilOptions metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoActivityIndicatorView, _scannedInfoLabel)]];
	[_scannedInfoView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(12)-[_scannedInfoImageView(22)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoImageView)]];
	[_scannedInfoView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_scannedInfoActivityIndicatorView]-|" options:kNilOptions metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoActivityIndicatorView)]];
	[_scannedInfoView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_scannedInfoLabel]-|" options:kNilOptions metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoLabel)]];
	[_scannedInfoView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_scannedInfoImageView]-|" options:kNilOptions metrics:nil views:NSDictionaryOfVariableBindings(_scannedInfoImageView)]];
	[_scannedInfoActivityIndicatorView startAnimating];
	[_scannedInfoActivityIndicatorView setHidesWhenStopped:YES];
	
	
	[self.view layoutIfNeeded];
	
	
	// If the info view is tapped, launch the respective view
	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(infoViewTapped:)];
	[_scannedInfoView addGestureRecognizer:tapGestureRecognizer];
	
	
	
	[UIView animateWithDuration:0.8 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:0.1 options:kNilOptions animations:^{
		if (_scannedInfoViewVerticalOffsetConstraint != nil) {
			_scannedInfoViewVerticalOffsetConstraint.constant = 16;
			[self.view layoutIfNeeded];
		}
	} completion:^(BOOL finished) {
		
	}];
	
	[self processURL:url token:[self generateToken]];
}

// This utility function will generate a random string.
// This random string is used to uniquely identify
- (NSString*)generateToken;
{
	NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	NSMutableString *randomString = [NSMutableString stringWithCapacity: 10];
	
	for (int i=0; i<10; i++) {
		[randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((uint)[letters length])]];
	}
	
	return randomString;
}

- (void)processURL:(NSURL*)url token:(NSString*)token;
{
	// Capture the provided token here.
	// If the user tries to scan a new address, this will be overwritten, and we will know to ignore the old notifications.
	_activeToken = token;
	
	_loadedCard = nil;
	_loadedAltURL = nil;
	
	[DKManagedCard determineDigidexURLFromProvidedURL:url completion:^(NSURL *determinedURL) {
		
		// If the user attempted to load something else, ignore this data.
		if (![_activeToken isEqualToString:token])
			return;
		
		[_scannedInfoActivityIndicatorView stopAnimating];
		
		[_scannedInfoLabel setTextAlignment:NSTextAlignmentCenter];
		[_scannedInfoLabel setTextColor:self.view.tintColor];
		[_scannedInfoLabel setFont:[UIFont systemFontOfSize:16]];
		
		if (determinedURL != nil) {
			
			_loadedCard = [[DKDataStore sharedDataStore] makeTransientContactWithURL:determinedURL];
			
			[_scannedInfoLabel setText:[determinedURL absoluteString]];
			
			[_scannedInfoImageView setImage:[UIImage imageNamed:@"digidex-card-outline"]];
			[_scannedInfoImageView setTintColor:self.view.tintColor];
			
			
			// When the contact is loaded, update the name.
			[[NSNotificationCenter defaultCenter] addObserverForName:@"ContactLoaded" object:_loadedCard queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
				
				// If the user attempted to load something else, ignore this data.
				if (![_activeToken isEqualToString:token])
					return;
				
				[_scannedInfoLabel setText:[_loadedCard guessedName]];
			}];
		} else {
			
			_loadedAltURL = url;
			[_scannedInfoLabel setText:[url absoluteString]];
			
			[_scannedInfoImageView setImage:[UIImage imageNamed:@"safari-outline"]];
			[_scannedInfoImageView setTintColor:self.view.tintColor];
		
		}
		
	}];
}

- (void)infoViewTapped:(UIGestureRecognizer*)gestureRecognizer;
{
	if (_loadedCard) {
		
		DPDetailTableViewController *detailViewController = [[UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil] instantiateViewControllerWithIdentifier:@"DetailViewController"];
		detailViewController.selectedCard = _loadedCard;
		detailViewController.title = @"New Card";
		
		UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
		
		[self presentViewController:navigationController animated:YES completion:^{
		}];
	} else if (_loadedAltURL) {
		[[UIApplication sharedApplication] openURL:_loadedAltURL];
	}
}













#pragma mark - Contact import methods

- (IBAction)importFromContacts:(id)sender
{
	ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
	peoplePicker.peoplePickerDelegate = self;
	[self presentViewController:peoplePicker animated:YES completion:^{
		
	}];
}

- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person;
{
	
	// Capture this metadata from the contact
	NSString *name = (__bridge NSString*)ABRecordCopyCompositeName(person);
	
	
	
	NSArray *singleStringKeys =	@[@{@"organization":	@(kABPersonOrganizationProperty)},
								  @{@"job title":		@(kABPersonJobTitleProperty)},
								  @{@"department":		@(kABPersonDepartmentProperty)}];
	
	NSArray *multiStringKeys =	@[@{@"URL":				@(kABPersonURLProperty)},
								  @{@"email":			@(kABPersonEmailProperty)},
								  @{@"phone":			@(kABPersonPhoneProperty)}];
	
	
	
	NSMutableArray *keyValuePairs = [@[@{@"key":@"name", @"value": name}] mutableCopy];
	
	
	for (NSDictionary *keyValuePair in singleStringKeys) {
		
		NSString *key = keyValuePair.allKeys[0];
		NSString *stringValue = (__bridge NSString *)(ABRecordCopyValue(person, [keyValuePair[key] intValue]));
		
		if (stringValue && [stringValue length] > 0)
			[keyValuePairs addObject:@{@"key":key, @"value":stringValue}];
		
	}
	
	for (NSDictionary *keyValuePair in multiStringKeys) {
		
		NSString *key = keyValuePair.allKeys[0];
		ABMultiValueRef multiValue = ABRecordCopyValue(person, [keyValuePair[key] intValue]);
		long count = ABMultiValueGetCount(multiValue);
		for (int i = 0; i < count; i++) {
			
			CFStringRef label = ABMultiValueCopyLabelAtIndex(multiValue, i);
			NSString *localizedLabel = (__bridge NSString *)(ABAddressBookCopyLocalizedLabel(label));
			
			NSString *value = (__bridge NSString *)ABMultiValueCopyValueAtIndex(multiValue, i);
			
			if (value && [value length] > 0) {
				[keyValuePairs addObject:@{@"key":[NSString stringWithFormat:@"%@ %@", localizedLabel, key], @"value":value, @"type":key}];
			}
		}
	}
	
	
	// Address is a special case...
	ABMultiValueRef addresses = ABRecordCopyValue(person, kABPersonAddressProperty);
	long addressCount = ABMultiValueGetCount(addresses);
	for (int i = 0; i < addressCount; i++) {
		
		CFStringRef label = ABMultiValueCopyLabelAtIndex(addresses, i);
		NSString *localizedLabel = (__bridge NSString*)ABAddressBookCopyLocalizedLabel(label);
		
		CFDictionaryRef address = ABMultiValueCopyValueAtIndex(addresses, i);
		
		NSString *street =	CFDictionaryGetValue(address, kABPersonAddressStreetKey);
		NSString *city =	CFDictionaryGetValue(address, kABPersonAddressCityKey);
		NSString *state =	CFDictionaryGetValue(address, kABPersonAddressStateKey);
		NSString *zip =		CFDictionaryGetValue(address, kABPersonAddressZIPKey);
		NSString *country = CFDictionaryGetValue(address, kABPersonAddressCountryKey);
		
		NSString *addressString = [NSString stringWithFormat:@"%@\n%@, %@ %@\n%@", street, city, state, zip, country];
		
		[keyValuePairs addObject:@{@"key": [NSString stringWithFormat:@"%@ %@", localizedLabel, @"address"], @"value": addressString}];
	}
	
	
	
	UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone"
															 bundle: nil];
	
	DPCreateCardTableViewController *controller = (DPCreateCardTableViewController*)[mainStoryboard instantiateViewControllerWithIdentifier: @"CreateCardTableViewController"];
	controller.initialKeyValuePairs = [keyValuePairs copy];
	
	[self.navigationController pushViewController:controller animated:YES];
}







#pragma mark - Debug Methods

// This method spoofs a captured URL
-(IBAction)debugCaptureURL:(id)sender;
{
	NSURL *bogusURL;
	if (arc4random() % 2 == 0)
		bogusURL = [DPBarcodeScannerViewController bogusURL];
	else
		bogusURL = [NSURL URLWithString:@"http://digidex.org/"];
	
	[self captureURL:bogusURL];
}

- (IBAction)createBogusCard:(id)sender {
	
	NSURL *bogusURL = [DPBarcodeScannerViewController bogusURL];
	[self processURL:bogusURL token:[self generateToken]];
}

+ (NSURL*)bogusURL;
{
	NSArray *bogusURLs = @[@"http://bloviations.net/contact/cardData0.json",
						   @"http://bloviations.net/contact/cardData1.json",
						   @"http://bloviations.net/contact/cardData2.json",
						   @"http://bloviations.net/contact/cardData3.json",
						   @"http://bloviations.net/contact/soulful_sparrow.json",
						   @"http://bloviations.net/contact/elgin_history_museum.json"];
	
	NSURL *bogusURL = [NSURL URLWithString:[bogusURLs objectAtIndex:(arc4random() % bogusURLs.count)]];
	return bogusURL;
}


@end
