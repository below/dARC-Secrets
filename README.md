# dARC-Secrets

## Or: How To Shoot Yourself In The Foot With ARC

### Abstract

This project is meant both to demonstrate a problem that can arise when using Cocoa's Automatic Reference Counting (ARC), as well as to explain a few little things about Cocoa's modern Memory Management, on iOS and on OS X.
It should be noted that the problem shown here is not a fault in ARC, but in the end a developer error.

### Shooting Yourself in the Foot

So my code crashed:

	EXC_BAD_ACCESS (code=2, address=0x1)

`EXC_BAD_ACCES` means that the machine attempted to access memory at an illegal location. `0x01` is very obviously illegal.
This happend in a somewhat surprising location: `libobjc.A.dylib\`objc\_retain\`. Going up the stacktrace one step to my own code led me to a seemingly insuspicious call: `if ([self doFoo])`.

Address = 0x01? Retain? In a condition test? What?

### Finding the Bullet

The project in which this happened of course was much larger and more complex than the sample, so I searched in all the places that looked like the usual suspects. I fired up Instruments, enabled Zombies, but nothing really got any closer.

To add to the confusion, the code worked when I moved it from the base class to a subclass. 

What was going on? It was clear that the `0x01` pointed to to a boolean value, and in fact, the method I was calling actually did a `return YES;`. Why did ARC think that this value needs to be retained?

Finally, we found the problem: The class, let's call it `BaseClass`, in which I made the call was meant to be an abstract class, never to be actually instantiated. Instead, concrete subclasses of it are. For the sake of this example, let's call one such class `DerivedClass`.

Part one of the problem was, that the `BaseClass` contained a prototypic implementation of `doFoo`:

	- (id) doFoo {
		NSAssert(NO, @"Abstract implementation");
		return nil;
	}

But through some refactoring or other changes, the method which is actually called (in `DerivedCalls`) looked differently:

	- (BOOL) doFoo {
		return YES;
	}

As Objective-C has its roots in Smalltalk, it is a pretty dynamic language, and things like strong typing are optional. And so are method prototypes, which is why the compiler never complained that `doFoo` was declared only by its implementation.

Now, because in `BaseClass.m` ARC only sees `- (id) doFoo`, ARC produces code which assumes that it will get an object back, and not a boolean (Remember: ARC is a compiler technology, it checks the object types at compiletime, not at runtime). Thus, when `–[DerivedClass doFoo]` returned `YES`, the compiled code tried to retain the value `0x01` and crashed, because that is clearly an invalid pointer. Problem solved.

### Wait, what …you said "retained"?

Let's go back one step: The crash was caused in the statement `if ([self doFoo])`. The return value is only used for a conditional test, and it should not matter if we passed an autoreleased object or a boolean variable into it. Why then does ARC even try to retain the value? In non-ARC code, there would most certainly not be a `retain` here anywhere.

Looking very closely, there is not exactly a `retain` here either. When we examine the assembly for the code, we can see that actually a function `\_objc\_retainAutoreleasedReturnValue` is being called. Now, "Retain Autoreleased Return Value" is a curious name unlike anything we have seen outside of ARC code, It is well worth looking into.

We find interesting information about this in the Objective-C runtime, which luckily is open source, specifically in the file [objc-arr.mm](http://www.opensource.apple.com/source/objc4/objc4-493.11/runtime/objc-arr.mm "objc-arr.mm"):

>  The caller and callee cooperate to keep the returned object  out of the autorelease pool.

So what ARC tries to do to improve performance, is actually to avoid putting things into the autorelease pool (ARP). It does so by putting little hints into the code:

The callee (i.e. the method being called) uses the function `objc\_autoreleaseReturnValue()` to examine the instruction at the return address. If they call `objc\_autoreleaseReturnValue` (which is actually indicated by the assembly NOP `mov	r7, r7`), then the callee does not send `autorelease` to the returned object, but instead stores the result in thread-local storage.

As we have seen, the caller calls `objc\_retainAutoreleasedReturnValue`, which checks if the returned value is the same as in the thread-local storage. If it is, then the value is used directly, completely bypassing the autorelease pool. If it is _not_ then `objc_retain` is called, which is exactly what has happend in our case.

But is `objc_retain` called, even in the case of a simple `if` test? The rationale is that after `objc\_retainAutoreleasedReturnValue`, the caller always has a retained reference to the object. Remeber: ARC is not garbage collection, neither does it magically do away with the basic rules of object allocation. Even with ARC, anything you create must be released at some point to avoid memory leakage. And from a performance perspective, explictly releasing objects is  always preferable to putting them into an autorelease pool.

The Cocoa autorelease pool always was something for the convenience of the developers. Having the autorelease pool allowed us to write elegant statements like this:

	NSLog ([NSString stringWithString:@"foo"]);

(Yes, yes, I know this makes little sense. It's for informational purposes only).

The autorelease pool postpones the release to sometime in the future. Without ARP, the code would look like this:

	NSString *output = [[NSString alloc] initWithString:@"foo"];
	NSLog (output);
	[output release];

Other than less typing, there is absolutely no benefit in the ARP version. But now, with ARC, the compiler can deliver us from all the pesky typing by inserting the manual release calls automatically. 

And even when we think that nothing needs to be retained in the case of a simple `if` statement, ARC attempts to avoid using an autorelese pool here just as well. Looking at the assembly, we find proof of that:

	bl	_objc_retainAutoreleasedReturnValue
	str	r0, [sp]                @ 4-byte Spill
	bl	_objc_release

And this is the complete explanation, why the crash happens.

### Lessons Learned

* Prototype your methods, even if you are an old school Objective-C developer. If I had prototyped my methods, the compiler would have told me that the return types mismatch
* ARC is good for you. ARC is not only helping you to avoid leaks or accessing deallocated memory, it also does some things which actually improve the performance of your app.

### Thanks 

I wish to thank Tammo Freese for brushing up my ARM assembly, and for investigating this issue with me, and pointing me towards the runtime source code.

### One more thing …

For the more curious: When the code is compiled for OS X it does _not_ crash. But this is a story for another day (Hint, hint: OS X is 64 Bit) … 
