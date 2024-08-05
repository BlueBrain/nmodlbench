COMMENT
/**
 * @file CoreConfig.mod
 * @brief Interface to write simulation configuration for CoreNEURON
 */
ENDCOMMENT

NEURON {
    THREADSAFE
    ARTIFICIAL_CELL CoreConfig
}

VERBATIM
#include <stdio.h>
#include <stdlib.h>
#if defined(ENABLE_CORENEURON)
#include <coreneuron/engine.h>
#endif

extern double* vector_vec();
extern int vector_capacity();
extern void* vector_arg();
extern int nrnmpi_myid;

// name of config files
static char const* const SIM_CONFIG_FILE = "sim.conf";
static char const* const REPORT_CONFIG_FILE = "report.conf";
static const int DEFAULT_CELL_PERMUTE = 0;

#define MAX_FILE_PATH 4096


// helper function to open file and error checking
FILE* open_file(const char *filename, const char *mode) {
    FILE *fp = fopen(filename, mode);
    if(!fp) {
        printf("Error while opening file %s\n", filename);
        abort();
    }
    return fp;
}
ENDVERBATIM


: Write basic sim settings from Run block of BlueConfig
PROCEDURE write_sim_config() {
VERBATIM
    #ifndef CORENEURON_BUILD
    if(nrnmpi_myid == 0) {
        FILE *fp = open_file(SIM_CONFIG_FILE, "w");
        fprintf(fp, "--outpath .\n");
        fprintf(fp, "--datpath %s\n", hoc_gargstr(1));
        fprintf(fp, "--tstop %lf\n", *getarg(2));
        fprintf(fp, "-mpi\n");
        fclose(fp);
    }
    #endif
ENDVERBATIM
}


PROCEDURE psolve_core() {
    VERBATIM
        #if defined(ENABLE_CORENEURON)
            int argc = 5;
            char *argv[9] = {"", "--read-config", SIM_CONFIG_FILE, "--skip-mpi-finalize", "-mpi", NULL, NULL, NULL, NULL };
            solve_core(argc, argv);
        #else
            if(nrnmpi_myid == 0) {
                fprintf(stderr, "%s", "ERROR : CoreNEURON library not linked with NEURODAMUS!\n");
            }
        #endif
    ENDVERBATIM
}
