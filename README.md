# use ID flag to control elements behavior
use ID flag to choose linear or nonlinear map, to control collective effects behavior.
## quad
- (-10,0),        linear map, recommend using ID=-5
- less than -10,  nonlinear map, recommend using ID=-15

<br/>usage:

quad length=0.3, steps=1, map steps=1, K1=-4, ID=-5, radius=0.014 

0.30 1 1 1 -4 -5 0.014 0 0 0 0 0 /

## dipole
- (0,50),         linear map, ID=25
- (50,100),       linear map + csr, ID=75
- (100,200),      nonlinear map, recommend using ID=150
- \>200,          nonlinear map + CSR, recommend using ID=250

<br/>usage: ID=25

0.200000 1 1 4 1.105843492438955e-01 0 25 1.0 0.000000000000000e+00 1.105843492438955e-01 0 0 0 /

## drift
add an addition parameter for ID flag.
- ID<0, linear map, ID=-1
- otherwise, real map, ID left ungiven use real map.

<br/>usage:ID=1

10 1 1 0 1.0 -1 /

## 103 cavity
when ID<0, the 103 element use simple sinusoidal RF cavity model. Parameters following 103 is different from manual.
- -0.5,           linear map
- -1.0,           nonlinear map for middle drift and end focus, drift using individual particle informations.

<br/>usage:ID=-0.5 

acceleration gradient=5.97474936319844610989e+06 V/m, frequency=1.3e9 Hz, phase=-30 degree, ID=-0.5 use linear map

1.0 1 1 103     5.97474936319844610989e+06     1.3e+09    -30 -0.5 1.0 /

## space charge 
current in 11th line of ImpactZ.in file:
- current=0, off 
- current .ne. 0, on
 
## -41 element, read-in RF cavity structure wakefield
this element should be used in pair, turn on in previous of 103 cavity element, and turn off after 103 cavity.
- ID=-1, turn OFF
- ID=(0,10), only Lwake, ID=5
- ID=(10,20), only Twake, ID=15
- ID\>20, Lwake + Twake, ID=25

<br/>usage: ID=15, ID=-1

add structure wakefield (given in rfdata41.in file) for 103 cavity, and only turn ON Twake

0 0 1 -41 1.0 41 15 /

1.0 1 1 103     5.97474936319844610989e+06     1.3e+09    -30 -0.5 1.0 /

0 0 1 -41 1.0 41 -1 / 

# add new distribution type
- type 45, cylinder uniform distribution based on pseudorandom number, gaussian distribution of momentum.

- type 46, cylinder uniform distribution with sinusoidal density modulation, based on halton sequence, gaussian distribution of momentum.
  - alphaxyz=0, which means alpha value settings in 8th-10th lines are ignored, and also: mismatch=1 and offset=0
  - offsetPhase and offsetEnergy are used as (eta,lambda), eta is density modulation depth, lambda is wavelength (m)
  - no gaussian end distribution added yet

# how to compile IMPACT-Z to parallel version
- comment out the line "use mpistub" in Contrl/Input.f90, DataStruct/Data.f90,
DataStruct/Pgrid.f90, DataStruct/PhysConst.f90, and Func/Timer.f90.
- remove the mpif.h file under the Appl, Control, DataStruct, and Func directories.
- delete mpistub.o in the Makefile
- use the appropriate parallel fortran compiler such as mpif90.
