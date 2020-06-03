
$$
micro neurodamus - Channel Benchmark
$$

1. Install neuron
   1. with needed requirements

    For example

    CMAKE options:

    ```
    cmake -DNRN_ENABLE_BINARY_SPECIAL=ON -DNRN_ENABLE_INTERVIEWS=OFF -DNRN_ENABLE_RX3D=ON -DPYTHON_EXECUTABLE=`which python3` -DNRN_ENABLE_MPI=ON ..
    ```

    then

    ```
    make -j && sudo make install
    ```

   2.  Update PYTHONPATH

    This should include the path to NEURON libraries.

    ```
    export PYTHONPATH=/usr/local/lib/python:$PYTHONPATH
    ```

2. Create **special** and **special-core**

    ```
    nrnivmodl lib/modlib

    nrnivmodl-core lib/modlib
    ```

    You should have them in **./x86_64/**

3. Set HOC_LIBRARY_PATH

    ```
    export HOC_LIBRARY_PATH=`pwd`/lib/hoclib
    ```

4. Launch tests
   1. With **NEURON**
    ```
        ./x86_64/special $HOC_LIBRARY_PATH/init.hoc
    ```
   2. With **CORENEURON**
    ```
        ./x86_64/special -c arg_coreneuron=1 $HOC_LIBRARY_PATH/init.hoc
    ```
    or
    ```
        ./x86_64/special-core --mpi -d coredat
    ```
