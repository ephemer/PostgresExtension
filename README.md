# PostgresExtension for Swift

This package allows you to write Postgres Functions and Aggregations in Swift.

Those functions can accept different data types as inputs (see `PGDatum.swift`) and return individual values (see `PGDatumRepresentable`) or complex tuples (see `PGTuple(type: String, values: InlineArray<N, PGDatum?>)`).


### Embedded Swift

The package works best in combination with [Embedded Swift](https://docs.swift.org/embedded/documentation/embedded/). This provides the widest compatibility for writing Postgres Extensions across different platforms.

It will also give you a much smaller library with effectively no external dependencies. In my experience, the resulting functions will also be slightly faster (probably due to ObjC interop and bridging being disabled).

Due to how Postgres' concurrency model works internally, it's [not safe](https://forums.swift.org/t/how-to-prevent-crash-due-to-swift-runtime-initializing-os-log-on-macos/81842) to write Postgres Extensions for Mac in (esp. regular) Swift or, theoretically, even at all. In practice, the simple runtime employed by Embedded Swift works reliably and will not cause you issues, unless you're doing something quite unusual.

Using regular (non-Embedded) Swift is theoretically possible on Linux, but that use case is not recommended or supported.


## Getting Started

To write a Postgres Function or Aggregate in Swift, first create a Swift Package:

```
mkdir MySwiftPackage
cd MySwiftPackage
swift package init
```

Then update `Package.swift` to depend on `PostgresExtension`, and set the library type to `.dynamic`:

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
            type: .dynamic, // without this, you'll get no library to install into Postgres
            targets: ["MySwiftPackage"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ephemer/PostgresExtension", from: "0.0.1")
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


### Complex Types

You can accept and process basically any type definable in Postgres, including user-defined ones:

```
CREATE TYPE custom_hand_type AS ENUM (
  'left',
  'right'
);

CREATE TYPE my_custom_return_type AS (
    a            smallint,
    b            smallint,
    whatever     float4,
    you          float4,
    like         float4
);

CREATE OR REPLACE FUNCTION some_func(
        time        timestamp,
        my_id       text,
        proportion  float4,
        hand        custom_hand_type
)
        RETURNS my_custom_return_type
        AS 'libMySwiftPackageName', 'some_func'
        LANGUAGE C
        IMMUTABLE 
        PARALLEL RESTRICTED;
```

```
@_cdecl("some_func")
public func someFunc(fcinfo: FunctionCallInfo) -> PGDatum {
    guard
        // converts it into a Unix epoch timestamp in milliseconds:
        let t = fcinfo.getArg(0)?.toUnixTimestamp(), // UInt

        // get a Swift string
        let myId = fcinfo.getArg(1)?.string, // String

        // Floats (in postgres: float4) and Doubles (float8) are also supported
        let proportion = fcinfo.getArg(2)?.float, // Float

        // getting the underlying enum case is more involved; see also below.
        let handOid = event[1]?.uint64 // UInt64
    else {
        return .void
    }

    guard let hand = Hand(oid: handOid) else {
        assertionFailure("Could not decode Hand enum")
        return .void
    }

    return PGTuple(type: "my_custom_return_type", values: [
        Int16(123).pgDatum,
        Int16(456).pgDatum,
        Float(99.9).pgDatum,
        Float(42.0).pgDatum,
        Float(-1).pgDatum,
    ]).toDatum()
}


private enum Hand: String {
    case left, right

    init?(oid: UInt64) {
        guard
            let string = String(postgresEnumObjectID: oid),
            let result = Hand(rawValue: string)
        else {
            return nil
        }

        self = result
    }
}
```


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
    guard ... else {
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
        RETURNS int8
        AS 'libMySwiftPackageName', 'my_agg_finalize'
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

Note the aggregate input types match the state function (`my_agg`) other than the initial `state` parameter with type `internal`. You can use a Swift type for this (a `class` is easiest: if you need a `struct`, wrap it in a `class`).

Here's a simple but full example:

```
import PostgresExtension

// It's not necessary to use a `class` type if your state is just an Int like this.
// You can take this example and build whatever complexity you need on top of it though.
final class AggregationState {
    var sum = 0
    init() {}
}

private func getOrCreateAggregationState(_ fcinfo: FunctionCallInfo) -> AggregationState? {
    if let state: AggregationState? = fcinfo.getAggregationState()?.takeUnretainedValue() {
        return state
    }

    return AggregationState()
}

@_cdecl("pg_finfo_my_agg")
public func pg_finfo_my_agg() -> UnsafeRawPointer {
    PG_FUNCTION_INFO_V1
}

@_cdecl("my_agg")
public func my_agg(fcinfo: FunctionCallInfo) -> UInt {
    guard let result = my_agg_impl(fcinfo: fcinfo) else {
        fcinfo.pointee.isnull = true
        return 0
    }

    return result.datum
}

private func my_agg_impl(fcinfo: FunctionCallInfo) -> PGDatum? {
    guard let state = getOrCreateAggregationState(fcinfo) else {
        return nil // it's ok – we will return `nil` for this result
    }

    // Note that `state` is in arg[0], so start from getArg(1)!
    guard let someValue = fcinfo.getArg(1)?.int64 else {
        // We can't process this partial result. This can be a gotcha.
        // Always return `state` and not `nil` unless you want to nuke the result and make it `NULL`!
        return PGDatum(
            UInt(bitPattern: Unmanaged<AggregationState>.passRetained(state).toOpaque())
        )
    }

    state.sum += Int(someValue)

    return PGDatum(
        // use `passRetained` to ensure reference counts are balanced
        UInt(bitPattern: Unmanaged<AggregationState>.passRetained(state).toOpaque())
    )
}


@_cdecl("pg_finfo_my_agg_finalize")
public func pg_finfo_my_agg_finalize() -> UnsafeRawPointer {
    PG_FUNCTION_INFO_V1
}

@_cdecl("my_agg_finalize")
public func my_agg_finalize(fcinfo: FunctionCallInfo) -> UInt {
    guard let result = my_agg_finalize_impl(fcinfo: fcinfo) else {
        fcinfo.pointee.isnull = true
        return 0
    }

    return result.datum
}

private func my_agg_finalize_impl(fcinfo: FunctionCallInfo) -> PGDatum? {
    guard let state: AggregationState = fcinfo.getAggregationState()?.takeRetainedValue() else {
        return nil
    }

    return state.sum.pgDatum
}
```