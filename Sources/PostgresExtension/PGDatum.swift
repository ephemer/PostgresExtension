import CPostgres

public struct PGDatum: Sendable {
    private let rawDatum: CPostgres.Datum

    public init(_ rawDatum: CPostgres.Datum) {
        self.rawDatum = rawDatum
    }

    public var int64: Int64 { Int64(DatumGetInt64(rawDatum)) }
    public var uint64: UInt64 { UInt64(DatumGetUInt64(rawDatum)) }
    
    public var uint32: UInt32 { DatumGetUInt32(rawDatum) }
    public var int32: Int32 { DatumGetInt32(rawDatum) }

    public var int16: Int16 { DatumGetInt16(rawDatum) }
    public var uint16: UInt16 { DatumGetUInt16(rawDatum) }

    public var int8: Int8 { DatumGetChar(rawDatum) }
    public var uint8: UInt8 { DatumGetUInt8(rawDatum) }

    public func toUnixTimestamp() -> UInt {
        let EPOCH_DIFF = UInt((POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * SECS_PER_DAY) * 1000
        return (rawDatum / 1_000) + EPOCH_DIFF
    }

    public var datum: UInt {
        return rawDatum
    }

    // better not to make this public. instead, convert to a real type internally first
    internal func assumingMemoryBound<T>(to: T.Type) -> UnsafeMutablePointer<T>? {
        return UnsafeMutableRawPointer(bitPattern: self.rawDatum)?.assumingMemoryBound(to: T.self)
    }
}

extension UnsafeMutablePointer<varlena> {
    var varSize: UInt32 { varsize_length(self) }
    var varHeaderSize: UInt32 { UInt32(MemoryLayout<Int32>.alignment) } // VARHDRSZ
}

public protocol PGDatumRepresentable {
    var pgDatum: PGDatum { get }
}

extension PGDatum: PGDatumRepresentable {
    public var pgDatum: PGDatum { self }
}

extension Double: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(Float8GetDatum(self)) }
}

extension Float: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(Float4GetDatum(self)) }
}

extension Int64: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(Int64GetDatum(self)) }
}

extension Int32: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(Int32GetDatum(self)) }
}

extension UInt32: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(UInt32GetDatum(self)) }
}

extension Int16: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(Int16GetDatum(self)) }
}

extension UInt16: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(UInt16GetDatum(self)) }
}

extension Int8: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(CharGetDatum(self)) }
}

extension Bool: PGDatumRepresentable {
    public var pgDatum: PGDatum { PGDatum(BoolGetDatum(self)) }
}
