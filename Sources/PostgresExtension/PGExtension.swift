import CPostgres

public let PG_FUNCTION_INFO_V1 = {
    let ptr = UnsafeMutablePointer<Pg_finfo_record>.allocate(capacity: 1)
    ptr.initialize(to: Pg_finfo_record(api_version: 1))
    return UnsafeRawPointer(ptr)
}()
