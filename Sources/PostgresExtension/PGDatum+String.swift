import func CPostgres.get_enum_label
import func CPostgres.pg_text_view
import func CPostgres.PointerGetDatum
import func CPostgres.cstring_to_text_with_len
import func CPostgres.cstring_to_text

public extension PGDatum {
    var string: String {
        String(pgTextDatum: self)
    }
}

public extension String {
    init(pgTextDatum datum: PGDatum) {
        let textView = pg_text_view(datum.datum)
        let newTextBytes = UnsafeBufferPointer(start: textView.data, count: textView.count)
        self = String(copying: UTF8Span(unchecked: newTextBytes.span))
    }
}

public extension String {
    init?(postgresEnumObjectID: UInt64) {
        guard let cString = get_enum_label(postgresEnumObjectID) else {
            return nil
        }

        self = .init(cString: cString)
    }
}

extension String: PGDatumRepresentable {
    public var pgDatum: PGDatum {
        self.utf8.withContiguousStorageIfAvailable({ buf in
            // fast path
            let textPtr = cstring_to_text_with_len(buf.baseAddress, Int32(buf.count))
            return PGDatum(PointerGetDatum(textPtr))
        }) ?? self.withCString { cstr in
            // slower fallback
            let textPtr = cstring_to_text(cstr)
            return PGDatum(PointerGetDatum(textPtr))
        }
    }
}
