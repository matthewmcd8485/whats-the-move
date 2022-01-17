//
//  RemoteConfigValues.swift
//  wtm?
//
//  Created by Matthew McDonnell on 1/16/22.
//

import Foundation
import Firebase

final class RemoteConfigValues {
    static let shared = RemoteConfigValues()
    var loadingDoneCallback: (() -> Void)?
    var fetchComplete = false
    
    let remoteConfig = RemoteConfig.remoteConfig()
    
    private init() {
        loadDefaultValues()
        fetchCloudValues()
    }
    
    private func loadDefaultValues() {
        let appDefaults: [String: Any] = [
            "latestVersion" : 1.2
        ]
        
        remoteConfig.setDefaults(appDefaults as? [String : NSObject])
    }
    
    
    private func fetchCloudValues() {
        // WARNING: Turn this to false for production!
        debugMode(active: true)
        
        remoteConfig.fetch { [weak self] _, error in
            if let error = error {
                print("Uh-oh. Got an error fetching remote values \(error)")
                // In a real app, you would probably want to call the loading done callback anyway,
                // and just proceed with the default values. I won't do that here, so we can call attention
                // to the fact that Remote Config isn't loading.
                return
            }
            
            RemoteConfig.remoteConfig().activate { [weak self] _, _ in
                print("Retrieved values from the cloud!")
                self?.fetchComplete = true
                DispatchQueue.main.async {
                    self?.loadingDoneCallback?()
                }
            }
        }
    }
    
    func debugMode(active: Bool) {
        let settings = RemoteConfigSettings()
        
        if active {
            settings.minimumFetchInterval = 0
        } else {
            settings.minimumFetchInterval = 43200
        }
        
        RemoteConfig.remoteConfig().configSettings = settings
    }
    
    func color(forKey key: ValueKey) -> UIColor {
        let colorAsHexString = RemoteConfig.remoteConfig()[key.rawValue].stringValue ?? "#FFFFFFFF"
        guard let convertedColor = UIColor(named: colorAsHexString) else {
            return UIColor.white
        }
        return convertedColor
    }
    
    func bool(forKey key: ValueKey) -> Bool {
        RemoteConfig.remoteConfig()[key.rawValue].boolValue
    }
    
    func string(forKey key: ValueKey) -> String {
        RemoteConfig.remoteConfig()[key.rawValue].stringValue ?? ""
    }
    
    func double(forKey key: ValueKey) -> Double {
        RemoteConfig.remoteConfig()[key.rawValue].numberValue.doubleValue
    }
}
