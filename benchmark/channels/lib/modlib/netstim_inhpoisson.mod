COMMENT
/**
 * @file netstim_inhpoisson.mod
 * @brief
 * @author ebmuller
 * @date 2011-03-16
 * @remark Copyright © BBP/EPFL 2005-2011; All rights reserved. Do not distribute without further notice.
 */
ENDCOMMENT

: Inhibitory poisson generator by the thinning method.
: See:
:   Muller, Buesing, Schemmel, Meier (2007). "Spike-Frequency Adapting
:   Neural Ensembles: Beyond Mean Adaptation and Renewal Theories",
:   Neural Computation 19:11, 2958-3010.
:   doi:10.1162/neco.2007.19.11.2958
:
: Based on vecstim.mod and netstim2.mod shipped with PyNN
: Author: Eilif Muller, 2011

NEURON {
THREADSAFE
  ARTIFICIAL_CELL InhPoissonStim
  RANGE rmax
  RANGE duration
  RANDOM uniform_rng, exp_rng
  BBCOREPOINTER vecRate, vecTbins
  :THREADSAFE : only true if every instance has its own distinct Random
}
VERBATIM

// constant used to indicate an event triggered after a restore to restart the main event loop
const int POST_RESTORE_RESTART_FLAG = -99;

ENDVERBATIM


PARAMETER {
  interval_min = 1.0  : average spike interval of surrogate Poisson process
  duration	= 1e6 (ms) <0,1e9>   : duration of firing (msec)
}

VERBATIM
#include "nrnran123.h"
ENDVERBATIM

ASSIGNED {
   vecRate
   vecTbins
   index
   curRate
   start (ms)
   event (ms)
   rmax
   activeFlag
}

INITIAL {
   index = 0.
   activeFlag = 0.

   : determine start of spiking.
   VERBATIM
   IvocVect *vvTbins = *((IvocVect**)(&_p_vecTbins));
   double* px;

   if (vvTbins && vector_capacity(vvTbins)>=1) {
     px = vector_vec(vvTbins);
     start = px[0];
     if (start < 0.0) start=0.0;
   }
   else start = 0.0;

   /* first event is at the start
   TODO: This should draw from a more appropriate dist
   that has the surrogate process starting a t=-inf
   */
   event = start;

   /* set curRate */
   IvocVect *vvRate = *((IvocVect**)(&_p_vecRate));
   px = vector_vec(vvRate);

   /* set rmax */
   rmax = 0.0;
   int i;
   for (i=0;i<vector_capacity(vvRate);i++) {
      if (px[i]>rmax) rmax = px[i];
   }

   if (vvRate && vector_capacity(vvRate)>0) {
     curRate = px[0];
   }
   else {
      curRate = 1.0;
      rmax = 1.0;
   }

   /** after discussion with michael : rng streams should be set 0
     * in initial block. this is to make sure if initial block is
     * get called multiple times then the simulation should give the
     * same results. Otherwise this is an issue in coreneuron because
     * finitialized is get called twice in coreneuron (once from
     * neurodamus and then in coreneuron. But in general, initial state
     * should be callable multiple times.
     */
   ENDVERBATIM
   random_setseq(uniform_rng, 0)
   random_setseq(exp_rng, 0)

   update_time()
   erand() : for some reason, the first erand() call seems
           : to give implausibly large values, so we discard it
   generate_next_event()
   : stop even producing surrogate events if we are past duration
   if (t+event < start+duration) {
     net_send(event, activeFlag )
   }


}

: This procedure queues the next surrogate event in the
: poisson process (rate=ramx) to be thinned.
PROCEDURE generate_next_event() {
	event = 1000.0/rmax*erand()
	: but not earlier than 0
	if (event < 0) {
		event = 0
	}

}


FUNCTION urand() {
    urand = random_dpick(uniform_rng)
}

FUNCTION erand() {
    erand = random_negexp(exp_rng)
}

PROCEDURE setTbins() {
VERBATIM
  #ifndef CORENEURON_BUILD
  IvocVect** vv;
  vv = (IvocVect**)(&_p_vecTbins);
  *vv = (IvocVect*)0;

  if (ifarg(1)) {
    *vv = vector_arg(1);

    /*int size = vector_capacity(*vv);
    int i;
    double* px = vector_vec(*vv);
    for (i=0;i<size;i++) {
      printf("%f ", px[i]);
    }*/
  }
  #endif
ENDVERBATIM
}


PROCEDURE setRate() {
VERBATIM
  #ifndef CORENEURON_BUILD

  IvocVect** vv;
  vv = (IvocVect**)(&_p_vecRate);
  *vv = (IvocVect*)0;

  if (ifarg(1)) {
    *vv = vector_arg(1);

    int size = vector_capacity(*vv);
    int i;
    double max=0.0;
    double* px = vector_vec(*vv);
    for (i=0;i<size;i++) {
    	if (px[i]>max) max = px[i];
    }
    
    curRate = px[0];
    rmax = max;

    activeFlag = activeFlag + 1;
  }
  #endif
ENDVERBATIM
}

PROCEDURE update_time() {
VERBATIM
  IvocVect* vv; int i, i_prev, size; double* px;
  i = (int)index;
  i_prev = i;

  if (i >= 0) { // are we disabled?
    vv = *((IvocVect**)(&_p_vecTbins));
    if (vv) {
      size = vector_capacity(vv);
      px = vector_vec(vv);
      /* advance to current tbins without exceeding array bounds */
      while ((i+1 < size) && (t>=px[i+1])) {
	index += 1.;
	i += 1;
      }
      /* did the index change? */
      if (i!=i_prev) {
        /* advance curRate to next vecRate if possible */
        IvocVect *vvRate = *((IvocVect**)(&_p_vecRate));
        if (vvRate && vector_capacity(vvRate)>i) {
          px = vector_vec(vvRate);
          curRate = px[i];
        }
        else curRate = 1.0;
      }

      /* have we hit last bin? ... disable time advancing leaving curRate as it is*/
      if (i==size)
        index = -1.;

    } else { /* no vecTbins, use some defaults */
      rmax = 1.0;
      curRate = 1.0;
      index = -1.; /* no vecTbins ... disable time advancing & Poisson unit rate. */
    }
  }

ENDVERBATIM
}



COMMENT
/**
 * Upon a net_receive, we do up to two things.  The first is to determine the next time this artificial cell triggers
 * and sending a self event.  Second, we check to see if the synapse coupled to this artificial cell should be activated.
 * This second task is not done if we have just completed a state restore and only wish to restart the self event triggers.
 *
 * @param flag >= 0 for Typical activation, POST_RESTORE_RESTART_FLAG for only restarting the self event triggers 
 */
ENDCOMMENT
NET_RECEIVE (w) { LOCAL u
    : Note - if we have restored a sim from a saved state.  We need to restart the queue, but do not generate a spike now
    if ( flag == POST_RESTORE_RESTART_FLAG ) {
        if (t+event < start+duration) {
            net_send(event, activeFlag )
        }
    } else if( activeFlag == flag ) {
        update_time()
        generate_next_event()

        : stop even producing surrogate events if we are past duration
        if (t+event < start+duration) {
            net_send(event, activeFlag )
        }

        : check if we trigger event on coupled synapse
        u = urand()
        if (u<curRate/rmax) {
            :printf("InhPoisson: spike time at time %g\n",t)
            net_event(t)
        }
    }
}


COMMENT
/**
 * Supply the POST_RESTORE_RESTART_FLAG.  For example, so a hoc program can call a NetCon.event with the proper event value
 *
 * @return POST_RESTORE_RESTART_FLAG value for entities that wish to use its value
 */
ENDCOMMENT
FUNCTION getPostRestoreFlag() {
VERBATIM
    return POST_RESTORE_RESTART_FLAG;
ENDVERBATIM
}


COMMENT
/**
 * After a resume, populate variable 'event' with the first event time that can be given to net_send such that the elapsed time is
 * greater than the resume time.  Note that if an event was generated just before saving, but due for delivery afterwards (delay 0.1),
 * then the hoc layer must deliver this event directly.
 *
 * @param delay (typically 0.1) #TODO: accept a parameter rather than using hard coded value below
 * @return Time of the next event.  If this is less than the current time (resume time), the hoc layer should deliver the event immediately
 */
ENDCOMMENT
FUNCTION resumeEvent() {
    LOCAL elapsed_time, delay
    : Since we want the minis to be consistent with the previous run, it should use t=0 as a starting point until it
    : reaches an elapsed_time >= resume_t.  Events generated right before the save time but scheduled for delivery afterwards
    : will already be restored to the NetCon by the bbsavestate routines

    elapsed_time = event : event has some value from the INITIAL block
    delay = 0.1

    while( elapsed_time < t ) {
        update_time()
        generate_next_event()
        elapsed_time = elapsed_time + event
    }
    resumeEvent = elapsed_time
    event = elapsed_time-t
}

VERBATIM
static void bbcore_write(double* dArray, int* iArray, int* doffset, int* ioffset, _threadargsproto_) {
        uint32_t dsize = 0;
        if (_p_vecRate)
        {
          dsize = (uint32_t)vector_capacity((IvocVect*)_p_vecRate);
        }
        if (iArray) {
                uint32_t* ia = ((uint32_t*)iArray) + *ioffset;
                IvocVect* vec = (IvocVect*)_p_vecRate;
                ia[0] = dsize;

                double *da = dArray + *doffset;
                double *dv;
                if(dsize)
                {
                  dv = vector_vec(vec);
                }
                int iInt;
                for (iInt = 0; iInt < dsize; ++iInt)
                {
                  da[iInt] = dv[iInt];
                }

                vec = (IvocVect*)_p_vecTbins;
                da = dArray + *doffset + dsize;
                if(dsize)
                {
                  dv = vector_vec(vec);
                }
                for (iInt = 0; iInt < dsize; ++iInt)
                {
                  da[iInt] = dv[iInt];
                }
        }
        *ioffset += 1;
        *doffset += 2*dsize;

}

static void bbcore_read(double* dArray, int* iArray, int* doffset, int* ioffset, _threadargsproto_) {
        uint32_t* ia = ((uint32_t*)iArray) + *ioffset;
        int dsize = ia[0];
        *ioffset += 1;

        double *da = dArray + *doffset;
        if(!_p_vecRate) {
          _p_vecRate = (double*)vector_new1(dsize);  /* works for dsize=0 */
        }
        assert(dsize == vector_capacity((IvocVect*)_p_vecRate));
        double *dv = vector_vec((IvocVect*)_p_vecRate);
        int iInt;
        for (iInt = 0; iInt < dsize; ++iInt)
        {
          dv[iInt] = da[iInt];
        }
        *doffset += dsize;

        da = dArray + *doffset;
        if(!_p_vecTbins) {
          _p_vecTbins = (double*)vector_new1(dsize);
        }
        assert(dsize == vector_capacity((IvocVect*)_p_vecTbins));
        dv = vector_vec((IvocVect*)_p_vecTbins);
        for (iInt = 0; iInt < dsize; ++iInt)
        {
          dv[iInt] = da[iInt];
        }
        *doffset += dsize;
}
ENDVERBATIM
