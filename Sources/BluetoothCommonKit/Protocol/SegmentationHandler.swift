//
//  SegmentationHandler.swift
//  BluetoothCommonKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol SegmentationHandler: AnyObject {
    var maxRequestSize: Int { get }
    
    var storedResponses: [Data] { get set }
    
    var lockedSegmentCounter: Locked<UInt8> { get set }
    
    var segmentCounter: UInt8 { get set }
    
    func segmentRequest(_ request: Data) -> [Data]
    
    func checkResponseSegment(_ responseSegment: Data) -> Result<Data, DeviceCommError>
    
    func resetSegmentCounter()
}

public extension SegmentationHandler {
    var segmentCounter: UInt8 {
        get {
            return lockedSegmentCounter.value
        }
        set {
            if lockedSegmentCounter.value != newValue {
                // range is 0 to 63
                lockedSegmentCounter.value = newValue % (SegmentationHeader.maxCounterValue + 1)
            }
        }
    }
    
    func segmentRequest(_ request: Data) -> [Data] {
        var tempRequest = Data()
        var segmentedRequests: [Data] = []
        var counter = 0
        let segmentCounterInitialValue = segmentCounter
        while (request.count > maxRequestSize * counter) {
            tempRequest.removeAll()
            let minRange = maxRequestSize*counter
            let maxRange = maxRequestSize*(counter+1)
            var segmentationHeader: UInt8 = (segmentCounter << 2)
            if (segmentCounter == segmentCounterInitialValue) {
                segmentationHeader = segmentationHeader | SegmentationHeader.firstPart.rawValue
            }
            
            if (request.count > maxRange) {
                tempRequest.append(request.subdata(in: minRange..<maxRange))
            } else {
                tempRequest.append(request.subdata(in: minRange..<request.count))
                segmentationHeader = segmentationHeader | SegmentationHeader.lastPart.rawValue
            }
            tempRequest.insert(segmentationHeader, at: 0)
            segmentedRequests.append(tempRequest)
            segmentCounter = segmentCounter + 1
            counter = counter + 1
        }
        
        return segmentedRequests
    }
    
    func checkResponseSegment(_ responseSegment: Data) -> Result<Data, DeviceCommError> {
        let receivedSegmentationHeader = SegmentationHeader(rawValue: responseSegment[responseSegment.startIndex...].to(SegmentationHeader.RawValue.self))

        if receivedSegmentationHeader.isFirstPart {
            // this is a new response
            if receivedSegmentationHeader.isLastPart {
                // Response is complete. Remove the segmentation header and provide the complete reponse
                return .success(Data(responseSegment[responseSegment.startIndex.advanced(by: 1)...]))
            } else {
                // store the response segment to reassemble with remaining segments
                storedResponses.append(responseSegment)
                return .failure(.partialResponse)
            }
        } else {
            // response is a continuation of a previous response
            // find the previous response using the segment counter
            for (index, storedResponse) in storedResponses.enumerated() {
                let storedSegmentationHeader = SegmentationHeader(rawValue: storedResponse[storedResponse.startIndex...].to(UInt8.self))

                if (storedSegmentationHeader.nextCounterValue == receivedSegmentationHeader.counter) {
                    // this is a response segment for this stored response
                    // update the stored segmentation header for future comparison
                    storedResponses[index][0] = receivedSegmentationHeader.rawValue

                    // append the response segment excluding the segmentation header
                    storedResponses[index].append(Data(responseSegment[responseSegment.startIndex.advanced(by: 1)...]))

                    // check if the response is now complete
                    guard receivedSegmentationHeader.isLastPart else {
                        return .failure(.partialResponse)
                    }

                    // Response is complete. Remove the segmentation header and provide the complete reponse
                    let completeResponse = Data(storedResponses[index][responseSegment.startIndex.advanced(by: 1)...])
                    storedResponses.remove(at: index)
                    return .success(completeResponse)
                }
            }

            return .failure(.partialResponse)
        }
    }

    func resetSegmentCounter() {
        segmentCounter = 0
    }
}
