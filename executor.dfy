
// An executor executes an instruction set or language as a state
// machine. For a given state "s", "exec(s)" returns two possible next
// states. "branchCondition(s)" returns the condition under which the
// first of those states should be taken. When "s" is executing a
// non-branching instruction, it is common for "state(s)" to return (s2,
// null), and for "branchCondition(s)" to return true.


// Implements a basic subset of the LLVM intermediate representation.
//   http://llvm.org/docs/LangRef.html
module LlvmExecutor {
  import opened SatLib : NetworkSatLib

  type Reg = int  // Index into map of registers, State.regs

  // Fields cannot be duplicated, so fields are appended with the instruction.
  datatype Instr =
    Add(add_dest: Reg, add_op1: Reg, add_op2: Reg)
  | Icmp(icmp_dest: Reg, icmp_op1: Reg, icmp_op2: Reg)
  | Br(br_cond: Reg, br_label1: int, br_label2: int)

  datatype State = State(ip: int, regs: map<Reg, IntExpr>) | HaltedState

  method program() returns (instrs: array<Instr>)
    ensures fresh(instrs)
  {
    instrs := new Instr[4];
    instrs[0] := Add(0, 1, 2);
    instrs[1] := Icmp(0, 0, 1);
    instrs[2] := Br(0, 3, 4);
    instrs[3] := Add(0, 1, 2);
    return instrs;
  }

  method getReg(s: State, r: Reg) returns (regExpr: IntExpr)
    requires s.State?
  {
    if r in s.regs {
      return s.regs[r];
    } else {
      return intSymbolic(r);
    }
  }

  method getInitialState() returns (s: State) {
    return State(0, map[]);
  }

  method branchCondition(s: State) returns (cond: SatLib.BoolExpr)
  {
    var prog := program();

    // If we're halted, or we run out of instructions, it
    // doesn't matter, the children will be halted.
    if !(s.State? && 0 <= s.ip < prog.Length) {
      return not(getTrueBool());
    }

    match prog[s.ip] {
      case Add(_, _, _) =>
        return getTrueBool();
      case Icmp(_, _, _) =>
        return getTrueBool();
      case Br(cond, _, _) =>
        var condReg := getReg(s, cond);
        return cmp(condReg, intConst(1));
    }
  }

  method exec(s: State) returns (s1: State, s2: State) {
    var prog := program();

    // If we're halted, both children are also halted
    if !(s.State? && 0 <= s.ip < prog.Length) {
      return HaltedState, HaltedState;
    }

    // Return two children states.
    // If not branching, return (state, HaltedState).
    match prog[s.ip] {

      case Add(dest, op1, op2) =>
        var x1 := getReg(s, op1);
        var x2 := getReg(s, op2);
        return State(
          s.ip + 1,
          s.regs[dest := add(x1, x2)]
        ), HaltedState;

      case Icmp(dest, op1, op2) =>
        var x1 := getReg(s, op1);
        var x2 := getReg(s, op2);
        return State(
          s.ip + 1,
          s.regs[dest := boolToInt(cmp(x1, x2))]
        ), HaltedState;

      case Br(cond, label1, label2) =>
        return State(
          label1,
          s.regs
        ), State(
          label2,
          s.regs
        );

    }
  }

  method halted(s: State) returns (b: bool) {
    var prog := program();
    return !(s.State? && 0 <= s.ip < prog.Length);
  }

}
