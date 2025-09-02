import CPostgres

public typealias FunctionCallInfo = CPostgres.FunctionCallInfo

extension FunctionCallInfo {
    @inlinable
    public func getArg(_ i: Int32) -> PGDatum? {
        guard i >= 0 && i < pointee.nargs else { return nil }
        guard let arg = get_args(self)?[Int(i)] else { return nil }
        if arg.isnull { return nil }
        return PGDatum(arg.value)
    }

    /// In a PostgreSQL aggregation whose state type is set to `internal`,
    /// this function provides an easy way to get the Unmanaged instance,
    /// assuming you returned the Unmanaged instance in previous aggregation
    /// steps.
    @inlinable
    public func getAggregationState<T : AnyObject>() -> Unmanaged<T>? {
        guard
            let argDatum = getArg(0),
            let rawPtr = UnsafeRawPointer(bitPattern: argDatum.datum)
        else {
            return nil
        }

        return Unmanaged<T>.fromOpaque(rawPtr)
    }
}

// public struct TriggerEvent: OptionSet {
//     public let rawValue: UInt32
//     public init(rawValue: UInt32) {
//         self.rawValue = rawValue
//     }

//     public static let INSERT     = Self(rawValue: UInt32(TRIGGER_EVENT_INSERT))
//     public static let DELETE     = Self(rawValue: UInt32(TRIGGER_EVENT_DELETE))
//     public static let UPDATE     = Self(rawValue: UInt32(TRIGGER_EVENT_UPDATE))
//     public static let TRUNCATE   = Self(rawValue: UInt32(TRIGGER_EVENT_TRUNCATE))
//     public static let OPMASK     = Self(rawValue: UInt32(TRIGGER_EVENT_OPMASK))

//     public static let ROW        = Self(rawValue: UInt32(TRIGGER_EVENT_ROW))
//     public static let BEFORE     = Self(rawValue: UInt32(TRIGGER_EVENT_BEFORE))
//     public static let AFTER      = Self(rawValue: UInt32(TRIGGER_EVENT_AFTER))
//     public static let INSTEAD    = Self(rawValue: UInt32(TRIGGER_EVENT_INSTEAD))
//     public static let TIMINGMASK = Self(rawValue: UInt32(TRIGGER_EVENT_TIMINGMASK))
// }

// extension FunctionCallInfo {
//     public func createSPI(assert triggerAssertions: ((_ triggerEvent: TriggerEvent) -> Bool)? = nil) -> PostgresSPI {
//         guard let triggerAssertions else {
//             return PostgresSPI(triggerData: nil) // transition table data will not be available!
//         }

//         guard
//             let trigdata = UnsafeMutableRawPointer(pointee.context)?.assumingMemoryBound(to: TriggerData.self),
//             trigdata.pointee.type == T_TriggerData
//         else {
//             preconditionFailure("Not called as a TRIGGER function")
//         }

//         let triggerEvent = TriggerEvent(rawValue: trigdata.pointee.tg_event)
//         assert(triggerAssertions(triggerEvent), "Your trigger assertions did not hold true! Ensure your trigger is set up correctly.")
//         return PostgresSPI(triggerData: trigdata)
//     }
// }
