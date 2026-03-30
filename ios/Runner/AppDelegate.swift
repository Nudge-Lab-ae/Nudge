import UIKit
import Flutter
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase first
    FirebaseApp.configure()
    
    // Setup for iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      // Request notification permissions
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound, .provisional]
      ) { granted, error in
        if granted {
          //print("✅ Notification permission granted")
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
          }
        } else {
          //print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown error")")
        }
      }
    } else {
      // For iOS 9 and below
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle successful registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Pass token to Firebase
    Messaging.messaging().apnsToken = deviceToken
    
    // Print token for debugging
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    //print("✅ APNS Token: \(tokenString)")
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    //print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    
    // Log detailed error for debugging
    let nsError = error as NSError
    //print("Error domain: \(nsError.domain)")
    //print("Error code: \(nsError.code)")
    //print("Error userInfo: \(nsError.userInfo)")
  }
  
  // Handle notification actions for iOS 10+
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // Handle action button taps
    let actionId = response.actionIdentifier
    
    // Send to Flutter via method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "notification_actions",
        binaryMessenger: controller.binaryMessenger
      )
      channel.invokeMethod("handleNotificationAction", arguments: [
        "action": actionId,
        "payload": userInfo
      ])
    }
    
    completionHandler()
  }
  
  // Handle foreground notifications for iOS 10+
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    //print("📱 Foreground notification received: \(userInfo)")
    
    // Show banner even when app is in foreground
    completionHandler([.alert, .badge, .sound])
  }
}