//
//  FirebaseMagic.swift
//  CoffeeBreakExample
//
//  Created by Alex Nagy on 21/05/2018.
//  Copyright © 2018 Alex Nagy. All rights reserved.
//
// Icons from https://icons8.com/

import UIKit
import Firebase
import JGProgressHUD

class FirebaseMagic {
  
//  // for testing
//  static let Database_Users = Database.database().reference().child("test").child("users")
//  static let Database_Usernames = Database.database().reference().child("test").child("usernames")
//  static let Storage_ProfileImages = Storage.storage().reference().child("test").child("profile_images")
  
  // for live
  static let Database_Users = Database.database().reference().child("users")
  static let Database_Usernames = Database.database().reference().child("usernames")
  static let Database_Posts = Database.database().reference().child("posts")
  static let Database_UserPosts = Database.database().reference().child("userPosts")
  static let Database_UserFeed = Database.database().reference().child("userFeed")
  static let Database_UserFollowers = Database.database().reference().child("userFollowers")
  static let Database_UserFollowing = Database.database().reference().child("userFollowing")
  
  static let Storage_ProfileImages = Storage.storage().reference().child("profile_images")
  static let Storage_PostImages = Storage.storage().reference().child("post_images")
  
  static let CurrentUserUid = Auth.auth().currentUser?.uid
  
  static var fetchedPosts = [Post]()
  static var fetchedPostsCurrentKey: String?
  static let paginationElementsLimitPosts: UInt = 3
  
  static var fetchedUserPosts = [Post]()
  static var fetchedUserPostsCurrentKey: String?
  static let paginationElementsLimitUserPosts: UInt = 12
  
  static func start() {
    FirebaseApp.configure()
  }
  
  static func checkIfUserIsSignedIn(completion: @escaping (_ result: Bool) ->()) {
    if Auth.auth().currentUser == nil {
      completion(false)
    } else {
      completion(true)
    }
  }
  
  static func logout(completion: @escaping (_ error: Error?) ->()) {
    do {
      try Auth.auth().signOut()
      completion(nil)
    } catch let err {
      print("Failed to sign out with error:", err)
      completion(err)
    }
  }
  
  static func resetPassword(withUsernameOrEmail usernameOrEmail: String?, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    guard let usernameOrEmail = usernameOrEmail else {
      completion(false, nil)
      return
    }
    
    if usernameOrEmail.range(of: "@") != nil {
      print("Reseting password with email:", usernameOrEmail)
      resetPassword(withEmail: usernameOrEmail) { (result, err) in
        completion(result, err)
      }
      
    } else {
      print("Reseting password with username:", usernameOrEmail)
      resetPassword(withUserName: usernameOrEmail) { (result, err) in
        completion(result, err)
      }
    }
  }
  
  private static func resetPassword(withUserName username: String, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    Database_Usernames.child(username).observeSingleEvent(of: .value, with: { (snapshot) in
      guard let email = snapshot.value as? String else {
        print("Failed to fetch username: invalid username")
        completion(false, nil)
        return
      }
      resetPassword(withEmail: email) { (result, err) in
        completion(result, err)
      }
    }) { (err) in
      print("Failed to fetch username:", err)
      completion(false, err)
    }
  }
  
  private static func resetPassword(withEmail email: String, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    Auth.auth().sendPasswordReset(withEmail: email) { (err) in
      if let err = err {
        print("Failed to reset password with email:", err)
        completion(false, err)
        return
      }
      print("Successfully sent reset password to email:", email)
      completion(true, nil)
    }
  }
  
  static func signIn(withUsernameOrEmail usernameOrEmail: String?, password: String?, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    guard let usernameOrEmail = usernameOrEmail, let password = password else {
      completion(false, nil)
      return
    }
    
    if usernameOrEmail.range(of: "@") != nil {
      print("Signing in with email:", usernameOrEmail)
      signIn(withEmail: usernameOrEmail, password: password) { (result, err) in
        completion(result, err)
      }
      
    } else {
      print("Signing in with username:", usernameOrEmail)
      signIn(withUsername: usernameOrEmail, password: password) { (result, err) in
        completion(result, err)
      }
    }
    
  }
  
  private static func signIn(withUsername username: String, password: String, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    Database_Usernames.child(username).observeSingleEvent(of: .value, with: { (snapshot) in
      guard let email = snapshot.value as? String else {
        print("Failed to fetch username: invalid username")
        completion(false, nil)
        return
      }
      signIn(withEmail: email, password: password) { (result, err) in
        completion(result, err)
      }
    }) { (err) in
      print("Failed to fetch username:", err)
      completion(false, err)
    }
  }
  
  private static func signIn(withEmail email: String, password: String, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    Auth.auth().signIn(withEmail: email, password: password) { (result, err) in
      if let err = err {
        print("Failed to sign in with email:", err)
        completion(false, err)
        return
      }
      
      guard let result = result else {
        completion(false, nil)
        return
      }
      print("Successfully logged back in with user:", result.user.uid)
      completion(true, nil)
    }
  }
  
  static func signUpUserWithEmail(in viewController: UIViewController, userCredentials: [String : Any], userDetails: [String : Any]?, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    guard let username = userCredentials[keyUsername] as? String else {
      completion(false, nil)
      return
    }
    fetchUser(withUsername: username, limitedToFirst: 1) { (users, err) in
      if let err = err {
        completion(false, err)
      }
      
      if users == nil {
        
        signUpUniqueUserWithEmail(userCredentials: userCredentials, userDetails: userDetails) { (result, err) in
          completion(result, err)
        }
        
      } else {
        
        let textField = UITextField()
        textField.placeholder = "New Username"
        textField.autocapitalizationType = .none
        
        Service.showAlert(on: viewController, style: .alert, title: "Sign Up Error", message: "The username '\(username.lowercased())' is already taken. Please, choose another one.", textFields: [textField], completion: { (usernames) in
          guard let usernames = usernames, let username = usernames.first else {
            completion(false, nil)
            return
          }
          var mutableUserCredentials = userCredentials
          mutableUserCredentials.updateValue(username, forKey: keyUsername)
          signUpUserWithEmail(in: viewController, userCredentials: mutableUserCredentials, userDetails: userDetails, completion: { (result, err) in
            completion(result, err)
          })
        })
        
      }
    }
    
  }
  
  private static func signUpUniqueUserWithEmail(userCredentials: [String : Any], userDetails: [String : Any]?, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    guard let email = userCredentials[keyEmail] as? String,
      let password = userCredentials[keyPassword] as? String else {
        completion(false, nil)
        return
    }
    
    Auth.auth().createUser(withEmail: email, password: password) { (result, err) in
      if let err = err {
        print("Failed to create Firebase user:", err)
        completion(false, err)
        return
      }
      
      guard let result = result else {
        completion(false, nil)
        return
      }
      print("Successfully created Firebase user:", result.user.uid )
      saveUserIntoFirebase(user: result.user, userCredentials: userCredentials, userDetails: userDetails, completion: { (result, err) in
        if let err = err {
          completion(false, err)
          return
        } else if result == false {
          completion(false, nil)
          return
        }
        completion(result, err)
      })
    }
  }
  
  private static func saveUserIntoFirebase(user: User?, userCredentials: [String : Any], userDetails: [String : Any]?, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    guard let user = user,
      let email = user.email,
      let username = userCredentials[keyUsername] as? String else {
      completion(false, nil)
      return
    }
    
    let uid = user.uid
    var mutableUserDetails: [String : Any] = [keyUsername: username.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "#", with: "_").replacingOccurrences(of: "$", with: "_").replacingOccurrences(of: "[", with: "_").replacingOccurrences(of: "]", with: "_").replacingOccurrences(of: "/", with: "_"), keyEmail : email]
    
    if let userDetails = userDetails {
      mutableUserDetails.update(with: userDetails)
      
      if let profileImage = mutableUserDetails[keyProfileImage] as? UIImage {
        saveImage(profileImage, atPath: Storage_ProfileImages) { (imageUrl, result, err) in
          if let err = err {
            completion(false, err)
            return
          } else if result == false {
            completion(false, nil)
            return
          }
          guard let imageUrl = imageUrl else {
            completion(false, nil)
            return
          }
          
          mutableUserDetails.updateValue(imageUrl, forKey: keyProfileImageUrl)
          mutableUserDetails.removeValue(forKey: keyProfileImage)
          
          updateUserValues(forCurrentUserUid: uid, with: mutableUserDetails, username: username, email: email) { (result, err) in
            completion(result, err)
          }
          
        }
      } else {
        
        updateUserValues(forCurrentUserUid: uid, with: mutableUserDetails, username: username, email: email) { (result, err) in
          completion(result, err)
        }
        
      }
    } else {
      
      updateUserValues(forCurrentUserUid: uid, with: mutableUserDetails, username: username, email: email) { (result, err) in
        completion(result, err)
      }
      
    }
    
  }
  
  private static func updateUserValues(forCurrentUserUid currentUserUid: String, with dictionary: [String : Any], username: String, email: String,  completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    
    updateValues(atPath: Database_Users.child(currentUserUid), with: dictionary, completion: { (result, err) in
      if let err = err {
        completion(false, err)
        return
      } else if result == false {
        completion(false, nil)
        return
      }
      updateValues(atPath: Database_Usernames, with: [username.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "#", with: "_").replacingOccurrences(of: "$", with: "_").replacingOccurrences(of: "[", with: "_").replacingOccurrences(of: "]", with: "_").replacingOccurrences(of: "/", with: "_") : email], completion: { (result, err) in
        if let err = err {
          completion(false, err)
          return
        } else if result == false {
          completion(false, nil)
          return
        }
        let values = [currentUserUid : 1]
        updateValues(atPath: Database_UserFollowers.child(currentUserUid), with: values, completion: { (result, err) in
          completion(result, err)
        })
      })
    })
  }
  
  private static func updateValues(atPath path: DatabaseReference, with dictionary: [String : Any],  completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    path.updateChildValues(dictionary) { (err, ref) in
      if let err = err {
        print("Failed to update Firebase database with error:", err)
        completion(false, err)
        return
      }
      print("Successfully updated Firebase database at path: '\(path)' with values: '\(dictionary)'")
      completion(true, nil)
    }
  }
  
  private static func observeValues(atPath path: DatabaseReference, eventType: DataEventType,  completion: @escaping (_ snapshot: DataSnapshot?, _ error: Error?) ->()) {
    path.observe(eventType, with: { (snapshot) in
      completion(snapshot, nil)
    }) { (err) in
      completion(nil, err)
    }
  }
  
  private static func saveImage(_ image: UIImage,atPath path: StorageReference, completion: @escaping (_ imageUrl: String?, _ result: Bool, _ error: Error?) ->()) {
    guard let imageUploadData = UIImageJPEGRepresentation(image, 0.3) else {
      completion(nil, false, nil)
      return
    }
    let fileName = UUID().uuidString
    path.child(fileName).putData(imageUploadData, metadata: nil) { (metadata, err) in
      if let err = err {
        print("Failed to upload image into Firebase storage with error:", err)
        completion(nil, false, err)
        return
      }
      path.child(fileName).downloadURL(completion: { (url, err) in
        if let err = err {
          print("Failed to get image url with error:", err)
          completion(nil, false, err)
          return
        }
        guard let imageUrl = url?.absoluteString else {
          completion(nil, false, nil)
          return
        }
        print("Successfully uploaded image into Firebase storage with URL:", imageUrl)
        completion(imageUrl, true, nil)
      })
    }
  }
  
  static func fetchUser(withUsername username: String, limitedToFirst: Int, completion: @escaping (_ users: [CurrentUser]?, _ error: Error?) -> ()) {
    
    var filteredUsers: [CurrentUser] = []
    let lowerCasedSearchText = username.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "#", with: "_").replacingOccurrences(of: "$", with: "_").replacingOccurrences(of: "[", with: "_").replacingOccurrences(of: "]", with: "_").replacingOccurrences(of: "/", with: "_")
    let userRef = Database_Users.queryLimited(toFirst: UInt(limitedToFirst)).queryOrdered(byChild: keyUsername).queryStarting(atValue: lowerCasedSearchText).queryEnding(atValue: lowerCasedSearchText+"\u{f8ff}")
    
    userRef.observeSingleEvent(of: .value, with: { (snapshot) in
      
      if snapshot.exists() {
        guard let dictionaries = snapshot.value as? [String: Any] else { return }
        
        dictionaries.forEach({ (key, value) in
          if key == currentUserUid() {
            return
          }
          guard let userDictionary = value as? [String: Any] else { return }
          let user = CurrentUser(uid: key, dictionary: userDictionary)
          
          let isContained = filteredUsers.contains(where: { (containedUser) -> Bool in
            return user.uid == containedUser.uid
          })
          if !isContained {
            filteredUsers.append(user)
          }
          
        })
        print("Filtered users:", filteredUsers)
        completion(filteredUsers, nil)
      } else {
        print("No users available")
        completion(nil, nil)
      }
      
    }) { (err) in
      print("Failed to fetch users:", err)
      completion(nil, err)
    }
  }
  
  static func currentUserUid() -> String? {
    return Auth.auth().currentUser?.uid
  }
  
  static func fetchUser(withUid uid: String, completion: @escaping (_ user: CurrentUser?, _ error: Error?) -> ()) {
    Database_Users.child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
      guard let dictionary = snapshot.value as? [String : Any] else {
        completion(nil, nil)
        return
      }
      
      fetchUserStats(forUid: uid, completion: { (userStats, err) in
        if let err = err {
          print("Failed to fetch user stats:", err)
          completion(nil, err)
        }
        
      })
      
      let user = CurrentUser(uid: uid, dictionary: dictionary)
      completion(user, nil)
    }) { (err) in
      print("Failed to fetch user:", err)
      completion(nil, err)
    }
  }
  
  static func fetchUserStats(forUid uid: String, completion: @escaping (_ userStatsDictionary: [String : Any]?, _ error: Error?) -> ()) {
    var userStats: [String : Any] = [:]
    Database_UserPosts.child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
      let postsCount = snapshot.childrenCount
      userStats.update(with: [keyPostsCount: postsCount])
      
      Database_UserFollowers.child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
        let followersCount = snapshot.childrenCount
        userStats.update(with: [keyFollowersCount: followersCount])
        
        Database_UserFollowing.child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
          let followingCount = snapshot.childrenCount
          userStats.update(with: [keyFollowingCount: followingCount])
          completion(userStats, nil)
          
        }, withCancel: { (err) in
          print("Failed to fetch user following for count:", err)
          completion(nil, err)
        })
        
      }, withCancel: { (err) in
        print("Failed to fetch user followers for count:", err)
        completion(nil, err)
      })
      
    }, withCancel:{ (err) in
      print("Failed to fetch user posts for count:", err)
      completion(nil, err)
    })
  }
  
  static func sharePost(withCaption caption: String, image: UIImage, completion: @escaping (_ result: Bool, _ error: Error?) ->()) {
    saveImage(image, atPath: Storage_PostImages) { (imageUrl, result, err) in
      if let err = err {
        completion(false, err)
        return
      } else if result == false {
        completion(false, nil)
        return
      }
      guard let imageUrl = imageUrl, let currentUserUid = currentUserUid() else {
        completion(false, nil)
        return
      }
      let postRef = Database_Posts.childByAutoId()
      let postId = postRef.key
      let values = [keyCaption: caption,
                    keyImageUrl: imageUrl,
                    keyOwnerId: currentUserUid,
                    keyId: postId,
                    keyCreationDate : Date().timeIntervalSince1970] as [String : Any]
      
      updateValues(atPath: postRef, with: values, completion: { (result, err) in
        if let err = err {
          completion(false, err)
          return
        } else if result == false {
          completion(false, nil)
          return
        }
        
        let values = [postId : 1]
        updateValues(atPath: Database_UserPosts.child(currentUserUid), with: values, completion: { (result, err) in
          if let err = err {
            completion(false, err)
            return
          } else if result == false {
            completion(false, nil)
            return
          }
          
          observeValues(atPath: Database_UserFollowers.child(currentUserUid), eventType: .childAdded, completion: { (snapshot, err) in
            if let err = err {
              completion(false, err)
              return
            } else if snapshot == nil {
              completion(false, nil)
              return
            }
            guard let snapshot = snapshot else {
              completion(false, nil)
              return
            }
            
            let followerUid = snapshot.key
            let values = [postId : 1]
            updateValues(atPath: Database_UserFeed.child(followerUid), with: values, completion: { (result, err) in
              completion(result, err)
            })
          })
        })
      })
    }
  }
  
//  static func fetchCurrentUserPosts(uid: String, in collectionViewController: UICollectionViewController, completion: @escaping () -> ()) {
//    print("Started fetching posts for current user with id:", uid)
//    // guard let currentUid = Service.currentUserUid else { return }
//
//    if fetchedUserPostsCurrentKey == nil {
//      // initial pull
//      Database_UserPosts.child(uid).queryLimited(toLast: paginationElementsLimitUserPosts).observeSingleEvent(of: .value, with: { (snapshot) in
//
//        if snapshot.childrenCount == 0 {
//          print("No posts to fetch for user.")
//          completion()
//        }
//
//        guard let first = snapshot.children.allObjects.first as? DataSnapshot else { return }
//        guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
//
//        allObjects.forEach({ (snapshot) in
//          let postId = snapshot.key
//          Service.fetchCurrentUserPost(withPostId: postId, in: collectionViewController, completion: {
//            completion()
//          })
//        })
//
//        Service.fetchedCurrentUserPostsCurrentKey = first.key
//
//      }) { (err) in
//        print("Failed to query current user posts: ", err)
//      }
//
//    } else {
//      // paginate here
//      Service.database.child(pathUserPosts).child(uid).queryOrderedByKey().queryEnding(atValue: Service.fetchedCurrentUserPostsCurrentKey).queryLimited(toLast: paginationElementsLimitCurrentUserPosts).observeSingleEvent(of: .value, with: { (snapshot) in
//
//        guard let first = snapshot.children.allObjects.first as? DataSnapshot else { return }
//        guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
//
//        allObjects.forEach({ (snapshot) in
//
//          if snapshot.key != Service.fetchedCurrentUserPostsCurrentKey {
//            let postId = snapshot.key
//            Service.fetchCurrentUserPost(withPostId: postId, in: collectionViewController, completion: {
//              completion()
//            })
//          }
//
//        })
//
//        Service.fetchedCurrentUserPostsCurrentKey = first.key
//
//      }) { (err) in
//        print("Failed to query and paginate current user: ", err)
//      }
//    }
//
//  }
  
//  fileprivate static func fetchUserPost(with postId: String, in collectionViewController: UICollectionViewController, completion: @escaping () -> ()) {
//
//    Database.fetchPost(with: postId) { (post) in
//
//      fetchedCurrentUserPosts.insert(post, at: 0)
//      self.fetchedCurrentUserPosts.sort(by: { (p1, p2) -> Bool in
//        return p1.creationDate.compare(p2.creationDate) == .orderedDescending
//      })
//
//      collectionViewController.collectionView?.reloadData()
//      print("Fetched current user post with id:", postId)
//
//      completion()
//    }
//  }
  
//  static func fetchPost(with postId: String, completion: @escaping(Post) -> ()) {
//    Database_Posts.child(postId).observeSingleEvent(of: .value) { (snapshot) in
//      guard let dictionary = snapshot.value as? Dictionary<String, AnyObject> else { return }
//      guard let ownerUid = dictionary[keyOwnerId] as? String else { return }
//
//      fetch
//
//      fetchUserWith(ownerUid, completion: { (user) in
//        guard let user = user else { return }
//        var post = Post(user: user, dictionary: dictionary)
//        post.id = postId
//
//        guard let uid = Service.currentUserUid else { return }
//
//        Service.database.child(pathPostLikes).child(postId).child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
//          if let value = snapshot.value as? Int, value == 1 {
//            post.hasLiked = true
//          } else {
//            post.hasLiked = false
//          }
//          completion(post)
//        }, withCancel: { (err) in
//          print("Failed to fetch like for post with error:", err)
//        })
//
//
//      })
//
//    }
//  }
  
  static func showHud(_ hud: JGProgressHUD, in viewController: UIViewController, text: String) {
    hud.textLabel.text = text
    hud.show(in: viewController.view, animated: true)
  }
  
  static func showHud(_ hud: JGProgressHUD, in collectionViewController: UICollectionViewController, text: String) {
    hud.textLabel.text = text
    hud.show(in: collectionViewController.view, animated: true)
  }
  
}
