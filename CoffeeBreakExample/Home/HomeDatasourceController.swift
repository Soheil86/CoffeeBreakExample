//
//  HomeDatasourceController.swift
//  CoffeeBreakExample
//
//  Created by Alex Nagy on 21/05/2018.
//  Copyright © 2018 Alex Nagy. All rights reserved.
//

import LBTAComponents
import Firebase
import JGProgressHUD

class HomeDatasourceController: DatasourceController {
  
  let homeDatasource = HomeDatasource()
  
  lazy var refreshControl : UIRefreshControl = {
    var rc = self.getRefreshControl()
    return rc
  }()
  
  @objc fileprivate func handleUserSharedAPost() {
    reloadAllPosts { (result) in
      print("Reloaded posts after user have shared a new post with result:", result)
    }
  }
  
  @objc fileprivate func handleFollowedUser() {
    reloadAllPosts { (result) in
      print("Reloaded posts after user has followed with result:", result)
    }
  }
  
  @objc fileprivate func handleUnfollowedUser() {
    reloadAllPosts { (result) in
      print("Reloaded posts after user has unfollowed with result:", result)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleUserSharedAPost), name: Service.notificationNameUserSharedAPost, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFollowedUser), name: Service.notificationNameFollowedUser, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleUnfollowedUser), name: Service.notificationNameUnfollowedUser, object: nil)
    
    datasource = homeDatasource
    collectionView?.refreshControl = refreshControl
    
    setupController()
    
    clearPosts()
    
//    homeDatasource.fetchCurrentUser(in: self) { (currentUser) in
//      self.navigationItem.title = currentUser.username
//      self.fetchPosts(completion: { (result) in
//        print("Fetched post with result:", result)
//      })
//    }
    
    fetchPosts { (result) in
      print("Fetched posts with result:", result)
    }
  }
  
  fileprivate func setupController() {
    collectionView?.backgroundColor = .white
    navigationItem.title = "Home"
    collectionView?.showsVerticalScrollIndicator = false
  }
  
  fileprivate func clearPosts() {
    // MARK: FirebaseMagic - Removing current posts if any
    FirebaseMagic.fetchedPosts.removeAll()
    FirebaseMagic.fetchedPostsCurrentKey = nil
    collectionView?.reloadData()
  }
  
  fileprivate func fetchPosts(completion: @escaping (_ result: Bool) -> ()) {
    // MARK: FirebaseMagic - Fetch posts
    let hud = JGProgressHUD(style: .light)
    FirebaseMagic.showHud(hud, in: self, text: "Fetching posts...")
    FirebaseMagic.fetchUserPosts(forUid: FirebaseMagic.currentUserUid(), fetchType: .onHome, in: self, completion: { (result, err) in
      if let err = err {
        print("Failed to fetch posts with err:", err)
        hud.dismiss(animated: true)
        Service.showAlert(onCollectionViewController: self, style: .alert, title: "Fetch error", message: "Failed to fetch posts with err: \(err)")
        completion(false)
        return
      } else if result == false {
        hud.textLabel.text = "Something went wrong..."
        hud.dismiss(afterDelay: 1, animated: true)
        completion(false)
        return
      }
      print("Successfully fetched posts")
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
  
  fileprivate func deleteCurrentUserSession() {
    
  }
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    
    // MARK: FirebaseMagic - Trigger pagination when last item will be displayed
    if FirebaseMagic.fetchedPosts.count > FirebaseMagic.paginationElementsLimitPosts - 1 {
      if indexPath.row == FirebaseMagic.fetchedPosts.count - 1 {
        fetchPosts { (result) in
          print("Paginated posts with result:", result)
        }
      }
    }
    
  }
  
  override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = ScreenSize.width
    let height = 8 + 32 + 8 + width + 8 + 36 + 8 + 18 + 8
    return CGSize(width: width, height: height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 1
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 1
  }
  
}

