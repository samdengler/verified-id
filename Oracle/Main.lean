import Lean

set_option doc.verso false

/-!
# `lake exe oracle`

Loads `Oracle.Handle` from its compiled `.olean` files and runs it in Lean's
interpreter, the same way `lake exe status` evaluates examples.  Importing
the rules directly would make the executable link Mathlib's native code.

    lake exe oracle      one JSON request per line in, one response per line out

`Oracle/Handle.lean` describes the requests.  The conformance vectors are in
`build/one-id-data/decisions.jsonl`, written by `lake exe oneid-facts`.
-/

open Lean

def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Oracle.Handle }] {} (loadExts := true)
  let handle ← IO.ofExcept <| unsafe env.evalConst (String → String) {} `Oracle.handle
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
