#!/bin/bash

BUILDPACK_HOME="/buildpack"

setUp() {
    OUTPUT_DIR="$(mktemp -d "$SHUNIT_TMPDIR/output.XXXX")"
    STD_OUT="${OUTPUT_DIR}/stdout"
    STD_ERR="${OUTPUT_DIR}/stderr"
    BUILD_DIR="${OUTPUT_DIR}/build"
    CACHE_DIR="${OUTPUT_DIR}/cache"
    ENV_DIR="${OUTPUT_DIR}/env"
    mkdir -p "$OUTPUT_DIR" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR"
    echo 2 > "$ENV_DIR/GO_BUILDPACK_VERSION"
}

tearDown() {
    rm -rf "$OUTPUT_DIR"
}

fixture() {
    local fixture="${1}"
    echo "* fixture: $fixture"
    local fp="$BUILDPACK_HOME/test/fixtures/v2/$fixture"
    tar -cf - -C "$fp" . | tar -x -C "$BUILD_DIR"
}

output() {
    echo "=== stdout"
    cat "$STD_OUT"
    echo "=== stderr"
    cat "$STD_ERR"
}

# shellcheck disable=SC2119,SC2120
compile() {
    want="$1"
    if [ -z "$want" ]; then
	want=0
    fi
    "$BUILDPACK_HOME/bin/compile" "$BUILD_DIR" "$CACHE_DIR" "$ENV_DIR" >"$STD_OUT" 2>"$STD_ERR"

    got=$?
    if ! assertEquals "got compile status $got, want $want" "$want" "$got"; then
	output
    fi
}

check() {
    cmd="fixture"
    if [ -n "$1" ]; then
	cmd="$1"
    fi
    "$BUILD_DIR/bin/$cmd" >"$STD_OUT" 2>"$STD_ERR"
    got=$?
    if ! assertEquals "got fixture run status $got, want 0" 0 "$got"; then
	output
    fi
}

assertStdout() {
    assertContains "$(< "$STD_OUT")" "$1"
}

assertNoStdout() {
    assertNotContains "$(< "$STD_OUT")" "$1"
}

assertStderr() {
    assertContains "$(< "$STD_ERR")" "$1"
}

testBasic() {
    fixture basic

    compile

    assertStdout "version go1.14.1 requested via default"
    assertStdout "fetching"

    check
}

testDeps() {
    fixture deps

    compile

    assertStdout "version go1.14.1 requested via default"
    assertStdout "fetching"

    check
}

testVendor() {
    fixture deps

    compile

    assertStdout "version go1.14.1 requested via default"
    assertStdout "fetching"

    check
}

testMultiMain() {
    fixture multi-main

    compile

    check fixture1
    check fixture2
    check fixture3
}

testGoModInstall() {
    fixture multi-main

    echo "// +heroku install ./cmd/fixture1 ./cmd/fixture2" >> "$BUILD_DIR/go.mod"

    compile

    check fixture1
    check fixture2

    if [ -e "$BUILD_DIR/bin/fixture3" ]; then
	fail "wanted bin/fixture3 to not exist"
    fi
}

testGoModVersion() {
    fixture basic

    echo "// +heroku goVersion go1.14" >> "$BUILD_DIR/go.mod"

    compile

    assertStdout "version go1.14 requested via go.mod"

    check
}

testGOVERSION() {
    fixture basic

    echo go1.14 > "$ENV_DIR/GOVERSION"

    compile

    assertStdout "version go1.14 requested via GOVERSION"

    check
}

testCache() {
    fixture basic

    compile
    assertStdout "fetching"
    check

    compile
    assertNoStdout "fetching"
    check
}

testCacheClearOnVersionChange() {
    fixture basic

    compile
    assertNoStdout "clearing cache"
    assertStdout "fetching"
    check

    echo go1.14 > "$ENV_DIR/GOVERSION"

    compile
    assertStdout "clearing cache"
    assertStdout "fetching"
    check
}

testCacheClearOnStackSet() {
    fixture basic

    compile
    check

    STACK=new-stack compile
    assertStdout "fetching"
    check
}

testCacheClearOnStackChange() {
    fixture basic

    STACK=old-stack compile
    check

    STACK=new-stack compile
    assertStdout "clearing cache"
    assertStdout "fetching"
    check
}

testGoTooOld() {
    fixture basic

    echo "// +heroku goVersion go1.13" >> "$BUILD_DIR/go.mod"

    compile 1

    assertStderr "only go1.14 or greater supported"
}

testNoGoMod() {
    fixture basic

    rm "$BUILD_DIR/go.mod"

    compile 1

    assertStderr "go.mod required"
}

source "$(pwd)/test/shunit2.sh"
