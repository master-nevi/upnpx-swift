//
//  SOAPSerialization.swift
//  ControlPointDemo
//
//  Created by David Robles on 12/28/14.
//  Copyright (c) 2014 David Robles. All rights reserved.
//

import Foundation

class SOAPRequestSerializer: AFHTTPRequestSerializer {
    let upnpNamespace: String
    var soapAction = ""
    
    init(upnpNamespace: String) {
        self.upnpNamespace = upnpNamespace
        super.init()
    }
    
    required init(coder aDecoder: NSCoder) {
        self.upnpNamespace = aDecoder.decodeObjectOfClass(SOAPRequestSerializer.self, forKey: "upnpNamespace") as String
        super.init(coder: aDecoder)
    }
        
    override func requestBySerializingRequest(request: NSURLRequest!, withParameters parameters: AnyObject!, error: NSErrorPointer) -> NSURLRequest! {
        var mutableRequest: NSMutableURLRequest = request.mutableCopy() as NSMutableURLRequest
        
        for (field, value) in self.HTTPRequestHeaders {
            if let field = field as? String {
                if request.valueForHTTPHeaderField(field) == nil {
                    if let value = value as? String {
                        mutableRequest.setValue(value, forHTTPHeaderField: field)
                    }
                }
            }
        }
        
        if mutableRequest.valueForHTTPHeaderField("Content-Type") == nil {
            var charSet = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
            mutableRequest.setValue("text/xml; charset=\"\(charSet)\"", forHTTPHeaderField: "Content-Type")
        }
        
        mutableRequest.setValue("\"\(upnpNamespace)#\(soapAction)\"", forHTTPHeaderField: "SOAPACTION")
        
        var body = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        body += "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">"
        body += "<s:Body>"
        body += "<u:\(soapAction) xmlns:u=\"\(upnpNamespace)\">"
        if let parameters = parameters as? NSDictionary {
            for (key, value) in parameters {
                body += "<\(key)>\(value)</\(key)>"
            }
        }
        body += "</u:\(soapAction)>"
        body += "</s:Body></s:Envelope>"
        //        println("swift: \(body)")
        
        mutableRequest.setValue("\(countElements(body.utf8))", forHTTPHeaderField: "Content-Length")
        
        mutableRequest.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        
        return mutableRequest
    }
}

class SOAPResponseSerializer: AFXMLParserResponseSerializer {
    let soapAction: String
    
    init(soapAction: String) {
        self.soapAction = soapAction
        super.init()
    }
    
    required init(coder aDecoder: NSCoder) {
        self.soapAction = aDecoder.decodeObjectOfClass(SOAPResponseSerializer.self, forKey: "soapAction") as String
        super.init(coder: aDecoder)
    }
    
    override func responseObjectForResponse(response: NSURLResponse!, data: NSData!, error: NSErrorPointer) -> AnyObject! {
        if !validateResponse(response as NSHTTPURLResponse, data: data, error: error) {
            if error == nil {
                return nil
            }
        }
        
        var serializationError: NSError?
        var responseObject: AnyObject!
        let xmlParser = SOAPResponseParser()
        
        switch xmlParser.parse(soapResponseData: data) {
        case .Success(let value):
            responseObject = value()
        case .Failure(let error):
            serializationError = error
        }
        
        if serializationError != nil && error != nil {
            error.memory = serializationError!
        }
        
        return responseObject
    }
}
