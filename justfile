default:
    just --list

prepare:
    zigup 0.14.0

build:
    zig build -Doptimize=Debug

run:
    zig build
    emrun --browser chrome ./web/test.html

clean:
    rm -r ./.zig-cache ./zig-out
