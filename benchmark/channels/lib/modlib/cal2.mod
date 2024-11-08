TITLE l-calcium channel
: l-type calcium channel


UNITS {
	(mA) = (milliamp)
	(mV) = (millivolt)

	FARADAY = (faraday) (coulomb)
	R = 8.3134 (joule/degC)
	KTOMV = .0853 (mV/degC)
}

PARAMETER {
	v (mV)
	celsius 	(degC)
	gcalbar=.003 (mho/cm2)
	ki=.001 (mM)
	cai = 50.e-6 (mM)
	cao = 2 (mM)
	q10 = 5
	mmin=0.2
	tfa = 1
	a0m =0.1
	zetam = 2
	vhalfm = 4
	gmm=0.1	
	ggk
}


NEURON {
	SUFFIX cal
	USEION ca READ cai,cao WRITE ica
        RANGE gcalbar,cai, ica, gcal, ggk
        RANGE minf,tau
}

STATE {
	m
}

ASSIGNED {
	ica (mA/cm2)
        gcal (mho/cm2)
        minf
        tau   (ms)
}

INITIAL {
	rate(v)
	m = minf
}

BREAKPOINT {
	SOLVE state METHOD cnexp
	gcal = gcalbar*m*m*h2(cai)
	ggk=ghk(v,cai,cao)
	ica = gcal*ggk

}

FUNCTION h2(cai(mM)) {
	h2 = ki/(ki+cai)
}


FUNCTION ghk(v(mV), ci(mM), co(mM)) (mV) {
        LOCAL nu,f

        f = KTF(celsius)/2
        nu = v/f
        ghk=-f*(1. - (ci/co)*exp(nu))*efun(nu)
}

FUNCTION KTF(celsius (DegC)) (mV) {
        KTF = ((25./293.15)*(celsius + 273.15))
}


FUNCTION efun(z) {
	if (fabs(z) < 1e-4) {
		efun = 1 - z/2
	}else{
		efun = z/(exp(z) - 1)
	}
}

FUNCTION alp(v(mV)) (1/ms) {
	alp = 15.69*(-1.0*v+81.5)/(exp((-1.0*v+81.5)/10.0)-1.0)
}

FUNCTION bet(v(mV)) (1/ms) {
	bet = 0.29*exp(-v/10.86)
}

FUNCTION alpmt(v(mV)) {
  alpmt = exp(0.0378*zetam*(v-vhalfm)) 
}

FUNCTION betmt(v(mV)) {
  betmt = exp(0.0378*zetam*gmm*(v-vhalfm)) 
}

DERIVATIVE state {  
        rate(v)
        m' = (minf - m)/tau
}

PROCEDURE rate(v (mV)) { :callable from hoc
        LOCAL a, b, qt
        qt=q10^((celsius-25)/10)
        a = alp(v)
        b = 1/((a + bet(v)))
        minf = a*b
	tau = betmt(v)/(qt*a0m*(1+alpmt(v)))
	if (tau<mmin/qt) {tau=mmin/qt}
}
