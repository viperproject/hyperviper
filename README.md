HyperViper is an automated prototype verifier for proving information flow security for concurrent programs based on abstract commutativity. It is implemented as a plugin for the open source Viper verifier (https://www.pm.inf.ethz.ch/research/viper.html). That is, it takes Viper’s ordinary language (which is a simple sequential language with support for a mutable heap) and its specification language and extends them with custom language and specification constructs for commutativity-based information flow reasoning.

# Compiling and Running HyperViper

HyperViper requires Java (version 11 or newer) and SBT as well as a working installation of Z3 4.8.7.

Check out this repoository and all submodules:
```
git clone --recursive https://github.com/viperproject/hyperviper
```

Execute
```
cd commutativity-plugin-test
sbt assembly
```
to compile HyperViper.

To run tests, set the environment variable ``Z3_EXE`` to point to the Z3 executable. Then run
```
cd commutativity-plugin-test
sbt test
```

To verify an individual file, run
```
./hyperviper.sh path/to/file.vpr
```

# Syntax and specifications

## Resource specifications
Resource specifications are top-level declarations in HyperViper. Since HyperViper supports multiple shared resources in a single program by supporting multiple locks (and each lock is associated with a resource specification), they are called lock types in HyperViper. A simple resource specification declaration looks as follows:

```
lockType CounterLock {
 type Int
 invariant(l, v) = [l.lockCounter |-> ?cp && [cp.val |-> v]]
 alpha(v): Int = v

 actions = [(Incr, Unit, duplicable)]

 action Incr(v, arg)
   requires true
 { v + 1 }

 noLabels = N()
}
```

Similar to the presentation in the paper, they declare the logical type of the value they work with (here that type is ``Int``), an abstraction function alpha, and a set of actions (here only one, which is called ``Incr`` and takes ``Unit`` as its parameter type), each of which is a function marked as shared (called duplicable in the tool) or unique. In HyperViper, one first declares the set of actions in a given lock type and marks them shared or unique, and subsequently defines the actions and their (potentially relational) preconditions.

Unlike in the paper, in HyperViper, lock types are immediately associated with invariants (which map the value of the resource to some concrete implementation, in this case, to the value of the field ``cp.val``). 

Additionally, lock type declarations contain an integer ``noLabels``, which defines how many times the guards for the shared actions in the lock type should be splittable; this is used to aid automation (see also the respective ghost statements below). In particular, in HyperViper, each shared action guard is associated with a set of integer labels 0 … noLabels. Performing the action requires a guard with a singleton set containing a specific label, and having the entire guard corresponds to having the guard with the full set of labels. Guards have to be explicitly split and merged using ghost statements (see below).

Additionally, lock types can contain proof blocks that define proofs (in the form of intermediate assertions the prover should check that will enable it to prove the overall proof goal) to help HyperViper prove aspects of the validity of each declared lock type. In most cases, HyperViper is able to prove these properties completely automatically, but if the automatic check e.g. of action commutativity fails, users can manually write such a block to help the prover. An example from example 13_salary-histogram.vpr that helps HyperViper prove the commutativity of two disjoint put actions Put1 and Put2 looks as follows:

```
proof commutativity[Put1, Put2](v, arg1, arg2) {
 var r1 : MyMap[Int, Int] := put(put(v, fst(arg1), snd(arg1)), fst(arg2), snd(arg2))
 var r2 : MyMap[Int, Int] := put(put(v, fst(arg2), snd(arg2)), fst(arg1), snd(arg1))
 assert map_eq(r1, r2)
}
```

## Statements
HyperViper extends the standard Viper language with several new statements:

- ``t := fork m(args)``

  Forks a new thread that executes method ``m`` with arguments ``args``, and assigns the resulting thread object to variable ``t``. As we state in the paper, while CommCSL only supports parallel composition statements ``c || c``, HyperViper supports dynamic forking and joining of threads.

- ``join[m](t)``

  Joins thread object ``t``, which must have executed method ``m``.
- ``with[LT] l when e performing a(x) at lbl { c }``

  Acquires lock ``l`` of lock type ``LT`` once expression ``e`` is true, executes statement ``c``, and releases the lock again. All other parts of the statement are annotations that help the proof, i.e., they are required to fix values that are free in CommCSL rules, like the action ``a`` in the Atomic rules, s.t. HyperViper does not have to try to automatically find the correct values. Here, ``a`` must be an action allowed by lock type ``LT``, and statement ``c`` must change the state in a way that corresponds to executing action ``a`` with argument ``x`` (and all of these properties are, of course, checked by the tool). The end ``at lbl`` is only used if ``a`` is a shared action: In this case, it updates the specific action guard with integer label ``lbl``.

- ``share[LT](l, e)``

  Shares the previously not shared lock ``l`` of lock type ``LT`` with an initial value of ``e`` (which requires that the lock’s invariant holds, consumes it, and creates all action guards for the lock).

- ``unshare[LT](l)``

  Unshares the previously shared lock ``l`` of lock type ``LT``, which consumes the action guards and checks, among other things, that all action preconditions were fulfilled (i.e., PRE holds for every action), and lets the user assume that the abstraction of the data protected by the lock is low afterwards.

- ``merge[LT, a](l, s1, s2)``

  Merges two guards for shared action ``a`` of lock ``l`` of type ``LT``. One guard must have the set of labels ``s1``, the other the set ``s2``, and the merged guard will have the set ``s1 union s2``. This statement is again required as an annotation from the user, to avoid that the prover has to automatically infer when to merge (and split) shared action guards.

- ``split[LT, a](l, s1, s2, ms1, ms2)``

  Performs the opposite of ``merge`` and splits the currently held guard for shared action ``a`` of lock ``l`` of lock type ``LT`` (which must have the union of the labels in ``s1`` and ``s2`` and whose argument multiset must be the union of multisets ``ms1`` and ``ms2``) into two separate guards with label sets ``s1`` and ``s2`` and with action argument multisets ``ms1`` and ``ms2``. 

## Assertions and expressions
HyperViper adds several new assertions and expressions to the Viper language:

- A points-to assertion ``[e.f |-p-> ?v && A]`` states that receiver ``e`` has a field ``f`` which points to some existentially-quantified value ``v``, and assertion ``A`` holds for said value. Additionally, the optional expression ``p`` (which defaults to 1) expresses the fractional permission amount to this field that the current context owns.
- The relational assertion ``low(e)`` states that the value of ``e`` is low.
- The relational assertion ``lowEvent`` states that the current calling context is low, i.e., whether or not the current point in the program is reached does not depend on high data. This assertion is not supported in CommCSL but is useful to specify effectful methods, e.g., for a print method, one may want to ensure not only that the printed value is low, but also that whether or not something is printed at all does not depend on high data. This property can be expressed using the method precondition lowEvent.
- The assertion ``sguard[LT, a](l, s)`` represents a partial guard for shared action ``a`` of lock ``l`` of type ``LT``. ``s`` is a set of labels, i.e., if ``s`` is the set 0 … noLabels, then the guard is a full guard and not a partial one. While in the paper, we have a guard assertion ``sguard(p, ms)`` where ``p`` is a fractional permission amount and ``ms`` is the multiset of action arguments, here, we have to additionally specify the lock (since we can have more than one) and the action and lock type (since we can have more than one). We express the permission amount via the set of labels. The argument multiset ``ms`` is not included in the assertion in HyperViper, but handled separately via an expression:
- The expression ``sguardArgs[LT, a](l, s)`` represents the multiset of arguments in the partial guard for shared action ``a`` has been performed on lock ``l`` of type ``LT`` with label set ``s``. This expression is well-defined only when the respective guard is held (and HyperViper reports an error if it is used in a context when the guard is not held). Separating the guard itself from its argument expression simplifies automation.
- Similarly, there is an assertion ``uguard[LT,a](l)`` that represents a full guard for unique action ``a`` of lock ``l`` of type ``LT``, and its argument sequence is represented by the expression ``uguardArgs[LT, a](l)``.
- ``allPre[LT, a](e)`` is equivalent to ``PRE_a(e)`` in the paper and expresses that the multiset or sequence of arguments ``e`` satisfies the precondition of action ``a``.
- Finally, ``joinable[m](t, args)`` states that ``t`` is a thread running method ``m`` with arguments ``args`` and can be joined.

# HyperViper implementation overview

As stated above, HyperViper is implemented in Scala as a plugin for the open source Viper verification infrastructure. It extends Viper’s syntax with custom constructs for commutativity-based information flow reasoning. Users can write programs using said extended syntax, and HyperViper subsequently encodes it into a standard Viper program, which is then verified by Viper’s default symbolic execution backend, which ultimately uses the SMT solver Z3. 

This repository contains the implementation of HyperViper in multiple parts:
- hyperviper/silver contains the definition of Viper’s standard verification language, and hyperviper/silicon contains Viper’s standard execution backend. These are parts of the open source Viper infrastructure and used without major modifications.
- hyperviper/commutativity-plugin contains the entire implementation of HyperViper itself, which will be described further below.
- hyperviper/commutativity-plugin-test contains no code itself and exists only for build purposes; it has Viper itself and the HyperViper plugin as dependencies and thus can be packaged to get a single jar file.
- hyperviper/silver-sif-extension is a pre-existing open source implementation of the modular product program transformation for Viper, and is used without major modifications by HyperViper. This transformation enables Viper, which is unable to directly verify relational properties, to verify programs containing relational Low(e)-assertions.

The main project, commutativity-plugin, contains six main files:
- CommutativityPluginASTExtensions.scala and CommutativityPluginPASTExtensions.scala contain definitions of AST nodes for the additional statements, expressions and assertions introduced by HyperViper. For example, CommutativityPluginASTExtensions.scala contains a class LockSpec (representing a lock type, i.e., a resource specification) that contains a type, a definition of an abstraction function, and several action definitions and an invariant declaration.
- CommutativityErrors.scala contains classes representing custom error types relating to commutativity-based reasoning, e.g., an error type that represents a failed commutativity check.
- CommutativityParser.scala defines an extension of Viper’s standard parser to parse the newly-added statements, declarations, expressions and assertions. 
- CommutativityPlugin is the main class of HyperViper that defines its extension of the Viper language in the form of a plugin. It hooks into Viper’s extension mechanism by 
  - extending its parser (by overriding the beforeParse method and adding the new parse rules defined in CommutativityParser.scala)
  - desugaring special types for locks and threads to simple references (by overriding the beforeResolve method, which is called before type checking)
  - and encoding all added language constructs to the standard Viper language (by overriding method beforeConsistencyCheck, which is called after type checking and before verification, to call the main encoding method defined in CommutativityTransformer.scala).
- CommutativityTransformer.scala defines the encoding of the extended Viper language with constructs for commutativity-based information flow reasoning to the standard Viper language. Its main method, encodeProgram, performs three main steps:
  - It checks various consistency criteria on the input program by calling checkDeclarationConsistency (which ensures, for example, that resource invariants do not contain Low-assertions).
  - It generates definitions and declarations of various helper functions and predicates which are used in the encoding. In particular, this includes the definition of PRE_a for each action a, which is generated by method generateAllPre.
  - It encodes proof obligations relating to the well-definesness and validity of all declared lock specifications by calling method encodeExtension.
  - It defines the encoding of all added statements (e.g., for forking and joining threads and acquiring resources) and assertions (e.g. relating to guards) in the inner functions transformStmt and transformExp, separately for each statement and assertion. For example, lines 457-503 encode the proof obligations resulting from a share-statement into regular Viper code. The generated code asserts that the lock invariant holds, asserts that the supplied initial value of the shared data structure is low modulo abstraction, and creates guards for all actions of the newly-shared lock. For each encoded statement and assertion, comments in the code show the generated Viper code.
  - Finally, it applies this transformation to the input program in line 781, and subsequently, since the generated program still uses relational Low(e) and LowEvent assertions, calls outside code to construct a product program of the generated program, which also transforms Low-assertions into regular Viper assertions.

## Extending HyperViper
HyperViper can easily be extended to work with additional statements, assertions, or more complex resource specification by performing the following steps:
- Add a new AST and ParseAST node for the new construct (or adapt the existing one) in CommutativityASTExtensions.scala and CommutativityPASTExtensions.scala. The ParseAST node internally has to define how to type check the new node, analogously to the existing nodes.
- Define a new parse rule in CommutativityParser.scala, and add it to the newStmt, newExp, or newDecl definitions at the top of the file.
- If the new construct requires any kind of desugaring before type checking, extend method beforeResolve in CommutativityPlugin.scala to do so accordingly.
- In CommutativityTransformer, 
  - For new top-level declarations or extended lock specifications, extend method checkDeclarationConsistency to add all required additional syntactic checks.
  - For new top-level declarations or extended lock specifications, extend method encodeExtension to generate all added proof obligations resulting from the new or extended declaration.
  - Generate any additional helper definitions inside encodeProgram.
  - Extend methods transformExp and/or transformStmt (by adding a case that matches on the new expression or statement type) inside encodeProgram to define the encoding of added statements, expressions or assertions to standard Viper code.
