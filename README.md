# PostgresExtension for Swift

This package allows you to write Postgres Functions and Aggregations in Swift.

Those functions can accept different datatypes as inputs (including raw arguments or tuples) and return individual values (see `PGDatumRepresentable`) or complex tuples (see `PGTuple(type: String, values: InlineArray<N, PGDatum?>)`).

The package works best in combination with Embedded Swift. This provides the widest compatibility for writing Postgres Extensions across different platforms.

For example, due to how Postgres' concurrency model works internally, it's not safe to write Postgres Extensions for Mac in Swift, or even at all. In practice though, Embedded Swift works well.

If you do need to use "fully-fledged" (non-Embedded) Swift, Linux would be a better platform to do it on.

## Getting Started

To write a Postgres Function or Aggregate in Swift, you should first create a Swift Package:

```
mkdir MySwiftPackage
cd MySwiftPackage
swift package init
```

Then update `Package.swift` to include `PostgresExtension`, and set the library type to `.dynamic`:

```
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "MySwiftPackage",
            type: .dynamic, // set the library type to `.dynamic`
            targets: ["MySwiftPackage"]
        )
    ],
    dependencies: [
        .package(name: "PostgresExtension", url: "https://github.com/ephemer/PostgresExtension", from: "0.0.1")
    ],
    targets: [
        .target(
            name: "MySwiftPackage",
            dependencies: [
                .target(name: "PostgresExtension")
            ]
        ),
        ...
    ]
    ...
)
```

The rest of this README assumes you are writing a `.swift` file within `Sources/MySwiftPackage`.


## Postgres Functions

Reference: https://www.postgresql.org/docs/18/xfunc-c.html


### Defining and building

Here's a "getting started" function for you to try. It simply adds two integers and returns the result.

Note that you must always define a matching `pg_finfo` function (e.g. `pg_finfo_my_func_name`) for the function you are defining and return PG_FUNCTION_INFO_V1 from it.

```SomeFunc.swift
@_cdecl("pg_finfo_some_func")
public func pg_finfo_someFunc() -> UnsafeRawPointer {
    PG_FUNCTION_INFO_V1
}

@_cdecl("some_func")
public func someFunc(fcinfo: FunctionCallInfo) -> PGDatum {
    guard
        let a = fcinfo.getArg(0)?.uint32,
        let b = fcinfo.getArg(1)?.uint32
    else {
        return 0
    }

    let result = a + b
    return result.pgDatum // we will come back to this later
}
```

Then build and install your Package. The recommended way to do this is via a Makefile: copy `Makefile.example` from this repository into your Package directory and rename it to `Makefile`.

*Note that the `Makefile` (without the `.example` extension) in this repository is used internally by to test builds. It's incomplete for the purpose of building and installing into Postgres!*

With a `Makefile` set up correctly in your Swift package, you can just run `make` in your Package directory to build and install the built product into Postgres' library directory.


### Using the function

Define a Postgres function in SQL as follows:

```
CREATE OR REPLACE FUNCTION some_func(
        a   unsigned int,
        b   unsigned int
)
        RETURNS unsigned int
        AS 'libMySwiftPackageName', 'some_func'
        LANGUAGE C
        IMMUTABLE 
        PARALLEL RESTRICTED;
```

You can then call it:

```
SELECT some_func(1, 1);
```

You should see the result of your first Postgres Function written in Swift!


### Nullability

It's possible to return `NULL` from your Swift functions back to Postgres. Postgres expects you to set `isnull` to true on `fcinfo` when you do though, which can be cumbersome and error prone with complex control flow.

I use the following pattern to simplify this:

```
@_cdecl("some_func")
public func someFunc(fcinfo: FunctionCallInfo) -> PGDatum {
    guard let result = someFuncImpl(fcinfo: fcinfo) else {
        fcinfo.pointee.isnull = true
        return .void
    }

    return result
}

private func someFuncImpl(fcinfo: FunctionCallInfo) -> PGDatum? {
    guard
        // convert a Postgres `timestamp` type into a Unix epoch timestamp in milliseconds:
        let t = fcinfo.getArg(0)?.toUnixTimestamp(),
        let duration = fcinfo.getArg(1)?.int32,
        let someType = fcinfo.getArg(2)?.uint8,
        let someId = fcinfo.getArg(3)?.string
    else {
        nil
    }

    return ...
}
```



## Aggregations

Reference: https://www.postgresql.org/docs/18/sql-createaggregate.html

To write a Postgres aggregation, you will need to define a state transition function and a finalize function:

```
CREATE OR REPLACE FUNCTION my_agg(
        state      internal,
        t          timestamp,
        duration   int,
        some_type  smallint,
        some_id    text
)
        RETURNS internal
        AS 'libMySwiftPackageName', 'my_agg'
        LANGUAGE C
        IMMUTABLE 
        PARALLEL RESTRICTED;

CREATE OR REPLACE FUNCTION my_agg_finalize(internal)
        RETURNS performance_stats
        AS 'libPerformanceAnalysis', 'my_agg_finalize'
        LANGUAGE C
        IMMUTABLE 
        PARALLEL RESTRICTED;
```

... and then combine the two in an aggregate definition:

```
CREATE OR REPLACE AGGREGATE do_agg(
        t          timestamp,
        duration   int,
        some_type  smallint,
        some_id    text
)
(
        SFUNC = my_agg,
        STYPE = internal,
        FINALFUNC = my_agg_finalize,
        FINALFUNC_MODIFY = READ_ONLY
);
```

Note the aggregate input types match the state function (`my_agg`) other than the initial `state` parameter with type `internal`. You can use a Swift type for this.