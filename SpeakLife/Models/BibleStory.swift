//
//  BibleStory.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 7/3/24.
//

import Foundation

//
//[
//    {"id":"1",
//"verse_id":"1001001",
//"story":"God Creates the World",
//"verses_1":"Genesis 1:1",
//"verses_2":"",
//"verses_3":"",
//"verses_4":""
//    }
//]


//let headers = [
//    "x-rapidapi-key": "333338f3f3msh5c99f092f9c14dcp18867ejsna643d6e58f43",
//    "x-rapidapi-host": "iq-bible.p.rapidapi.com"
//]
//
//let request = NSMutableURLRequest(url: NSURL(string: "https://iq-bible.p.rapidapi.com/GetStories?language=english")! as URL,
//                                        cachePolicy: .useProtocolCachePolicy,
//                                    timeoutInterval: 10.0)
//request.httpMethod = "GET"
//request.allHTTPHeaderFields = headers
//
//let session = URLSession.shared
//let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
//    if (error != nil) {
//        print(error as Any)
//    } else {
//        let httpResponse = response as? HTTPURLResponse
//        print(httpResponse)
//    }
//})
//
//dataTask.resume()

// MARK: - BibleStory
struct BibleStory: Codable {
    let id, verseID, story, verses1: String
    let verses2, verses3, verses4: String

    enum CodingKeys: String, CodingKey {
        case id
        case verseID = "verse_id"
        case story
        case verses1 = "verses_1"
        case verses2 = "verses_2"
        case verses3 = "verses_3"
        case verses4 = "verses_4"
    }
}

typealias BibleStories = [BibleStory]
