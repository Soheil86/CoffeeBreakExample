//
//  UserProfileDatasourceController.swift
//  CoffeeBreakExample
//
//  Created by Alex Nagy on 21/05/2018.
//  Copyright © 2018 Alex Nagy. All rights reserved.
//

import LBTAComponents
import Firebase
import JGProgressHUD

class UserProfileDatasourceController: DatasourceController {
  
  let userProfileDatasource = UserProfileDatasource()
  
  lazy var refreshControl : UIRefreshControl = {
    var rc = self.getRefreshControl()
    return rc
  }()
  
  lazy var logoutBarButtonItem: UIBarButtonItem = {
    var item = UIBarButtonItem(title: "Logout", style: .done, target: self, action: #selector(handleLogoutBarButtonItemTapped))
    return item
  }()
  
  @objc func handleLogoutBarButtonItemTapped() {
    let logOutAction = UIAlertAction(title: "Logout", style: .destructive) { (action) in
      // MARK: FirebaseMagic - Log out
      let hud = JGProgressHUD(style: .light)
      FirebaseMagic.showHud(hud, in: self, text: "Logging out...")
      FirebaseMagic.logout(completion: { (err) in
        hud.dismiss(animated: true)
        
        if let err = err {
          Service.showAlert(on: self, style: .alert, title: "Logout Error", message: err.localizedDescription)
          return
        }
        
        self.deleteCurrentUserSession()
        let controller = SignUpController()
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
      })
    }
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    Service.showAlert(onCollectionViewController: self, style: .actionSheet, title: nil, message: nil, actions: [logOutAction, cancelAction], completion: nil)
  }
  
  @objc fileprivate func handleUserSharedAPost() {
    reloadAllPosts { (result) in
      print("Reloaded posts after user have shared a new post with result:", result)
    }
  }
  
  @objc fileprivate func handleFollowedUser() {
    userProfileDatasource.fetchCurrentUser(in: self) { (currentUser) in
      print("Reloaded user stats after user has followed.")
    }
  }
  
  @objc fileprivate func handleUnfollowedUser() {
    userProfileDatasource.fetchCurrentUser(in: self) { (currentUser) in
      print("Reloaded user stats after user has unfollowed.")
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleUserSharedAPost), name: Service.notificationNameUserSharedAPost, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFollowersButtonTapped), name: Service.notificationNameShowFollowers, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFollowingButtonTapped), name: Service.notificationNameShowFollowing, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFollowedUser), name: Service.notificationNameFollowedUser, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleUnfollowedUser), name: Service.notificationNameUnfollowedUser, object: nil)
    
    datasource = userProfileDatasource
    collectionView?.refreshControl = refreshControl
    
    setupController()
    
    clearPosts()
    
    userProfileDatasource.fetchCurrentUser(in: self) { (currentUser) in
      self.navigationItem.title = currentUser.username
      self.fetchPosts(completion: { (result) in
        print("Fetched post with result:", result)
      })
    }
  }
  
  fileprivate func setupController() {
    collectionView?.backgroundColor = .white
    navigationItem.title = "Me"
    navigationItem.setRightBarButton(logoutBarButtonItem, animated: false)
    collectionView?.showsVerticalScrollIndicator = false
  }
  
  fileprivate func clearPosts() {
    // MARK: FirebaseMagic - Removing current posts if any
    FirebaseMagic.fetchedUserPosts.removeAll()
    FirebaseMagic.fetchedUserPostsCurrentKey = nil
    collectionView?.reloadData()
  }
  
  fileprivate func fetchPosts(completion: @escaping (_ result: Bool) -> ()) {
    // MARK: FirebaseMagic - Fetch user posts
    let hud = JGProgressHUD(style: .light)
    FirebaseMagic.showHud(hud, in: self, text: "Fetching user posts...")
    FirebaseMagic.fetchUserPosts(forUid: FirebaseMagic.currentUserUid(), fetchType: .onUserProfile, in: self, completion: { (result, err) in
      if let err = err {
        print("Failed to fetch user posts with err:", err)
        hud.dismiss(animated: true)
        Service.showAlert(onCollectionViewController: self, style: .alert, title: "Fetch error", message: "Failed to fetch user posts with err: \(err)")
        completion(false)
        return
      } else if result == false {
        hud.textLabel.text = "Something went wrong..."
        hud.dismiss(afterDelay: 1, animated: true)
        completion(false)
        return
      }
      print("Successfully fetched user posts")
      hud.dismiss(animated: true)
      completion(true)
    })
  }
  
  fileprivate func reloadAllPosts(completion: @escaping (_ result: Bool) -> ()) {
    clearPosts()
    fetchPosts { (result) in
      completion(result)
    }
  }
  
  override func handleRefresh() {
    reloadAllPosts { (result) in
      self.refreshControl.endRefreshing()
    }
  }
  
  @objc fileprivate func handleFollowersButtonTapped() {
    let controller = UserStatsDatasourceController()
    controller.statsType = .followers
    let navController = UINavigationController(rootViewController: controller)
    self.navigationController?.present(navController, animated: true, completion: nil)
  }
  
  @objc fileprivate func handleFollowingButtonTapped() {
    let controller = UserStatsDatasourceController()
    controller.statsType = .following
    let navController = UINavigationController(rootViewController: controller)
    self.navigationController?.present(navController, animated: true, completion: nil)
  }
  
  fileprivate func deleteCurrentUserSession() {
    
  }
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    
    // MARK: FirebaseMagic - Trigger pagination when last item will be displayed
    if FirebaseMagic.fetchedUserPosts.count > FirebaseMagic.paginationElementsLimitUserPosts - 1 {
      if indexPath.row == FirebaseMagic.fetchedUserPosts.count - 1 {
        fetchPosts { (result) in
          print("Paginated user posts with result:", result)
        }
      }
    }
    
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
    return CGSize(width: ScreenSize.width, height: 180)
  }
  
  override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = (ScreenSize.width - 2) / 3
    return CGSize(width: width, height: width)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 1
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 1
  }
  
}