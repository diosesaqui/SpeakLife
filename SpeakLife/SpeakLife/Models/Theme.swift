//
//  Theme.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/7/22.
//

import Foundation
import SwiftUI

class Theme: Identifiable, Codable {
    
    enum Mode: String, Codable {
        case light
        case dark
    }
    
    let isPremium: Bool
    
    var backgroundImageString: String
    var id = UUID()
    var mode: Mode
    let blurEffect: Bool
    
    var fontColor: Color {
        switch fontColorString {
        case "white": return Color.white
        case "green": return .green
        case "black" : return .black
        case "gold": return Constants.gold
        case "slBlue": return Constants.DAMidBlue
        default: return .white
        }
    }
    let fontColorString: String
    var image: Image {
        Image(backgroundImageString)
    }
    
    private(set) var userSelectedImageData: Data?
    
    var userSelectedImage: UIImage? {
        if let imageData = userSelectedImageData,  let uiimage = UIImage(data: imageData) {
            return uiimage
        }
        return nil
    }
    
    init(_ backgroundImageString: String, mode: Mode = .dark, isPremium: Bool = true, blurEffect: Bool = false, userSelectedImageData: Data? = nil, fontColorString: String = "white") {
        self.backgroundImageString = backgroundImageString
        self.mode = mode
        self.isPremium = isPremium
        self.blurEffect = blurEffect
        self.userSelectedImageData = userSelectedImageData
        self.fontColorString = fontColorString
    }

    
    func setUserSelectedImage(image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.5) {
            userSelectedImageData = imageData
        }
    }
    
    func setBackground(_ backgroundImageString: String) {
        self.backgroundImageString = backgroundImageString
        self.userSelectedImageData = nil
    }
    
     func encode() -> Data? {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            return encoded
        } else {
            return nil
        }
    }
    
    static func decode(data: Data) -> Theme? {
        let decoder = JSONDecoder()
        if let theme = try? decoder.decode(Theme.self, from: data) {
            return theme
        } else {
            return nil
        }
    }
    
    static var all: [Theme] = [nightaurora, starrySunrise, redmoon, fullmoonOcean, JesusOnWater,JesusOnCross,JesusHealing,JesusRisen, lakeSunrise2,oceansunrise2, sunsetMountains3,mountainValley,autumnLake, autumnleaves,redRosesGreySkies, redTreeLake, snowMountainLake,boatLakeMountain,sunriseCliff,heavenStairway,wheatFieldRedRose,nightStarrySkies, desertNight, doveSkies,wheatField,lightHouse,oceanSunrise,lakeSunset,  JesusPraying, JesusHeaven,warriorAngel,heavenly, starryNight,lakeTrees,majesticNight, mountainLandscape, pinkHueMountain, sunsetMountain, breathTakingSunset, sunset3,moonlight2,desertsky, lushForestSunrise, flowingRiver]
    
    private static let boatLakeMountain = Theme("boatLakeMountain", blurEffect: true)
    private static let nightaurora = Theme("nightaurora", blurEffect: false)
    private static let autumnleaves = Theme("autumnleaves", blurEffect: false)
    private static let redRosesGreySkies = Theme("redRosesGreySkies", blurEffect: false)
    private static let redTreeLake = Theme("redTreeLake", blurEffect: true)
    private static let wheatFieldRedRose = Theme("wheatFieldRedRose", blurEffect: true)
    private static let autumnLake = Theme("autumnLake", blurEffect: true)
    private static let fullmoonOcean = Theme("fullmoonOcean", blurEffect: true)
    private static let lakeSunrise2 = Theme("lakeSunrise2", blurEffect: true)
    private static let oceansunrise2 = Theme("oceansunrise2", blurEffect: true)
    private static let redmoon = Theme("redmoon", blurEffect: true)
    private static let snowMountainLake = Theme("snowMountainLake", blurEffect: true)
    private static let starrySunrise = Theme("starrySunrise", blurEffect: true)
    private static let sunsetMountains3 = Theme("sunsetmountains3", blurEffect: true)
    private static let mountainValley = Theme("mountainValley", blurEffect: true)
    static let nightStarrySkies = Theme("nightStarrySkies", blurEffect: true)
    private static let desertNight = Theme("desertNight", blurEffect: true)
    private static let oceanSunrise = Theme("oceanSunrise", blurEffect: true)
    private static let lushForestSunrise = Theme("lushForestSunrise", blurEffect: true)
    private static let sunriseCliff = Theme("sunriseCliff", blurEffect: true)
    private static let heavenStairway = Theme("heavenStairway", blurEffect: true)
    private static let lakeSunset = Theme("lakeSunset", blurEffect: true)
    private static let lightHouse = Theme("lightHouse", blurEffect: true)
    private static let doveSkies = Theme("doveSkies", blurEffect: true)
    private static let wheatField = Theme("wheatField", blurEffect: true)
    private static let JesusOnCross = Theme("JesusOnCross", blurEffect: true)
    private static let JesusOnWater = Theme("JesusOnWater", blurEffect: true)
    private static let JesusHealing = Theme("JesusHealing", blurEffect: true)
    private static let JesusPraying = Theme("JesusPraying", blurEffect: true)
    private static let JesusRisen = Theme("JesusRisen", blurEffect: true)
    private static let warriorAngel = Theme("warriorAngel", blurEffect: true)
    private static let countryNightSky = Theme("countryNightSky", blurEffect: true)
    private static let mountainLandscape = Theme("mountainLandscape")
    private static let heavenly = Theme("heavenly", blurEffect: true)
    private static let JesusHeaven = Theme("JesusHeaven", blurEffect: true)
    private static let majesticNight = Theme("majesticNight")
    private static let pinkHueMountain = Theme("pinkHueMountain", blurEffect: true)
    private static let sunsetMountain = Theme("sunsetMountain", blurEffect: true)
    static let starryNight = Theme("starryNight", blurEffect: true)
    private static let peacefulMountainNight = Theme("peacefulMountainNight", blurEffect: true)
    private static let lakeTrees = Theme("lakeTrees", blurEffect: true)
    private static let sereneMountain = Theme("sereneMountain", blurEffect: true)
    private static let flowingRiver = Theme("flowingRiver", blurEffect: true)
    private static let breathTakingSunset = Theme("breathTakingSunset", blurEffect: true)
    private static let autumnTrees = Theme("autumntrees", isPremium: false, blurEffect: true, fontColorString: "white")
    private static let cross = Theme("cross", isPremium: false)
    private static let lion = Theme("lion", mode: .light, isPremium: false)
    static let longroadtraveled = Theme("longroadtraveled")
    private static let moon = Theme("moon")
    private static let rainbow = Theme("rainbow")
    private static let space = Theme("space", mode: .light)
    private static let stars = Theme("stars", mode: .light)
    private static let summerbeach = Theme("summerbeach", blurEffect: true)
    private static let canyons = Theme("canyons")
    private static let talltrees = Theme("talltrees",  mode: .light, blurEffect: true)
    private static let luxurydrive = Theme("luxurydrive")
    private static let beautifulsky = Theme("beautifulsky")
    private static let desertsky = Theme("desertSky", mode: .light, blurEffect: true)
    private static let gorgeousmoon = Theme("gorgeousmoon")
    private static let plantgreen = Theme("plantgreen")
    private static let fogroad = Theme("fogroad", blurEffect: true)
    private static let greenplants = Theme("greenPlants",blurEffect: true)
    private static let trippy = Theme("trippy",blurEffect: true)
    private static let landingView1 = Theme("landingView1",blurEffect: true)
    static let landingView2 = Theme("landingView2",blurEffect: true)
    static let highway = Theme("highway",blurEffect: true)
    static let lakeMountain = Theme("lakeMountain",blurEffect: true)
    static let lakeHills = Theme("lakeHills",isPremium: false,blurEffect: true)
    static let sandOcean = Theme("sandOcean",blurEffect: true)
    static let citynight = Theme("citynight",blurEffect: false)
    static let woodnight = Theme("woodnight",blurEffect: true)
    static let forestwinter = Theme("forestwinter",blurEffect: false)
    static let sunset1 = Theme("sunset1",blurEffect: false)
    static let sunset2 = Theme("sunset2",blurEffect: false)
    static let sunset3 = Theme("sunset3",isPremium: false,blurEffect: false)
    static let sunset4 = Theme("sunset4",blurEffect: true)
    static let sunset5 = Theme("sunset5",blurEffect: false)
    static let moonlight2 = Theme("moonlight2",isPremium: false)
    static let icegreenmountain = Theme("icegreenmountain",blurEffect: true)
    static let chicago = Theme("chicago",blurEffect: false)
    static let gorgeous = Theme("gorgeous",blurEffect: true)//, fontColorString: "gold")
    static let kitty = Theme("kitty",blurEffect: true)
    static let meercat = Theme("meercat",blurEffect: true)
    static let taicitylights = Theme("taicitylights",blurEffect: true)
    static let safari = Theme("safari",blurEffect: true)
    static let aurora = Theme("aurora",blurEffect: false)
    static let sereneMountain2 = Theme("sereneMountain2",blurEffect: true)
}




import FirebaseStorage
import FirebaseFirestore
import UIKit

class ImageLoader {
    let storage = Storage.storage()
    
    func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            completion(UIImage(data: data))
        }.resume()
    }
    
    func saveImageToDevice(image: UIImage, imageName: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(imageName).jpg")
        
        do {
            try data.write(to: fileURL)
            print("Image saved to device at: \(fileURL)")
            return fileURL
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func loadImageFromDevice(imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(imageName).jpg")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        } else {
            print("Image not found at path: \(fileURL.path)")
            return nil
        }
    }
    
    func saveImageMetadataToFirestore(imageName: String, downloadURL: URL) {
        let db = Firestore.firestore()
        db.collection("userImages").addDocument(data: [
            "name": imageName,
            "url": downloadURL.absoluteString
        ]) { error in
            if let error = error {
                print("Error saving metadata: \(error.localizedDescription)")
            } else {
                print("Metadata saved for image \(imageName)")
            }
        }
    }
    
    func fetchImageMetadata(completion: @escaping ([(name: String, url: URL)]) -> Void) {
        let db = Firestore.firestore()
        db.collection("userImages").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("Error fetching metadata: \(String(describing: error))")
                return
            }
            
            var imageData: [(name: String, url: URL)] = []
            
            for document in documents {
                let data = document.data()
                if let name = data["name"] as? String,
                   let urlString = data["url"] as? String,
                   let url = URL(string: urlString) {
                    imageData.append((name: name, url: url))
                }
            }
            
            completion(imageData)
        }
    }
    
    func downloadAndSaveImagesLocally(imageData: [(name: String, url: URL)]) {
        for data in imageData {
            downloadImage(from: data.url) { [weak self] image in
                if let image = image {
                    let savedURL = self?.saveImageToDevice(image: image, imageName: data.name)
                    if let savedURL = savedURL {
                        print("Image \(data.name) saved locally at \(savedURL)")
                    }
                }
            }
        }
    }
    
    func fetchImage(imageName: String, url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check if the image exists locally
        if let localImage = loadImageFromDevice(imageName: imageName) {
            print("Loaded image from local storage: \(imageName)")
            completion(localImage)
        } else {
            // Download the image from Firebase if not found locally
            downloadImage(from: url) { [weak self] downloadedImage in
                if let downloadedImage = downloadedImage {
                    // Save the downloaded image locally for future use
                    _ = self?.saveImageToDevice(image: downloadedImage, imageName: imageName)
                    print("Downloaded and saved image: \(imageName)")
                    completion(downloadedImage)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
