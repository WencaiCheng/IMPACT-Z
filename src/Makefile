#****************************
#*** Copyright Notice ***
#IMPACT-Z,Copyright (c) 2016, The Regents of the University of California, through
#Lawrence Berkeley National Laboratory (subject to receipt of any required approvals
#from the U.S. Dept. of Energy).  All rights reserved.
#If you have questions about your rights to use or distribute this software,
#please contact Berkeley Lab's Innovation & Partnerships Office at  IPO@lbl.gov.
#NOTICE.  This Software was developed under funding from the U.S. Department of Energy
#and the U.S. Government consequently retains certain rights. As such, the U.S. Government
#has been granted for itself and others acting on its behalf a paid-up, nonexclusive, irrevocable,
#worldwide license in the Software to reproduce, distribute copies to the public, prepare
#derivative works, and perform publicly and display publicly, and to permit other to do so.
#****************************

#*****************************************************
#  General Makefile
#
#*****************************************************

#**************************************************************************
# Macros defining the Fortran, C/C++ compiler and linker.

CC = mpif90
LINK = mpif90
#FFLAGS = -O3
FFLAGS = -g

#**************************************************************************
# List of .o files that EXENAME depends on.  Edit as appropriate for MP.

OBJS = src/mpistub.o \
	src/DataStruct/NumConst.o src/DataStruct/PhysConst.o src/DataStruct/Pgrid.o \
    src/DataStruct/Data.o \
    src/Func/Timer.o src/Func/Transpose.o src/Func/Fldmger.o src/Func/Ptclmger.o  src/Func/FFT.o src/Func/math.o \
        src/Appl/BPM.o src/Appl/CCL.o src/Appl/CCDTL.o src/Appl/DTL.o src/Appl/SC.o \
    src/Appl/DriftTube.o src/Appl/Quadrupole.o src/Appl/ConstFoc.o src/Appl/SolRF.o \
    src/Appl/Sol.o src/Appl/Dipole.o src/Appl/Multipole.o src/Appl/EMfld.o src/Appl/TWS.o src/Appl/BeamLineElem.o \
    src/Appl/CompDom.o src/Appl/Field.o src/Appl/BeamBunch.o  src/Appl/Distribution.o \
    src/Contrl/Input.o src/Contrl/Output.o src/Contrl/AccSimulator.o src/Contrl/main.o

OBJS2 = mpistub.o \
	NumConst.o PhysConst.o Pgrid.o Data.o \
    Timer.o Transpose.o Fldmger.o Ptclmger.o FFT.o math.o \
	BPM.o CCL.o CCDTL.o DTL.o SC.o DriftTube.o Quadrupole.o ConstFoc.o \
	SolRF.o Sol.o Dipole.o Multipole.o EMfld.o TWS.o BeamLineElem.o CompDom.o Field.o BeamBunch.o Distribution.o \
	Input.o Output.o AccSimulator.o main.o	


#**************************************************************************
# Change this line if you don't like 'a.out'.

EXEOLD = ImpactZexe

#************************************************************************
# disable predefined suffixes and define your own set of allowed suffixes
 .SUFFIXES:
 .SUFFIXES: .o .f .F .c .f90 .F90

#*************************************************************************
# inference rules (how to compile object files that have no explicit rules)
#  $* = name part of target
#  $@ = full target name
#  $< = dependent name

.f90.o:
	$(CC) -c $(FFLAGS) $<

#**************************************************************************
# Rules for building EXENAME from OBJS and OBJS from your source.

all:  $(OBJS) $(OBJS2) 
	$(LINK) -o $(EXEOLD) $(OBJS2) 

#************************************************************************
# if you wish to compile a certain object with different flags
# or in some special way, then specify the target & dependency explicitly
# the following line say Timer.o is depended on Timer.f90
#Timer.o: Timer.f90
#	$(CC) -c -O3 Timer.f90

	cp  AccSimulator.o main.o Input.o Output.o ./src/Contrl
	cp  BPM.o CCL.o CCDTL.o DTL.o SC.o DriftTube.o Quadrupole.o \
	    ConstFoc.o BeamLineElem.o BeamBunch.o Field.o CompDom.o \
	    Multipole.o Distribution.o SolRF.o Sol.o Dipole.o TWS.o EMfld.o ./src/Appl
	cp  Timer.o Transpose.o Fldmger.o Ptclmger.o FFT.o math.o ./src/Func
	cp  NumConst.o PhysConst.o Data.o Pgrid.o ./src/DataStruct
##***********************************************************************
clean:
#	-rm *.o $(EXEOLD) *.mod */*.o
	-rm -f *.o *.mod */*.o ./src/*/*.o
