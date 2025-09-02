POSTGRES_BIN := $(shell which postgres)
PG_INCDIR := $(shell pg_config --includedir-server)
PG_LIBDIR := $(shell pg_config --pkglibdir)

build-mac:
	swift build -c release \
		-Xlinker -lswiftUnicodeDataTables \
		-Xlinker -L"$(shell dirname $(shell swiftly run which swift))/../lib/swift/embedded/arm64-apple-macos" \
		-Xcc -I$(PG_INCDIR) \
		-Xcc -I/opt/homebrew/include \
		-Xlinker -bundle \
		-Xlinker -bundle_loader \
		-Xlinker $(POSTGRES_BIN) \
		-Xswiftc -enable-experimental-feature -Xswiftc Embedded

build-linux:
	swift build -c release \
		-Xlinker -lswiftUnicodeDataTables \
		-Xlinker -L"$(shell dirname $(shell swiftly run which swift))/../lib/swift/embedded/x86_64-unknown-linux-gnu" \
		-Xcc -I$(PG_INCDIR) \
		-Xswiftc -enable-experimental-feature -Xswiftc Embedded

.PHONY: build-mac build-linux
