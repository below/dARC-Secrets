# dARC-Secrets

## Or: How To Shoot Yourself In The Foot With ARC

### Abstract

This project is meant both to demonstrate a problem that can arise when using Cocoa's Automatic Reference Counting (ARC), as well as to explain a few little things about Cocoa's modern Memory Management, on iOS and on OS X.
It should be noted that the problem shown here is not a fault in ARC, but in the end a developer error.

### Shooting Yourself in the Foot

What happended that my code crashed:

	EXC_BAD_ACCESS (code=2, address=0x1)

`EXC_BAD_ACCES` means that the machine attempted to access memory at an illegal location. `0x01` is very obviously illegal.
This happend in a somewhat surprising location: `libobjc.A.dylib\`objc\_retain\`. Going up the stacktrace on step to my own code led me to a seemingly insuspicious call: ``if ([self doFoo])`.

Address = 0x01? Retain? In a condition test? What?

The project in which this happened of course was much larger and more complex than the sample, so I searched in all the places that looked like the usual suspects. I fired up Instruments, enabled Zombies, but nothing really go me any closer.

