namespace QCHack.Task3 {
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Math;

    function CreateOracleForSATInstance (problem : (Int, Bool)[][]) : ((Qubit[], Qubit) => Unit is Adj) {
        return Oracle_SAT(_, _, problem);
    }
    // General SAT problem oracle: f(x) = ∧ᵢ (∨ₖ yᵢₖ), where yᵢₖ = either xᵢₖ or ¬xᵢₖ
    operation Oracle_SAT (queryRegister : Qubit[], 
                          target : Qubit, 
                          problem : (Int, Bool)[][]) : Unit is Adj {
        // Allocate qubits to store results of clauses evaluation
        using (ancillaRegister = Qubit[Length(problem)]) {
            // Compute clauses, evaluate the overall formula as an AND oracle (can use reference depending on the implementation) and uncompute
            within {
                EvaluateOrClauses(queryRegister, ancillaRegister, problem);
            }
            apply {
                Controlled X(ancillaRegister, target);
            }
        }
    }
    // Helper operation to evaluate all OR clauses given in the formula (independent on the number of variables in each clause)
    operation EvaluateOrClauses (queryRegister : Qubit[], 
                                 ancillaRegister : Qubit[], 
                                 problem : (Int, Bool)[][]) : Unit is Adj {
        for (clauseIndex in 0..Length(problem)-1) {
            Oracle_SATClause(queryRegister, ancillaRegister[clauseIndex], problem[clauseIndex]);
        }
    }
    // Oracle to evaluate one clause of a SAT formula
    operation Oracle_SATClause (queryRegister : Qubit[], 
                                target : Qubit, 
                                clause : (Int, Bool)[]) : Unit is Adj {
        let (clauseQubits, flip) = GetClauseQubits(queryRegister, clause);

        // Actually calculate the clause (flip the necessary qubits, calculate OR, flip them back)
        within {
            ApplyPauliFromBitString(PauliX, true, flip, clauseQubits);
        }
        apply {
            // First, flip target if all qubits are in |0⟩ state
            (ControlledOnInt(0, X))(clauseQubits, target);
            // Then flip target again to get negation
            X(target);
        }
    }
    // Helper function to get the list of qubits used in the clause and the bitmask of whether they need to be flipped
    function GetClauseQubits (queryRegister : Qubit[], clause : (Int, Bool)[]) : (Qubit[], Bool[]) {
        mutable clauseQubits = new Qubit[Length(clause)];
        mutable flip = new Bool[Length(clause)];
        for (varIndex in 0 .. Length(clause) - 1) {
            let (index, isTrue) = clause[varIndex];
            // Add the variable used in the clause to the list of variables which we'll need to call the OR oracle
            let qt = queryRegister[index];
            set clauseQubits w/= varIndex <- queryRegister[index];
            // If the negation of the variable is present in the formula, mark the qubit as needing a flip
            set flip w/= varIndex <- not isTrue;
        }
    
        return (clauseQubits, flip);
    }
    operation GroversAlgorithm_Loop (register : Qubit[], oracle : ((Qubit[], Qubit) => Unit is Adj), iterations : Int) : Unit {
        let phaseOracle = OracleConverter_Reference(oracle);
        ApplyToEach(H, register);
        for i in 1 .. iterations {
            phaseOracle(register);
            within {
                ApplyToEachA(H, register);
                ApplyToEachA(X, register);
            }
            apply {
                Controlled Z(Most(register), Tail(register));
            }
        }
    }
    function OracleConverter_Reference (markingOracle : ((Qubit[], Qubit) => Unit is Adj)) : (Qubit[] => Unit is Adj) {
        return OracleConverterImpl_Reference(markingOracle, _);
    }
    operation OracleConverterImpl_Reference (markingOracle : ((Qubit[], Qubit) => Unit is Adj), register : Qubit[]) : Unit is Adj {

        use target = Qubit();
        within {
            // Put the target into the |-⟩ state, perform the apply functionality, then put back into |0⟩ so we can return it
            X(target);
            H(target);
        }
        apply {
            // Apply the marking oracle; since the target is in the |-⟩ state,
            // flipping the target if the register satisfies the oracle condition will apply a -1 factor to the state
            markingOracle(register, target);
        }
    }

    // Task 3 (5 points). f(x) = 1 if at least two of three input bits are different - hard version
    //
    // Inputs:
    //      1) a 3-qubit array "inputs",
    //      2) a qubit "output".
    // Goal: Implement a marking oracle for function f(x) = 1 if at least two of the three bits of x are different.
    //       That is, if both inputs are in a basis state, flip the state of the output qubit 
    //       if and only if the three bits written in the array "inputs" have both 0 and 1 among them,
    //       and leave the state of the array "inputs" unchanged.
    //       The effect of the oracle on superposition states should be defined by its linearity.
    //       Don't use measurements; the implementation should use only X gates and its controlled variants.
    //       This task will be tested using ToffoliSimulator.
    // 
    // For example, the result of applying the operation to state (|001⟩ + |110⟩ + |111⟩)/√3 ⊗ |0⟩
    // will be 1/√3|001⟩ ⊗ |1⟩ + 1/√3|110⟩ ⊗ |1⟩ + 1/√3|111⟩ ⊗ |0⟩.
    //
    // In this task, unlike in task 2, you are not allowed to use 4-qubit gates, 
    // and you are allowed to use at most one 3-qubit gate.
    // Warning: some library operations, such as ApplyToEach, might count as multi-qubit gate,
    // even though they apply single-qubit gates to separate qubits. Make sure you run the test
    // on your solution to check that it passes before you submit the solution!
    operation Task3_ValidTriangle (inputs : Qubit[], output : Qubit) : Unit is Adj+Ctl {
        // let esopCode = [
        //     Term([Literal(0, true), Literal(1, false)]),    // A !B
        //     Term([Literal(0, false), Literal(2, true)]),    // !A C
        //     Term([Literal(1, true), Literal(2, false)])     // B !C
        // ];
        let newEsop = [
            [(0, true), (1, false)],// A !B
            [(0, false), (2, true)],// !A C
            [(1, true), (2, false)] // B !C
        ];
        // let controlsLE = LittleEndian(inputs);

        // ApplyTerm(_, controls, target) is partial application and returns
        // an operation that takes a single `Term` argument as input
        // ApplyToEach(ApplyTerm(_, controlsLE, output), esopCode);
        let variableCount = 3;

        let oracle = CreateOracleForSATInstance(newEsop);

        // We will discuss choosing the right number of iterations later
        let iterationCount = 1;
        
        // Allocate the qubits for running the algorithm
        use register = Qubit[variableCount];
        // Run the iterations using a pre-written operation
        GroversAlgorithm_Loop(register, oracle, iterationCount);
        
        
    }
}

