import Lean

set_option doc.verso false

/-!
# `lake exe oracle`

Loads `Oracle.Presentation`, which imports `Oracle.Handle`, from its compiled
`.olean` files and runs it in Lean's interpreter, the same way `lake exe status`
evaluates examples.  Importing the rules directly would make the executable
link Mathlib's native code.

    lake exe oracle      one JSON request per line in, one response per line out

`Oracle/Handle.lean` describes the requests of the credential checks and
`Oracle/Presentation.lean` those of the presentation rules.  The conformance
vectors are in `build/one-id-data/decisions.jsonl` and
`build/one-id-data/presentation/decisions.jsonl`, written by
`lake exe oneid-facts`.
-/

open Lean

def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Oracle.Presentation }] {} (loadExts := true)
  let handle ← IO.ofExcept <| unsafe env.evalConst (String → String) {} `Oracle.handleAny
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let line := line.trimAscii.toString
    if line.isEmpty then continue
    stdout.putStrLn (handle line)
    stdout.flush
  return 0
