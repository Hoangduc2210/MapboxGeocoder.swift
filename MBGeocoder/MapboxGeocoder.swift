import Foundation
import CoreLocation

public typealias MBGeocodeCompletionHandler = CLGeocodeCompletionHandler // FIXME ObjC

// MARK: - Geocoder

public class MBGeocoder: NSObject,
                         NSURLConnectionDelegate,
                         NSURLConnectionDataDelegate {

    // MARK: - Setup

    private let accessToken: NSString
    
    public init(accessToken: NSString) {
        self.accessToken = accessToken
        super.init()
    }

    private var connection: NSURLConnection?
    private var completionHandler: MBGeocodeCompletionHandler?
    private var receivedData: NSMutableData?
    
    private let MBGeocoderErrorDomain = "MBGeocoderErrorDomain"

    private enum MBGeocoderErrorCode: Int { // FIXME ObjC
        case ConnectionError = -1000
        case HTTPError       = -1001
        case ParseError      = -1002
    }
    
    // MARK: - Public API

    public var geocoding: Bool {
        return (self.connection != nil)
    }
    
    public func reverseGeocodeLocation(location: CLLocation, completionHandler: MBGeocodeCompletionHandler) {
        if (!self.geocoding) {
            self.completionHandler = completionHandler
            let requestString = "https://api.tiles.mapbox.com/v4/geocode/mapbox.places-v1/" +
                "\(location.coordinate.longitude),\(location.coordinate.latitude).json" +
                "?access_token=" + accessToken
            let request = NSURLRequest(URL: NSURL(string: requestString)!)
            self.connection = NSURLConnection(request: request, delegate: self)
        }
    }

//    public func geocodeAddressDictionary(addressDictionary: [NSObject : AnyObject],
//        completionHandler: MBGeocodeCompletionHandler)
    
    public func geocodeAddressString(addressString: String, completionHandler: MBGeocodeCompletionHandler) {
        if (!self.geocoding) {
            self.completionHandler = completionHandler
            let requestString = "https://api.tiles.mapbox.com/v4/geocode/mapbox.places-v1/" +
                addressString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)! +
                ".json?access_token=" + accessToken
            let request = NSURLRequest(URL: NSURL(string: requestString)!)
            self.connection = NSURLConnection(request: request, delegate: self)
        }
    }

//    public func geocodeAddressString(addressString: String, inRegion region: CLRegion, completionHandler: MBGeocodeCompletionHandler)

    public func cancelGeocode() {
        self.connection?.cancel()
        self.connection = nil
    }
    
    // MARK: - NSURLConnection Delegates

    public func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self.connection = nil
        self.completionHandler?(nil, NSError(domain: MBGeocoderErrorDomain,
            code: MBGeocoderErrorCode.ConnectionError.rawValue,
            userInfo: error.userInfo))
    }

    public func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        let statusCode = (response as NSHTTPURLResponse).statusCode
        if (statusCode != 200) {
            self.connection?.cancel()
            self.connection = nil
            self.completionHandler?(nil, NSError(domain: MBGeocoderErrorDomain,
                code: MBGeocoderErrorCode.HTTPError.rawValue,
                userInfo: [ NSLocalizedDescriptionKey: "Received HTTP status code \(statusCode)" ]))
        } else {
            self.receivedData = NSMutableData()
        }
    }
    
    public func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.receivedData!.appendData(data)
    }
    
    public func connectionDidFinishLoading(connection: NSURLConnection) {
        var parseError: NSError?
        let response = NSJSONSerialization.JSONObjectWithData(self.receivedData!, options: nil, error: &parseError) as NSDictionary
        if (parseError != nil) {
            self.completionHandler?(nil, NSError(domain: MBGeocoderErrorDomain,
                code: MBGeocoderErrorCode.ParseError.rawValue,
                userInfo: [ NSLocalizedDescriptionKey: "Unable to parse results" ]))
        } else {
            let features = response["features"] as NSArray
            if (features.count > 0) {
                var results = NSMutableArray()
                for feature in features {
                    if let placemark = MBPlacemark(featureJSON: feature as NSDictionary) {
                        results.addObject(placemark)
                    }
                }
                self.completionHandler?(NSArray(array: results), nil)
            } else {
                self.completionHandler?([], nil)
            }
        }
    }

}

// MARK: - Placemark

public class MBPlacemark: CLPlacemark {

    private var featureJSON: NSDictionary?

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init() {
        super.init()
    }

    internal convenience init?(featureJSON: NSDictionary) {
        var valid = false
        if let geometry = featureJSON["geometry"] as? NSDictionary {
            if (geometry["type"] as? String == "Point") {
                if let coordinates = geometry["coordinates"] as? NSArray {
                    if (featureJSON["place_name"] as? String != nil) {
                        valid = true
                    }
                }
            }
        }
        if (valid) {
            self.init()
            self.featureJSON = featureJSON
        } else {
            self.init()
            self.featureJSON = nil
            return nil
        }
    }

    override public var location: CLLocation! {
        let coordinates = (self.featureJSON!["geometry"] as NSDictionary)["coordinates"] as NSArray

        return CLLocation(latitude:  coordinates[1].doubleValue, longitude: coordinates[0].doubleValue)
    }

    override public var name: String! {
        return self.featureJSON!["place_name"] as String
    }

    override public var addressDictionary: [NSObject: AnyObject]! {
        return [:]
    }

    override public var ISOcountryCode: String! {
        return ""
    }

    override public var country: String! {
        return ""
    }

    override public var postalCode: String! {
        return ""
    }

    override public var administrativeArea: String! {
        return ""
    }

    override public var subAdministrativeArea: String! {
        return ""
    }

    override public var locality: String! {
        return ""
    }

    override public var subLocality: String! {
        return ""
    }

    override public var thoroughfare: String! {
        return ""
    }

    override public var subThoroughfare: String! {
        return ""
    }

    override public var region: CLRegion! {
        return CLRegion()
    }

    override public var inlandWater: String! {
        return ""
    }

    override public var ocean: String! {
        return ""
    }

    override public var areasOfInterest: [AnyObject]! {
        return []
    }

}
