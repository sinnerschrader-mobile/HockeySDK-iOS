/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

#import "BITAuthenticationViewController.h"
#import "BITAuthenticator_Private.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

@interface BITAuthenticationViewController ()<UITextFieldDelegate>
@property (nonatomic, strong) UITextField *emailTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UIButton *signInButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, copy) NSString *password;

@end

@implementation BITAuthenticationViewController

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
  }
  return self;
}

#pragma mark - view lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupView];
  [self setupConstraints];
  [self blockMenuButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [self updateBarButtons];
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

#pragma mark - Property overrides
- (void) updateBarButtons {
  if(self.showsLoginViaWebButton) {
    self.navigationItem.rightBarButtonItem = nil;
  } else {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(saveAction:)];
  }
}

- (void) blockMenuButton {
  UITapGestureRecognizer *tapGestureRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(signInButtonTapped:)];
  tapGestureRec.allowedPressTypes = @[@(UIPressTypeMenu)];
  [self.view addGestureRecognizer:tapGestureRec];
}

- (void) signInButtonTapped:(id)sender {
  if ([self allRequiredFieldsEntered]) {
    [self saveAction:sender];
  } else {
    NSString *message = NSLocalizedString(@"HockeyAuthenticationAuthFieldsMissing", "");
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"OK")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * action) {}];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
  }
}

- (void)setEmail:(NSString *)email {
  _email = email;
  if(self.isViewLoaded) {
    self.emailTextField.text = email;
  }
}

- (void)setViewTitle:(NSString *)viewDescription {
  _viewTitle = [viewDescription copy];
}

#pragma mark - UIViewController Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return YES;
}

#pragma mark - Private methods
- (BOOL)allRequiredFieldsEntered {
  if (self.requirePassword && [self.password length] == 0)
    return NO;
  
  if (![self.email length] || !bit_validateEmail(self.email))
    return NO;
  
  return YES;
}

- (void)userEmailEntered:(id)sender {
  self.email = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (void)userPasswordEntered:(id)sender {
  self.password = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  NSInteger nextTag = textField.tag + 1;
  
  UIResponder* nextResponder = [self.view viewWithTag:nextTag];
  if (nextResponder) {
    [nextResponder becomeFirstResponder];
  } else {
    if ([self allRequiredFieldsEntered]) {
      if ([textField isFirstResponder])
        [textField resignFirstResponder];
      
      [self saveAction:nil];
    }
  }
  return NO;
}

#pragma mark - Actions

- (void)saveAction:(id)sender {
  [self setLoginUIEnabled:NO];
  
  __weak typeof(self) weakSelf = self;
  [self.delegate authenticationViewController:self
                handleAuthenticationWithEmail:self.email
                                     password:self.password
                                   completion:^(BOOL succeeded, NSError *error) {
                                     if(succeeded) {
                                       //controller should dismiss us shortly..
                                     } else {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                         
                                          UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                          message:error.localizedDescription
                                          preferredStyle:UIAlertControllerStyleAlert];
                                          
                                          
                                          UIAlertAction *okAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"OK")
                                          style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction * action) {}];
                                          
                                          [alertController addAction:okAction];
                                          
                                          [weakSelf presentViewController:alertController animated:YES completion:nil];
                                       });
                                     }
                                   }];
}

#pragma mark - UI Setup

- (void) setLoginUIEnabled:(BOOL) enabled {
  [self.emailTextField setEnabled:NO];
  [self.passwordTextField setEnabled:NO];
  [self.signInButton setEnabled:NO];
}

- (void)setupView {
  
  // Title Text
  self.title = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerSignInButtonTitle");

  // Container View
  _containerView = [UIView new];
  
  // E-Mail Input
  _emailTextField = [UITextField new];
  self.emailTextField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerEmailPlaceholder");
  self.emailTextField.text = self.email;
  self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
  self.passwordTextField.delegate = self;
  self.emailTextField.returnKeyType = [self requirePassword] ? UIReturnKeyNext : UIReturnKeyDone;
  [self.emailTextField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
  [self.containerView addSubview:self.emailTextField];
  
  // Password Input
  if (self.requirePassword) {
    _passwordTextField = [UITextField new];
    self.passwordTextField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerPasswordPlaceholder");
    self.passwordTextField.text = self.password;
    self.passwordTextField.keyboardType = UIKeyboardTypeAlphabet;
    self.passwordTextField.returnKeyType = UIReturnKeyDone;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.delegate = self;
    [self.passwordTextField addTarget:self action:@selector(userPasswordEntered:) forControlEvents:UIControlEventEditingChanged];
    [self.containerView addSubview:self.passwordTextField];
  }

  // Sign Button
  _signInButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [self.signInButton setTitle:BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerSignInButtonTitle") forState:UIControlStateNormal];
  [self.signInButton addTarget:self action:@selector(signInButtonTapped:) forControlEvents:UIControlEventPrimaryActionTriggered];
  [self.containerView addSubview:self.signInButton];
  
  [self.view addSubview:self.containerView];
}

- (void)setupConstraints {
  
  // Preparing views for Auto Layout
  [self.emailTextField setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.passwordTextField setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.signInButton setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.containerView setTranslatesAutoresizingMaskIntoConstraints:NO];
  
  NSMutableDictionary *views = [NSMutableDictionary dictionaryWithObjectsAndKeys:self.emailTextField, @"email", self.signInButton, @"button", nil];
  if (self.requirePassword && self.passwordTextField) {
    [views addEntriesFromDictionary:@{@"password": self.passwordTextField}];
  }
  
  NSLayoutConstraint *centerVerticallyConstraint = [NSLayoutConstraint
                                                    constraintWithItem:self.containerView
                                                    attribute:NSLayoutAttributeCenterY
                                                    relatedBy:NSLayoutRelationEqual
                                                    toItem:self.view
                                                    attribute:NSLayoutAttributeCenterY
                                                    multiplier:1.0
                                                    constant:0];
  [self.view addConstraint:centerVerticallyConstraint];
  
  // Vertical Constraints
  NSString *verticalFormat = nil;
  if (self.requirePassword) {
    verticalFormat = @"V:|[email]-[password]-[button]|";
  } else {
    verticalFormat = @"V:|[email]-[button]|";
  }
  [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:verticalFormat options:0 metrics:nil views:views]];
  
  // Horizonatal Constraints
  NSString *horizontalFormat = @"H:|[email(500)]|";
  [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalFormat options:0 metrics:nil views:views]];
  
  if (self.requirePassword) {
    horizontalFormat = @"H:|[password(500)]|";
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalFormat options:0 metrics:nil views:views]];
  }
  
  horizontalFormat = @"H:[button(260)]";
  [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalFormat options:0 metrics:nil views:views]];
  
  NSLayoutConstraint *centerXButtonConstraints = [NSLayoutConstraint
                                                      constraintWithItem:self.signInButton
                                                      attribute:NSLayoutAttributeCenterX
                                                      relatedBy:NSLayoutRelationEqual
                                                      toItem:self.containerView
                                                      attribute:NSLayoutAttributeCenterX
                                                      multiplier:1.0
                                                      constant:0];
  [self.containerView addConstraint:centerXButtonConstraints];
  
  NSLayoutConstraint *centerHorizontallyConstraint = [NSLayoutConstraint
                                                      constraintWithItem:self.containerView
                                                      attribute:NSLayoutAttributeCenterX
                                                      relatedBy:NSLayoutRelationEqual
                                                      toItem:self.view
                                                      attribute:NSLayoutAttributeCenterX
                                                      multiplier:1.0
                                                      constant:0];
  [self.view addConstraint:centerHorizontallyConstraint];
}

@end

#endif  /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
