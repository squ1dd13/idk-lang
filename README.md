# IDK
(I haven't named it yet.)

This repository contains the code for an interpreted programming language implemented in Dart. 
The language isn't anything particularly special, but it *does* work, which is fairly special
by my standards.

The language has very typical syntax and very few interesting features at the moment.

## Examples
### Hello world
<!-- Note that here we use Java highlighting because it gives us basic highlighting for operators,
literals and some types. -->
```java
print("Hello, world!");
```

### Procedures and functions
We don't use `void` for procedures, we use `proc`.

```java
proc coolThing() {
    print("This is a cool thing.");
}
```

Functions are declared like in many other languages.

```java
int coolThingReturningInt() {
    return 0;
}
```

### References
Putting an `@` sign in front of a typename allows you to create a reference.

```java
// Normal variable.
int myInt = 10;

// Reference to myInt.
@int refToMyInt -> myInt;
```

References may be treated as though they are normal variables most of the time – 
they behave as such.

```java
// Prints '10' because refToMyInt resolves to the same as myInt.
print(refToMyInt);

// Sets myInt to 5.
refToMyInt = 5;
```

The `->` syntax is used to *direct* a reference, which is how we set the *target*. We can
direct a reference inline:

```java
proc doSomethingWithReference(@int something) {
    // Do something
}

int coolInteger = 123;

// We only have an 'int', not an '@int', so let's create a reference inline.
doSomethingWithReference(-> coolInteger);
```

It's possible to *redirect* references:

```java
@int someReference -> someIntegerSomewhere;

// We now want to change the target of someReference, so let's redirect it.
someReference -> someIntegerSomewhereElse;
```

### Function objects
Functions (and procedures, but we'll just call them functions here) are objects,
so you can create references to them and call them from other places.

```java
proc interestingProcedure() {
    print("Doing useful stuff, please wait...");
}

@any theProcedure -> interestingProcedure;
theProcedure();
```

In the above example we define a procedure, then create a reference to it.
Because references behave exactly as the target does (in this case, a function),
we can then use `()` syntax to call the function through the reference. This is
similar to using function pointers in C.

It is illegal to attempt to copy a function, since that wouldn't make sense.
Functions are immutable, so making a copy would provide nothing extra over 
a reference (because you still wouldn't be able to modify it). Additionally,
there is a lot of information contained within a function object, so copying
functions all the time would be slow.

```java
// ...

// Error! You can't copy functions.
any theProcedure = interestingProcedure;
theProcedure();
```