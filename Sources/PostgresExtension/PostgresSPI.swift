import CPostgres

public struct PostgresSPI {
    // private let triggerData: UnsafeMutablePointer<TriggerData>?
    internal init(/* triggerData: UnsafeMutablePointer<TriggerData>? */) {
        // self.triggerData = triggerData
    }

    public static func query<let N: Int>(_ query: StaticString) -> Cursor<N> {
        return PostgresSPI(/* triggerData: nil */).query(query)
    }

    public func query<let N: Int>(_ query: StaticString) -> Cursor<N> {
        guard SPI_connect() == SPI_OK_CONNECT else {
            preconditionFailure("SPI_connect failed")
        }

        // if let triggerData {
        //     // Makes transition table accessible to SPI queries
        //     guard SPI_register_trigger_data(triggerData) == SPI_OK_TD_REGISTER else {
        //         preconditionFailure("SPI_register_trigger_data failed")
        //     }
        // }

        let ret = SPI_execute(query.utf8Start, true, 0)
        if ret != SPI_OK_SELECT {
            preconditionFailure("SPI_execute failed")
        }

        guard let tupdesc = SPI_tuptable.pointee.tupdesc else {
            preconditionFailure("Expected a tuple descriptor to exist")
        }

        return Cursor<N>(tupdesc: tupdesc)
    }
    
    public func execute(_ query: String) -> Bool {
        guard SPI_connect() == SPI_OK_CONNECT else {
            preconditionFailure("SPI_connect failed")
        }

        // if let triggerData {
        //     // Makes transition table accessible to SPI queries
        //     guard SPI_register_trigger_data(triggerData) == SPI_OK_TD_REGISTER else {
        //         preconditionFailure("SPI_register_trigger_data failed")
        //     }
        // }

        let ret = SPI_execute(query, false, 0) // read_only = false for INSERT/UPDATE/DELETE
        SPI_finish()
        
        return ret == SPI_OK_INSERT || ret == SPI_OK_UPDATE || ret == SPI_OK_DELETE
    }
}


public struct Cursor<let N: Int>: Sequence, IteratorProtocol {
    var i = 0
    let attributeCount: Int32

    let tupdesc: TupleDesc
    init(tupdesc: TupleDesc) {
        self.tupdesc = tupdesc
        attributeCount = tupdesc.pointee.natts
        assert(attributeCount == N)
    }

    func makeIterator() -> some IteratorProtocol {
        return self
    }

    mutating public func next() -> InlineArray<N, PGDatum?>? {
        if i >= SPI_processed {
            SPI_finish()
            return nil
        }

        let tuple = SPI_tuptable.pointee.vals[i]
        let result = withUnsafeTemporaryAllocation(of: UInt.self, capacity: N, { datumValues in
            withUnsafeTemporaryAllocation(of: Bool.self, capacity: N, { nulls in
                heap_deform_tuple(tuple, tupdesc, datumValues.baseAddress, nulls.baseAddress)

                return InlineArray<N, PGDatum?> { i in
                    if nulls[i] { return nil }
                    return PGDatum(datumValues[i])
                }
            })
        })

        i += 1
        return result
    }
}
