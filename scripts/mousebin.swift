import CoreGraphics
import Foundation

// mousebin — warp the OS cursor to a global point (points, origin top-left).
// CGWarpMouseCursorPosition needs NO accessibility permission, and it triggers
// real CSS :hover states — synthetic MouseEvents never do.
// Used by rollgate.sh to generate on-screen motion for the pre-roll wiggle test
// (run the recorder with SHOWCURSOR=1 so the motion registers as pixels),
// and to park the pointer off-region before a synthetic-cursor take.
// usage: mousebin <x> <y>
// compile: swiftc -O mousebin.swift -o mousebin

let args = CommandLine.arguments
guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else {
    fputs("usage: mousebin <x> <y>\n", stderr); exit(2)
}
CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
