default:
    just --list

prepare:
    zigup 0.14.0-dev.2851+b074fb7dd

debug: 
    zig build

run:
    zig build -Doptimize=Debug run

web:
    zig build
    emrun --browser chrome ./web/test.html

release:
    zig build -Doptimize=ReleaseSafe run

package: 
    zig build -Doptimize=ReleaseSafe

test: 
    zig build test

clean:
    rm -r ./.zig-cache ./zig-out
