namespace Console {

    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open QCHack.Task1;
    

    @EntryPoint()
    operation HelloQ() : Unit {
        use (inputs, output) = (Qubit[3], Qubit());
        Task1_DivisibleByFour(inputs, output);
    }
}

