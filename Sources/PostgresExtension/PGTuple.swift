import CPostgres

public struct PGTuple: ~Copyable {
    private let tupleDescriptor: TupleDesc
    private var heapTuple: HeapTupleData

    public init?(_ datum: Datum) {
        guard let detoastedDatum = pg_detoast_datum(UnsafeMutablePointer<varlena>(bitPattern: datum)) else {
            return nil
        }

        let tupHeader = UnsafeMutableRawPointer(detoastedDatum).assumingMemoryBound(to: HeapTupleHeaderData.self)
        let fields = get_datum_tuple_fields(tupHeader)
        let typeId = fields.datum_typeid
        let typmod = fields.datum_typmod

        guard let tupleDescriptor = lookup_rowtype_tupdesc(typeId, typmod) else {
            assertionFailure("failed to get tuple descriptor")
            return nil
        }

        self.tupleDescriptor = tupleDescriptor

        var heapTuple = HeapTupleData()
        heapTuple.t_len = detoastedDatum.varSize
        heapTuple.t_data = tupHeader
        self.heapTuple = heapTuple
    }

    /// Used to keep the same tuple type and header, while updating its contents
    internal mutating func update(_ datum: Datum) {
        guard let detoastedDatum = pg_detoast_datum(UnsafeMutablePointer<varlena>(bitPattern: datum)) else {
            return
        }

        let tupHeader = UnsafeMutableRawPointer(detoastedDatum).assumingMemoryBound(to: HeapTupleHeaderData.self)
        heapTuple.t_data = tupHeader
    }

    public init<let N: Int>(type: String, values: InlineArray<N, PGDatum?>) {
        let returnTypeID = TypenameGetTypid(type)
        guard let returnTupleDesc = lookup_rowtype_tupdesc(returnTypeID, -1) else {
            preconditionFailure("failed to get tuple descriptor for `performance_stats` type")
        }

        let returnValues = InlineArray<N, Datum> { i in values[i]?.datum ?? 0 }
        let returnNulls = InlineArray<N, Bool> { i in values[i] == nil }

        self.tupleDescriptor = returnTupleDesc

        // let heapTuple = heap_form_tuple(returnTupleDesc, returnValues, returnNulls).pointee

        // .span.withUnsafeMutablePointer works around a compiler crash passing InlineArray as a pointer
        let heapTuple = returnNulls.span.withUnsafeBufferPointer { nulls in
            returnValues.span.withUnsafeBufferPointer { ret in
                heap_form_tuple(returnTupleDesc, ret.baseAddress, nulls.baseAddress).pointee
            }
        }

        self.heapTuple = heapTuple
    }

    consuming public func toDatum() -> PGDatum {
        return PGDatum(HeapTupleHeaderGetDatum(heapTuple.t_data))
    }

    mutating public func get(oneIndexed i: Int32) -> PGDatum? {
        var isNull = false
        let datum = fastgetattr(&heapTuple, i, tupleDescriptor, &isNull)
        return isNull ? nil : PGDatum(datum)
    }

    deinit {
        if tupleDescriptor.pointee.tdrefcount >= 0 {
            DecrTupleDescRefCount(tupleDescriptor)
        }
    }
}