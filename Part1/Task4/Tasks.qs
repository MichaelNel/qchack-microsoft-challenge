namespace QCHack.Task4 {
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Convert;

    function isAnEdge (Vtx_a : Int, Vtx_b : Int, edges : (Int, Int)[] ) : Bool {
        for (first,second) in edges {
            if ((first == Vtx_a and second == Vtx_b) or  (first == Vtx_b and second == Vtx_a)) {
                return true;
            }
        }
        return false;
    }

    function getEdgeIdx (V_1 : Int, V_2 : Int, edges : (Int, Int)[]) : Int {
        for idx in 0..Length(edges)-1 {
            let (first, second) = edges[idx];
            if ((first == V_1 and second == V_2) or  (first == V_2 and second == V_1)) {
                return idx;
            }
        }
        return -1;
    }

    // Task 4 (12 points). f(x) = 1 if the graph edge coloring is triangle-free
    // 
    // Inputs:
    //      1) The number of vertices in the graph "V" (V ≤ 6).
    //      2) An array of E tuples of integers "edges", representing the edges of the graph (0 ≤ E ≤ V(V-1)/2).
    //         Each tuple gives the indices of the start and the end vertices of the edge.
    //         The vertices are indexed 0 through V - 1.
    //         The graph is undirected, so the order of the start and the end vertices in the edge doesn't matter.
    //      3) An array of E qubits "colorsRegister" that encodes the color assignments of the edges.
    //         Each color will be 0 or 1 (stored in 1 qubit).
    //         The colors of edges in this array are given in the same order as the edges in the "edges" array.
    //      4) A qubit "target" in an arbitrary state.
    //
    // Goal: Implement a marking oracle for function f(x) = 1 if
    //       the coloring of the edges of the given graph described by this colors assignment is triangle-free, i.e.,
    //       no triangle of edges connecting 3 vertices has all three edges in the same color.
    //
    // Example: a graph with 3 vertices and 3 edges [(0, 1), (1, 2), (2, 0)] has one triangle.
    // The result of applying the operation to state (|001⟩ + |110⟩ + |111⟩)/√3 ⊗ |0⟩ 
    // will be 1/√3|001⟩ ⊗ |1⟩ + 1/√3|110⟩ ⊗ |1⟩ + 1/√3|111⟩ ⊗ |0⟩.
    // The first two terms describe triangle-free colorings, 
    // and the last term describes a coloring where all edges of the triangle have the same color.
    //
    // In this task you are not allowed to use quantum gates that use more qubits than the number of edges in the graph,
    // unless there are 3 or less edges in the graph. For example, if the graph has 4 edges, you can only use 4-qubit gates or less.
    // You are guaranteed that in tests that have 4 or more edges in the graph the number of triangles in the graph 
    // will be strictly less than the number of edges.
    //
    // Hint: Make use of helper functions and helper operations, and avoid trying to fit the complete
    //       implementation into a single operation - it's not impossible but make your code less readable.
    //       GraphColoring kata has an example of implementing oracles for a similar task.
    //
    // Hint: Remember that you can examine the inputs and the intermediary results of your computations
    //       using Message function for classical values and DumpMachine for quantum states.
    //
    operation Task4_TriangleFreeColoringOracle (
        V : Int, 
        edges : (Int, Int)[], 
        colorsRegister : Qubit[], 
        target : Qubit
    ) : Unit is Adj+Ctl {
        // Message("Start");
        // DumpMachine();
        use ColTriFound = Qubit();
        for (V_1, V_2) in edges {
            for V_idx in 0..V-1 {
                if(isAnEdge(V_1, V_idx, edges) and isAnEdge(V_2, V_idx, edges)) {
                    // triangle <V_1, V_2, V_idx> is a triangle
                    // Message("Triangle found!");
                    let q1 = colorsRegister[getEdgeIdx(V_1, V_2, edges)];
                    let q2 = colorsRegister[getEdgeIdx(V_2, V_idx, edges)];
                    let q3 = colorsRegister[getEdgeIdx(V_1, V_idx, edges)];
                    // ancilliary qubits
                    use anc0 = Qubit();
                    use anc1 = Qubit();
                    use target_tri = Qubit();
                    within {
                        // if a and b are different anc is 1
                        ApplyControlledOnInt(0, X, [q1], anc0);
                        ApplyControlledOnInt(0, X, [q2], anc0);

                        // if b and c are different anc1 is 1
                        ApplyControlledOnInt(0, X, [q2], anc1);
                        ApplyControlledOnInt(0, X, [q3], anc1);

                        // if anc1 and anc2 are zero then coloured triangle!
                        // DumpMachine();
                        ApplyControlledOnBitString(IntAsBoolArray(0,2),X,[anc0, anc1],target_tri);
                        // DumpMachine();

                        // if target_tri == 1 we have a coloured triangle
                        // if target_tri == 0 we don't
                    } apply {
                        // set target to one if target_tri is one
                        // if target is already one don't flip
                        // DumpMachine();
                        // ApplyControlledOnInt(1, X, [target_tri], ColTriFound);
                        use anc2 = Qubit();
                        within {
                            // Apply if either is different
                            ApplyControlledOnInt(1, X, [target_tri], anc2);
                            ApplyControlledOnInt(1, X, [ColTriFound], anc2);
                            ApplyControlledOnBitString(IntAsBoolArray(3,2),X,[target_tri, ColTriFound],anc2);
                            // ApplyAnd(target_tri,ColTriFound,anc2);
                            // DumpMachine();
                        } apply {
                            CNOT(anc2,target);
                        }
                        // DumpMachine();
                    }
                }
            }
        }
        // CNOT(ColTriFound,target);
        // CNOT(target,ColTriFound);
        X(target);
        // DumpMachine();
    }
}

