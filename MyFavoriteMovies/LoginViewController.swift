//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate                        
        
        configureUI()
        
        subscribeToNotification(NSNotification.Name.UIKeyboardWillShow.rawValue, selector: #selector(keyboardWillShow))
        subscribeToNotification(NSNotification.Name.UIKeyboardWillHide.rawValue, selector: #selector(keyboardWillHide))
        subscribeToNotification(NSNotification.Name.UIKeyboardDidShow.rawValue, selector: #selector(keyboardDidShow))
        subscribeToNotification(NSNotification.Name.UIKeyboardDidHide.rawValue, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    fileprivate func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "MoviesTabBarController") as! UITabBarController
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    fileprivate func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request)  { (data, response, error) in
            func displayError(error : String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "login failed (request token)."
                }
                
            }
            
            guard (error == nil) else {
                displayError(error: "there is error in requet token")
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode ,
                statusCode >= 200 && statusCode <= 299 else {
                    displayError(error: "Status Code is not 200.")
                    return
            }
            guard let data = data else {
                displayError(error: "LLL")
                return
            }
            
            /* 5. Parse the data */
            let parsedObject : [String : AnyObject]
            do {
                parsedObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject]
            } catch {
                    print("NNNN")
                    return
                }
            guard let  requestToken = parsedObject[Constants.TMDBResponseKeys.RequestToken] as? AnyObject  else {
                print("The request has an error")
                return
            }
            print("This is request token :\(requestToken)")
            self.appDelegate.requestToken = requestToken as? String
            self.loginWithToken(requestToken: self.appDelegate.requestToken!)
            
            
                
            
            /* 6. Use the data! */
        }

        /* 7. Start the request */
        task.resume()
    }
    
    fileprivate func loginWithToken(requestToken: String) {
        
        /* TASK: Login, then get a session id */
        
        /* 1. Set the parameters */
        let methodParameter : [String : String?] = [Constants.TMDBParameterKeys.ApiKey : Constants.TMDBParameterValues.ApiKey, Constants.TMDBParameterKeys.RequestToken : requestToken , Constants.TMDBParameterKeys.Username : usernameTextField.text, Constants.TMDBParameterKeys.Password : passwordTextField.text]
        
        
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameter as [String : AnyObject] , withPathExtension : "/authentication/token/validate_with_login"))
        print("MY url : \(request)")
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            func displayError(error : String) {
                print(error)
                performUIUpdatesOnMain {
                     self.setUIEnabled(true)
                }
            }
                guard (error == nil) else {
                    displayError(error: "There is error in sessin ID")
                    return
                }
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode , statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "Status code is not in 200")
                return
            }
            print("Status code is : \(statusCode)")
            
            guard let data = data else {
                displayError(error: "There is no data")
                
                return
            }
            
            
            /* 5. Parse the data */

            let parsedResult : [String :AnyObject]
            do {
                 parsedResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? AnyObject as! [String : AnyObject]            }
            catch
                 {
                print("UNable to parsed data")
                return
            }
            
        
                /* 6. Use the data! */
            guard let success = parsedResult[Constants.TMDBResponseKeys.Success]  as? Bool , (success == true) else {
                displayError(error: "Cannot find key in \(Constants.TMDBResponseKeys.Success)in \(parsedResult)")
                return
            }
            print("ready to get SessionID")
            self.getSessionID(self.appDelegate.requestToken!)
            
        }
        task.resume()
    
    }
    
    fileprivate func getSessionID(_ requestToken: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        
        /* 1. Set the parameters */
        let methodParameters : [String : String?] = [Constants.TMDBParameterKeys.ApiKey : Constants.TMDBParameterValues.ApiKey, Constants.TMDBParameterKeys.RequestToken : requestToken]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension : "/authentication/session/new"))
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) {
            (data, response, error) in
            
        
        /* 5. Parse the data */
            let parsedResult : [String : AnyObject]
            do { parsedResult = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject]
                
            }
            catch {
                return
            }
        /* 6. Use the data! */
            guard let sessionID = parsedResult[Constants.TMDBResponseKeys.SessionID] as? String else {
                return
            }
            print("This is sessionID \(sessionID)")
            self.appDelegate.sessionID =  sessionID
            
            self.getUserID(self.appDelegate.sessionID!)
            
        /* 7. Start the request */
        }
        task.resume()
    }
    
    fileprivate func getUserID(_ sessionID: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        /* 1. Set the parameters */
        let methodParameters = [Constants.TMDBParameterKeys.ApiKey : Constants.TMDBParameterValues.ApiKey, Constants.TMDBParameterKeys.SessionID : sessionID]
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject],  withPathExtension : "/ account"))
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) {(data,response,error) in
        
            func displayError(error : String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Failed "
                    
                }
            }
            
            guard error == nil else {
                displayError(error: "Theere is an error \(error)")
                return
            }
            guard let statusCode = (response as? HTTPURLResponse)? .statusCode , statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "status code is not in 200 ")
            
                return
            }
            guard let data = data else {
                displayError(error: "there is no data")
                return

            }
            /* 5. Parse the data */
            let parsedResult : [String : AnyObject]!
            do {parsedResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)  as! [String : AnyObject]
                        } catch  {
                            displayError(error: "Cannot find key '\(Constants.TMDBResponseKeys.UserID)")
                return
            }
        /* 6. Use the data! */
            
            guard let userID = parsedResult[Constants.TMDBResponseKeys.UserID]  else{
                return
            }
            print("This is UserID :\(userID)")
            self.appDelegate.userID = userID as? Int
            self.completeLogin()

        /* 7. Start the request */
        }
        task.resume()
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.isHidden = true
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.isHidden = false
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    fileprivate func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    fileprivate func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

extension LoginViewController {
    
    fileprivate func setUIEnabled(_ enabled: Bool) {
        usernameTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        loginButton.isEnabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.isEnabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    fileprivate func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    fileprivate func configureTextField(_ textField: UITextField) {
        let textFieldPaddingViewFrame = CGRect(x: 0.0, y: 0.0, width: 13.0, height: 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSForegroundColorAttributeName: UIColor.white])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

extension LoginViewController {
    
    fileprivate func subscribeToNotification(_ notification: String, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: NSNotification.Name(rawValue: notification), object: nil)
    }
    
    fileprivate func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
