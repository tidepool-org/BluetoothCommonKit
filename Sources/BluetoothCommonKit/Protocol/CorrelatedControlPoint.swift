//
//  CorrelatedControlPoint.swift
//  BluetoothCommonKit
//
//  Created by LoopKit Authors on 2026-09-25.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import Foundation

/// A control point whose responses identify the request they answer. Unlike `ControlPoint`, a request
/// leaves the queue when it is sent, so it cannot be sent twice, and its response is matched to the
/// request the caller has in flight rather than to the queue head.
public protocol CorrelatedControlPoint: AnyObject {
    associatedtype Completion
    associatedtype Response

    var lockedRequestQueue: Locked<[(request: Data, completion: Completion?)]> { get }

    func procedureIDForRequest(_ request: Data) -> ProcedureID

    /// Decodes `response` when it answers `request`; nil when it answers another request.
    func result(forResponse response: Data, to request: Data) -> Response?
}

public extension CorrelatedControlPoint {
    var hasRequestToSend: Bool {
        !lockedRequestQueue.value.isEmpty
    }

    func appendToRequestQueue(_ request: Data, completion: Completion?) {
        lockedRequestQueue.mutate { requestQueue in
            requestQueue.append((request, completion))
        }
    }

    func dequeueNextRequest() -> (request: Data, completion: Completion?)? {
        var nextRequest: (request: Data, completion: Completion?)?
        lockedRequestQueue.mutate { requestQueue in
            if !requestQueue.isEmpty {
                nextRequest = requestQueue.removeFirst()
            }
        }
        return nextRequest
    }

    /// Empties the queue, returning its requests for the caller to fail, e.g. after a disconnect.
    func drainRequestQueue() -> [(request: Data, completion: Completion?)] {
        var drainedRequests: [(request: Data, completion: Completion?)] = []
        lockedRequestQueue.mutate { requestQueue in
            drainedRequests = requestQueue
            requestQueue.removeAll()
        }
        return drainedRequests
    }
}
