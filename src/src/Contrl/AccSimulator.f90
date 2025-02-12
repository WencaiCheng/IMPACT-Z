!----------------------------------------------------------------
!*** Copyright Notice ***
!IMPACT-Z,Copyright (c) 2016, The Regents of the University of California, through
!Lawrence Berkeley National Laboratory (subject to receipt of any required approvals
!from the U.S. Dept. of Energy).  All rights reserved.
!If you have questions about your rights to use or distribute this software,
!please contact Berkeley Lab's Innovation & Partnerships Office at  IPO@lbl.gov.
!NOTICE.  This Software was developed under funding from the U.S. Department of Energy
!and the U.S. Government consequently retains certain rights. As such, the U.S. Government
!has been granted for itself and others acting on its behalf a paid-up, nonexclusive, irrevocable,
!worldwide license in the Software to reproduce, distribute copies to the public, prepare
!derivative works, and perform publicly and display publicly, and to permit other to do so.
!-------------------------
! AccSimulatorclass: Linear accelerator simulator class in CONTROL layer.
! Author: Ji Qiang, LBNL
! Description: This class defines functions to set up the initial beam 
!              particle distribution, field information, computational
!              domain, beam line element lattice and run the dynamics
!              simulation through the system.
! Comments: 
!----------------------------------------------------------------
      module AccSimulatorclass
        use Pgrid2dclass
        use CompDomclass
        use FieldQuantclass
        use BeamLineElemclass
        use Ptclmgerclass
        use BeamBunchclass
        use Timerclass
        use Inputclass
        use Outputclass
        use Dataclass
        use PhysConstclass
        use NumConstclass
        use Distributionclass
        use MathModule
        implicit none
        !# of phase dim., num. total and local particles, int. dist. 
        !and restart switch, error study switch, substep for space-charge
        !switch
        integer, private :: Dim, Np, Nplocal,Flagdist,Rstartflg,Flagerr,&
                            Flagsubstep 

        !# of num. total x, total and local y mesh pts., type of BC, 
        !# of beam elems, type of integrator.
        integer, private :: Nx,Ny,Nz,Nxlocal,Nylocal,Nzlocal,Flagbc,&
                            Nblem,Flagmap,Flagdiag
        !biaobin, new line
        !simutype=1, linac 
        !simutype=2, ring
        integer, private :: Flagsc,turn,outfq,simutype
        !biaobin, get the RingLength
        real*8, private :: Lc

        !# of processors in column and row direction.
        integer, private :: npcol, nprow

        !beam current, kin. energy, part. mass, and charge.
        double precision, private :: Bcurr,Bkenergy,Bmass,Bcharge,Bfreq,&
                                     Perdlen

        !conts. in init. dist.
        double precision, private, dimension(21) :: distparam

        !1d logical processor array.
        type (Pgrid2d), private :: grid2d

        !beam particle object and array.
        type (BeamBunch), private :: Bpts

        !beam charge density and field potential arrays.
        type (FieldQuant), private :: Potential

        !geometry object.
        type (CompDom), private :: Ageom

        !beam line element array.
        type (BPM),target,dimension(Nbpmmax) :: beamln0
        type (DriftTube),target,dimension(Ndriftmax) :: beamln1
        type (Quadrupole),target,dimension(Nquadmax) :: beamln2
        type (DTL),target,dimension(Ndtlmax) :: beamln3
        type (CCDTL),target,dimension(Nccdtlmax) :: beamln4
        type (CCL),target,dimension(Ncclmax) :: beamln5
        type (SC),target,dimension(Nscmax) :: beamln6
        type (ConstFoc),target,dimension(Ncfmax) :: beamln7
        type (SolRF),target,dimension(Nslrfmax) :: beamln8
        type (Sol),target,dimension(Nslmax) :: beamln9
        type (Dipole),target,dimension(Ndipolemax) :: beamln10
        type (EMfld),target,dimension(Ncclmax) :: beamln11
        type (Multipole),target,dimension(Nquadmax) :: beamln12
        type (TWS),target,dimension(Nscmax) :: beamln13
        type (BeamLineElem),private,dimension(Nblemtmax)::Blnelem
        !beam line element period.
        interface construct_AccSimulator
          module procedure init_AccSimulator
        end interface

        !//total # of charge state
        integer :: nchrg
        !//current list of charge state.
        !//charge/mass list of charge state.
        double precision, dimension(100) :: currlist,qmcclist
        !//number of particles of charge state.
        integer, dimension(100) :: nptlist
        integer, allocatable, dimension(:) :: Nptlist0
        double precision, allocatable, dimension(:) :: currlist0,qmcclist0
        integer :: iend,jend,ibalend,nstepend
        real*8 :: zend
      contains
        !set up objects and parameters.
        subroutine init_AccSimulator(time)
        implicit none
        include 'mpif.h'
        integer :: i,test1,test2,j
        integer :: myid,myidx,myidy,ierr,inb,jstp
        integer, allocatable, dimension(:) :: bnseg,bmpstp,bitype
        double precision, allocatable, dimension(:) :: blength,val1,&
        val2, val3,val4,val5,val6,val7,val8,val9,val10,val11,val12,val13,val14,&
        val15,val16,val17,val18,val19,val20,val21,val22,val23,val24
        double precision :: time
        double precision :: t0
        double precision :: z,xrad,yrad,phsini
        double precision, dimension(5) :: tmpdr 
        double precision, dimension(5) :: tmpcf 
        double precision, dimension(12) :: tmpbpm 
        double precision, dimension(9) :: tmpquad
        double precision, dimension(17) :: tmpdipole
        double precision, dimension(10) :: tmpmulpole 
        double precision, dimension(11) :: tmprf
        double precision, dimension(15) :: tmpslrf
        double precision, dimension(14) :: tmp13
        double precision, dimension(25) :: tmpdtl
        integer :: iqr,idr,ibpm,iccl,iccdtl,idtl,isc,icf,islrf,isl,idipole,&
                   iemfld,myrank,imultpole,itws,nfileout

        !start up MPI.
        call init_Input(time)

        ! initialize Timer.
        call construct_Timer(0.0d0)

        call starttime_Timer(t0)

        !Flagmap = 0

        nptlist = 0
        currlist = 0.0
        qmcclist = 0.0
!-------------------------------------------------------------------
! get all global input parameters.
        call in_Input(Dim,Np,Nx,Ny,Nz,Flagbc,Flagdist,Rstartflg,&
              Flagmap,distparam,21,Bcurr,Bkenergy,Bmass,Bcharge,&
        Bfreq,xrad,yrad,Perdlen,Nblem,npcol,nprow,Flagerr,Flagdiag,&
        Flagsubstep,phsini,nchrg,nptlist,currlist,qmcclist,Flagsc,&
        turn,outfq,Lc,simutype)

        allocate(nptlist0(nchrg))
        allocate(currlist0(nchrg))
        allocate(qmcclist0(nchrg))
        do i = 1, nchrg
          nptlist0(i) =  nptlist(i)
          currlist0(i) =  currlist(i)
          qmcclist0(i) =  qmcclist(i)
        enddo
!-------------------------------------------------------------------
! construct 2D logical processor Cartesian coordinate
        call construct_Pgrid2d(grid2d,MPI_COMM_WORLD,nprow,npcol)
        call getpost_Pgrid2d(grid2d,myid,myidy,myidx)
        if(myid.eq.0) then
          !print*,"Start simulation:"
          print*,"!-----------------------------------------------------------"
          print*,"! IMPACT-Z: Integrated Map and PArticle Tracking Code: Version 2.1"
          print*,"! Copyright of The Regents of the University of California"
          print*,"!-----------------------------------------------------------"
        endif

        !construct Constants class.
        call construct_PhysConst(Bfreq)

!-------------------------------------------------------------------
! construct computational domain CompDom class and get local geometry 
! information on each processor.
        call construct_CompDom(Ageom,distparam,21,Flagdist,&
               Nx,Ny,Nz,grid2d,nprow,npcol,Flagbc,xrad,yrad,Perdlen)

!-------------------------------------------------------------------
! initialize Data class.
        call init_Data()

!-------------------------------------------------------------------
! construct BeamBunch class.
        call construct_BeamBunch(Bpts,Bcurr,Bkenergy,Bmass,Bcharge,&
                            Np,phsini)

!-------------------------------------------------------------------
! sample initial particle distribution.
        call MPI_BARRIER(MPI_COMM_WORLD,ierr)
        call MPI_COMM_RANK(MPI_COMM_WORLD,myrank,ierr)

!-------------------------------------------------------------------
! construct FieldQuant class objects.
        call construct_FieldQuant(Potential,Nx,Ny,Nz,Ageom,grid2d)

!-------------------------------------------------------------------
! construct beam line elements.
        allocate(blength(Nblem),bnseg(Nblem),bmpstp(Nblem))
        allocate(bitype(Nblem))
        allocate(val1(Nblem),val2(Nblem),val3(Nblem),val4(Nblem))
        allocate(val5(Nblem),val6(Nblem),val7(Nblem),val8(Nblem))
        allocate(val9(Nblem),val10(Nblem),val11(Nblem),val12(Nblem))
        allocate(val13(Nblem),val14(Nblem),val15(Nblem),val16(Nblem))
        allocate(val17(Nblem),val18(Nblem),val19(Nblem),val20(Nblem))
        allocate(val21(Nblem),val22(Nblem),val23(Nblem),val24(Nblem))

        call in_Input(Nblem,blength,bnseg,bmpstp,bitype,val1,val2,val3,&
        val4,val5,val6,val7,val8,val9,val10,val11,val12,val13,val14,&
        val15,val16,val17,val18,val19,val20,val21,val22,val23,val24)

        iccl = 0
        iccdtl = 0
        idtl = 0
        isc = 0
        idr = 0
        iqr = 0
        ibpm = 0
        icf = 0
        islrf = 0
        isl = 0
        idipole = 0
        iemfld = 0
        imultpole = 0
        itws = 0
        do i = 1, Nblem
          if(bitype(i).lt.0) then
            ibpm = ibpm + 1
            call construct_BPM(beamln0(ibpm),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmpbpm(1) = 0.0
            !biaobin, val1 is parameter value after type, i.e. radius
            tmpbpm(2) = val1(i)
            tmpbpm(3) = val2(i)
            tmpbpm(4) = val3(i)
            tmpbpm(5) = val4(i)
            tmpbpm(6) = val5(i)
            tmpbpm(7) = val6(i)
            tmpbpm(8) = val7(i)
            tmpbpm(9) = val8(i)
            tmpbpm(10) = val9(i)
            tmpbpm(11) = val10(i)
            tmpbpm(12) = val11(i)
            call setparam_BPM(beamln0(ibpm),tmpbpm)
            Blnelem(i) = assign_BeamLineElem(beamln0(ibpm))
            if(bitype(i).eq.-7) nfileout=bmpstp(i)
          else if(bitype(i).eq.0) then
            idr = idr + 1
            call construct_DriftTube(beamln1(idr),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmpdr(1) = 0.0
            tmpdr(2) = val1(i)
            tmpdr(3) = val2(i) !additional parameter after drift pip
                               !radius, ID<0, linear map; otherwise real
                               !map
            tmpdr(4) = val3(i)
            tmpdr(5) = val4(i)
            call setparam_DriftTube(beamln1(idr),tmpdr)
            Blnelem(i) = assign_BeamLineElem(beamln1(idr))
          else if(bitype(i).eq.1) then
            iqr = iqr + 1
            call construct_Quadrupole(beamln2(iqr),bnseg(i),bmpstp(i),&
            bitype(i),blength(i))
            tmpquad(1) = 0.0
            tmpquad(2) = val1(i)
            tmpquad(3) = val2(i)
            tmpquad(4) = val3(i)
            tmpquad(5) = val4(i)
            tmpquad(6) = val5(i)
            tmpquad(7) = val6(i)
            tmpquad(8) = val7(i)
            tmpquad(9) = val8(i)
            call setparam_Quadrupole(beamln2(iqr),tmpquad)
            Blnelem(i) = assign_BeamLineElem(beamln2(iqr))
          else if(bitype(i).eq.2) then
            icf = icf + 1
            call construct_ConstFoc(beamln7(icf),bnseg(i),bmpstp(i),&
            bitype(i),blength(i))
            tmpcf(1) = 0.0
            tmpcf(2) = val1(i)
            tmpcf(3) = val2(i)
            tmpcf(4) = val3(i)
            tmpcf(5) = val4(i)
            call setparam_ConstFoc(beamln7(icf),tmpcf)
            Blnelem(i) = assign_BeamLineElem(beamln7(icf))
          else if(bitype(i).eq.3) then
            isl = isl + 1
            call construct_Sol(beamln9(isl),bnseg(i),bmpstp(i),&
            bitype(i),blength(i))
            tmpquad(1) = 0.0
            tmpquad(2) = val1(i)
            tmpquad(3) = val2(i)
            tmpquad(4) = val3(i)
            tmpquad(5) = val4(i)
            tmpquad(6) = val5(i)
            tmpquad(7) = val6(i)
            tmpquad(8) = val7(i)
            tmpquad(9) = val8(i)
            call setparam_Sol(beamln9(isl),tmpquad)
            Blnelem(i) = assign_BeamLineElem(beamln9(isl))
          else if(bitype(i).eq.4 .or. bitype(i).eq.5) then
            idipole = idipole + 1
            call construct_Dipole(beamln10(idipole),bnseg(i),bmpstp(i),&
            bitype(i),blength(i))
            tmpdipole(1) = 0.0
            tmpdipole(2) = val1(i)
            tmpdipole(3) = val2(i)
            tmpdipole(4) = val3(i)
            tmpdipole(5) = val4(i)
            tmpdipole(6) = val5(i)
            tmpdipole(7) = val6(i)
            tmpdipole(8) = val7(i)
            tmpdipole(9) = val8(i)
            tmpdipole(10) = val9(i)
            tmpdipole(11) = val10(i)
            tmpdipole(12) = val11(i)
            tmpdipole(13) = val12(i)
            tmpdipole(14) = val13(i)
            tmpdipole(15) = val14(i)
            tmpdipole(16) = val15(i)
            tmpdipole(17) = val16(i)

            call setparam_Dipole(beamln10(idipole),tmpdipole)
            Blnelem(i) = assign_BeamLineElem(beamln10(idipole))
          else if(bitype(i).eq.6) then  
            !bbl, Ji seems move this element to BPM type(minus id).
            !change it to 6, leave 5 for CSRKICK element
            imultpole = imultpole + 1
            call construct_Multipole(beamln12(imultpole),bnseg(i),bmpstp(i),&
            bitype(i),blength(i))
            tmpmulpole(1) = 0.0
            tmpmulpole(2) = val1(i)
            tmpmulpole(3) = val2(i)
            tmpmulpole(4) = val3(i)
            tmpmulpole(5) = val4(i)
            tmpmulpole(6) = val5(i)
            tmpmulpole(7) = val6(i)
            tmpmulpole(8) = val7(i)
            tmpmulpole(9) = val8(i)
            tmpmulpole(10) = val9(i)
            call setparam_Multipole(beamln12(imultpole),tmpmulpole)
            Blnelem(i) = assign_BeamLineElem(beamln12(imultpole))
          else if(bitype(i).eq.101) then
            idtl = idtl + 1
            call construct_DTL(beamln3(idtl),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmpdtl(1) = 0.0
            tmpdtl(2) = val1(i) 
            tmpdtl(3) = val2(i) 
            tmpdtl(4) = val3(i) 
            tmpdtl(5) = val4(i) 
            tmpdtl(6) = val5(i) 
            tmpdtl(7) = val6(i) 
            tmpdtl(8) = val7(i) 
            tmpdtl(9) = val8(i) 
            tmpdtl(10) = val9(i) 
            tmpdtl(11) = val10(i) 
            tmpdtl(12) = val11(i) 
            tmpdtl(13) = val12(i) 
            tmpdtl(14) = val13(i) 
            tmpdtl(15) = val14(i) 
            tmpdtl(16) = val15(i) 
            tmpdtl(17) = val16(i) 
            tmpdtl(18) = val17(i) 
            tmpdtl(19) = val18(i) 
            tmpdtl(20) = val19(i) 
            tmpdtl(21) = val20(i) 
            tmpdtl(22) = val21(i) 
            tmpdtl(23) = val22(i) 
            tmpdtl(24) = val23(i) 
            tmpdtl(25) = val24(i) 
            call setparam_DTL(beamln3(idtl),tmpdtl)
            Blnelem(i) = assign_BeamLineElem(beamln3(idtl))
          else if(bitype(i).eq.102) then
            iccdtl = iccdtl + 1
            call construct_CCDTL(beamln4(iccdtl),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmprf(1) = 0.0
            tmprf(2) = val1(i) 
            tmprf(3) = val2(i) 
            tmprf(4) = val3(i) 
            tmprf(5) = val4(i) 
            tmprf(6) = val5(i) 
            tmprf(7) = val6(i)
            tmprf(8) = val7(i) 
            tmprf(9) = val8(i) 
            tmprf(10) = val9(i) 
            tmprf(11) = val10(i) 
            call setparam_CCDTL(beamln4(iccdtl),tmprf)
            Blnelem(i) = assign_BeamLineElem(beamln4(iccdtl))
          else if(bitype(i).eq.103) then
            iccl = iccl + 1
            call construct_CCL(beamln5(iccl),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmprf(1) = 0.0
            tmprf(2) = val1(i) 
            tmprf(3) = val2(i) 
            tmprf(4) = val3(i) 
            tmprf(5) = val4(i) 
            tmprf(6) = val5(i) 
            tmprf(7) = val6(i) 
            tmprf(8) = val7(i) 
            tmprf(9) = val8(i) 
            tmprf(10) = val9(i) 
            tmprf(11) = val10(i) 
            call setparam_CCL(beamln5(iccl),tmprf)
            Blnelem(i) = assign_BeamLineElem(beamln5(iccl))
          else if(bitype(i).eq.104) then
            isc = isc + 1
            call construct_SC(beamln6(isc),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmprf(1) = 0.0
            tmprf(2) = val1(i) 
            tmprf(3) = val2(i) 
            tmprf(4) = val3(i) 
            tmprf(5) = val4(i) 
            tmprf(6) = val5(i) 
            tmprf(7) = val6(i)
            tmprf(8) = val7(i) 
            tmprf(9) = val8(i) 
            tmprf(10) = val9(i) 
            tmprf(11) = val10(i) 
            call setparam_SC(beamln6(isc),tmprf)
            Blnelem(i) = assign_BeamLineElem(beamln6(isc))
          else if(bitype(i).eq.105) then
            islrf = islrf + 1
            call construct_SolRF(beamln8(islrf),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmpslrf(1) = 0.0
            tmpslrf(2) = val1(i) 
            tmpslrf(3) = val2(i) 
            tmpslrf(4) = val3(i) 
            tmpslrf(5) = val4(i) 
            tmpslrf(6) = val5(i) 
            tmpslrf(7) = val6(i) 
            tmpslrf(8) = val7(i) 
            tmpslrf(9) = val8(i) 
            tmpslrf(10) = val9(i) 
            tmpslrf(11) = val10(i) 
            tmpslrf(12) = val11(i) 
            tmpslrf(13) = val12(i) 
            tmpslrf(14) = val13(i) 
            tmpslrf(15) = val14(i) 
            call setparam_SolRF(beamln8(islrf),tmpslrf)
            Blnelem(i) = assign_BeamLineElem(beamln8(islrf))
          else if(bitype(i).eq.106) then
            itws = itws + 1
            call construct_TWS(beamln13(itws),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmpslrf(1) = 0.0
            tmpslrf(2) = val1(i) 
            tmpslrf(3) = val2(i) 
            tmpslrf(4) = val3(i) 
            tmpslrf(5) = val4(i) 
            tmpslrf(6) = val5(i) 
            tmpslrf(7) = val6(i) 
            tmpslrf(8) = val7(i) 
            tmpslrf(9) = val8(i) 
            tmpslrf(10) = val9(i) 
            tmpslrf(11) = val10(i) 
            tmpslrf(12) = val11(i) 
            tmpslrf(13) = val12(i) 
            tmpslrf(14) = val13(i) 
            tmpslrf(15) = val14(i) 
            call setparam_TWS(beamln13(itws),tmpslrf)
            Blnelem(i) = assign_BeamLineElem(beamln13(itws))
          else if(bitype(i).eq.110) then
            iemfld = iemfld + 1
            call construct_EMfld(beamln11(iemfld),bnseg(i),bmpstp(i),&
                 bitype(i),blength(i))
            tmp13(1) = 0.0
            tmp13(2) = val1(i) 
            tmp13(3) = val2(i) 
            tmp13(4) = val3(i) 
            tmp13(5) = val4(i) 
            tmp13(6) = val5(i) 
            tmp13(7) = val6(i) 
            tmp13(8) = val7(i) 
            tmp13(9) = val8(i) 
            tmp13(10) = val9(i) 
            tmp13(11) = val10(i) 
            tmp13(12) = val11(i) 
            tmp13(13) = val12(i) 
            tmp13(14) = val13(i) 
            call setparam_EMfld(beamln11(iemfld),tmp13)
            Blnelem(i) = assign_BeamLineElem(beamln11(iemfld))
            !print*,"tmp13_12: ",tmp13(12),tmp13(13)
          else
          endif 
        enddo
        iend = 0
        jend = 0
        ibalend = 0
        nstepend = 0
        zend = 0.0

        if(Rstartflg.eq.1) then
          call inpoint_Output(myid+nfileout,Bpts,zend,iend,jend,ibalend,nstepend,&
               nprow,npcol,Ageom,Nx,Ny,Nz,myidx,myidy,Np)
          if(myid.eq.0)print*,"rstart at: ",zend,iend,jend,ibalend,nstepend
        else
          call sample_Dist(Bpts,distparam,21,Flagdist,Ageom,grid2d,Flagbc,&
                           nchrg,nptlist0,qmcclist0,currlist0)
        endif
        call MPI_BARRIER(MPI_COMM_WORLD,ierr)
        if(myid.eq.0) print*,"pass generating initial distribution..."

        !get local particle number and mesh number on each processor.
        call getnpt_BeamBunch(Bpts,Nplocal)

!-------------------------------------------------------------------
        call MPI_BARRIER(MPI_COMM_WORLD,ierr)
        if(myid.eq.0) print*,"pass setting up lattice..."

        deallocate(blength,bnseg,bmpstp,bitype)
        deallocate(val1,val2,val3,val4,val5,val6,val7,val8,val9)
        deallocate(val10,val11,val12,val13,val14,val15,val16)
        deallocate(val17,val18,val19,val20,val21,val22,val23)
        deallocate(val24)

        t_init = t_init + elapsedtime_Timer(t0)

        end subroutine init_AccSimulator

        !Run beam dynamics simulation through accelerator.
        subroutine run_AccSimulator()
        implicit none
        include 'mpif.h'
        integer :: i,j,bnseg,bmpstp,bitype
        integer :: myid,myidx,myidy,comm2d,commcol,commrow,npx,npy,&
                   totnp,ierr,nylcr,nzlcr
        integer :: nbal,ibal,nstep,ifile
        integer :: tmpfile,nfile
        integer, dimension(3) :: lcgrid
        integer, allocatable, dimension(:) :: lctabnmx,lctabnmy
        integer, allocatable, dimension(:,:,:) :: temptab
        double precision :: z0,z,tau1,tau2,blength,t0
        double precision, allocatable, dimension(:,:) :: lctabrgx, lctabrgy
        double precision, dimension(6) :: lcrange, range, ptrange,ptref
        double precision, dimension(3) :: msize
        double precision :: hy,hz,ymin,zmin,piperad,zedge
        double precision :: tmp1,tmp2,tmp3,tmp4,rfile,factor
        double precision, allocatable, dimension(:,:,:) :: chgdens
        integer :: nmod,k,ii,jj
        !double precision :: sumtest, sumtest2, sumtest3
        double precision, dimension(12) :: drange
        double precision, dimension(3) :: al0,ga0,epson0
        double precision :: tg,tv,gam,piperad2
        integer :: nsubstep,integerSamplePeriod,Flagbctmp,phaseopt
        double precision :: zz,vref
        !parameters for stripper modeling
        double precision :: beta0,gamma0,gambetz
        double precision, allocatable, dimension(:,:) :: tmpptcs
        double precision :: rwkinq,rwkinf,avgw
        integer :: itmp,jtmp
        !for WAKEFIELD purpose -----------------------------------------
        !double precision, allocatable, dimension(:,:,:) :: exg,eyg,ezg
        !double precision, allocatable, dimension(:) :: ztable,zdisp,&
        double precision, allocatable, dimension(:) :: &
            denszlc,densz,exwake,eywake,ezwake,xwakelc,xwakez,ywakelc,ywakez,&
            denszp,denszpp
        double precision, allocatable, dimension(:,:) :: sendensz,&
                                                         recvdensz
        double precision :: xx,yy,t3dstart,rr,tmger,tmpwk
        double precision  :: aawk,ggwk,lengwk,hzwake,ab
        integer :: flagwake,flagwakeread,flagwaketype,flagbtw,iizz,iizz1,kz,kadd,ipt,flagcsr
        !for bending magnet Transport transfer matrix implementation
        double precision :: hd0,hd1,dstr1,dstr2,angF,tanphiF,tanphiFb,&
            angB,tanphiB,tanphiBb,hF,hB,qm0,qmi,psi1,psi2,r0,gamn,gambet,&
            angz,dpi,ang0,hgap,betai,rcpgammai,ssll
        double precision, dimension(6) :: ptarry
        double precision, dimension(17) :: dparam
        real*8 :: xradmin,xradmax,yradmin,yradmax
        real*8 :: zwkmin,bendlen,zbleng
        real*8 :: tmplump,b0,qmass,qchg,pmass, alphax0,betax0,alphay0,betay0,scwk
        integer :: nslice,ihlf
        real*8 :: rsiglaser,rlaserwvleng
        real*8, dimension(2) :: xylc,xygl
        real*8 :: xsig2,ysig2,freqlaser,harm,sigx2,ezlaser
        real*8 :: tmp, t_ref
        integer :: ith_turn 
        real*8, dimension(3) :: vhphi 
        character(len=20) :: filename,formatstr
        integer :: csrout,csrfile
        integer :: wakeconvout=0,wakeconvfile=0
        integer :: scout=0,scfile=0
        
!-------------------------------------------------------------------
! prepare initial parameters, allocate temporary array.
!        iend = 0
!        ibalend = 0
!        nstepend = 0
!        zend = 0.0
        flagbtw = 0
        scwk = 1.0d0

        call getpost_Pgrid2d(grid2d,myid,myidy,myidx)
        call getcomm_Pgrid2d(grid2d,comm2d,commcol,commrow)
        call getsize_Pgrid2d(grid2d,totnp,npy,npx)

        call MPI_BARRIER(comm2d,ierr)
        call starttime_Timer(t0)

        allocate(lctabnmx(0:npx-1))
        allocate(lctabnmy(0:npy-1))
        allocate(lctabrgx(2,0:npx-1))
        allocate(lctabrgy(2,0:npy-1))
        allocate(temptab(2,0:npx-1,0:npy-1))
        allocate(tmpptcs(1,1))

        nbal = 5
        ibal = ibalend
        nstep = nstepend
        z = zend

        !print*,totnp,Bpts%Nptlocal,Bpts%Npt
        tmp = abs(totnp*Bpts%Nptlocal - Bpts%Npt)
        if ( tmp > totnp ) then
          print*,"WARNING, particle number given in ImpactZ.in &
                  not consistent with particle.in."  
          print*,"tracking particle number=", totnp*Bpts%Nptlocal 
          print*,"particle number read from ImpactZ.in = ",Bpts%Npt
          stop      
        endif

        if(Flagdiag.eq.1) then
            call diagnostic1_Output(z,Bpts,nchrg,nptlist0,turn,0)
        else
            call diagnostic2_Output(Bpts,z,nchrg,nptlist0)
        endif

        allocate(chgdens(1,1,1))
!-------------------------------------------------------------------
! prepare for round pipe, open longitudinal
        if(Flagbc.eq.3) then
          if(myid.eq.0) then
            print*,"Poisson solver not available for this boundary &
                    conditions"
            stop
          endif
        endif

        !assign initial storage used for wakefield calculation
        !allocate(ztable(0:npx-1))
        !allocate(zdisp(0:npx-1))
        !allocate(denszlc(1))
        !allocate(densz(1))
        !allocate(xwakelc(1))
        !allocate(xwakez(1))
        !allocate(ywakelc(1))
        !allocate(ywakez(1))
        allocate(denszlc(Nz))
        allocate(densz(Nz))
        allocate(denszp(Nz))
        allocate(denszpp(Nz))
        allocate(xwakelc(Nz))
        allocate(xwakez(Nz))
        allocate(ywakelc(Nz))
        allocate(ywakez(Nz))
        allocate(recvdensz(Nz,2))
        allocate(sendensz(Nz,2))
        allocate(exwake(Nz))
        allocate(eywake(Nz))
        allocate(ezwake(Nz))
        exwake = 0.0
        eywake = 0.0
        ezwake = 0.0
        flagwake = 0
        flagwakeread = 0
        flagwaketype=-1
        flagcsr = 0
        aawk = 0.05
        ggwk = 0.05
        lengwk = 0.1

        zbleng = 0.0d0
!-------------------------------------------------------------------
! start looping through 'Nblem' beam line elements.
!
        tmpfile = 0
        
        !2021-03-12, loop for multi-turns tracking  
        !outfq: -2,-8 element output every ofreq turns
        do ith_turn=1,turn       
          if(myid.eq.0 .and. turn.gt.1) then
              print*,"turn:",ith_turn
          endif
        do i = iend+1, Nblem
          !print*,"wakeconvout,wakeconvfile=",wakeconvout,wakeconvfile

          call getparam_BeamLineElem(Blnelem(i),blength,bnseg,bmpstp,&
                                     bitype)
          if(myid.eq.0 .and. turn.eq.1) then
            print*,"enter elment (type code): ",i,bitype
          endif
          call getradius_BeamLineElem(Blnelem(i),piperad,piperad2)
          if(bitype.eq.4) then
            piperad= 100.0
            piperad2= 100.0
          endif
          nsubstep = bmpstp
          nfile = 0
          tau1 = 0.0d0
          if(bitype.ge.0) tau1 = 0.5d0*blength/bnseg
          tau2 = 2.0d0*tau1
          !print*,"flagwakeread, flagwake, flagwaketype=", &
          !        flagwakeread,flagwake, flagwaketype
          !print*,"tau, ",i,tau1,blength,bnseg,bitype,z

          if(bitype.eq.0) then
            call getparam_BeamLineElem(Blnelem(i),4,tmp1)
            call getparam_BeamLineElem(Blnelem(i),5,tmp2)
            scout = nint(tmp1)
            scfile= nint(tmp2)
          endif

          !instant rotate "tmplump" radian w.r.s s-axis
          if(bitype.eq.-18) then
            call getparam_BeamLineElem(Blnelem(i),3,tmplump)
            call srot_BPM(Bpts%Pts1,Nplocal,tmplump)
          endif
          !shift longitudinal phase space
          if(bitype.eq.-19) then
            call shiftlong_BPM(Bpts%Pts1,bitype,Nplocal,Np,Bpts%refptcl(5),&
                               Bpts%refptcl(6))
          endif
          !instant heating from IBS
          if(bitype.eq.-20) then
            call getparam_BeamLineElem(Blnelem(i),3,b0)
            call getparam_BeamLineElem(Blnelem(i),4,tmp1)
            qmass = abs(Bpts%Charge)/Bpts%Mass
            call engheater_BPM(Bpts%Pts1,Nplocal,b0,qmass)
          endif

!-------------------------------------------------------------------
! read in the on axis E field for rf cavities.
!          if(myid.eq.0) print*,"bitype: ",bitype
          if(bitype.gt.100) then
            call getparam_BeamLineElem(Blnelem(i),5,rfile)
            nfile = int(rfile + 0.1)
            ifile = nfile
!            if(myid.eq.0) print*,"ifile: ",nfile
            if(ifile.ne.tmpfile)then
              !for linear map integrator
              if(Flagmap.eq.1) then
                !read in Ez, Ez', Ez'' on the axis
                !for SolRF and TWS, use Fourier coefficients
                !otherwise, use discrete data on axis.
                if(bitype.eq.105 .or. bitype.eq.106) then
                  call read3_Data(ifile)
                else
                  call read1_Data(ifile)
                endif
              else
                !read in Er, Ez, H_theta on r-z grid 
                !call read2_Data(ifile)
                !read in Fourier coefficients of Ez on the axis
                !call read3_Data(ifile)
                if(bitype.eq.110) then
                  call read4_Data(ifile)
                  !call read3_Data(ifile)
                else
                  call read3_Data(ifile)
                endif
              endif
              tmpfile=ifile
            endif
          endif
!-------------------------------------------------------------------
! read in the on axis G field for quadrupoles.
          if(bitype.eq.1) then
            call getparam_BeamLineElem(Blnelem(i),3,rfile)
            if(rfile.gt.1.0e-5) then
               nfile = int(rfile+0.1)
               ifile = nfile
               if(ifile.ne.tmpfile) then
                  call read1_Data(ifile)
                  tmpfile = ifile
               endif
            endif
          endif

          if(bitype.eq.105 .or. bitype.eq.106) then
            call getparam_BeamLineElem(Blnelem(i),13,aawk)
            call getparam_BeamLineElem(Blnelem(i),14,ggwk)
            call getparam_BeamLineElem(Blnelem(i),15,lengwk)
            if(lengwk.gt.0.0) then
              flagwake = 1
            else
              flagwake = 0
            endif
          else
            !biaobin,2022-03-07, flagwakeread for ANALYTICAL WAKE or READ-IN WAKE
            !                    flagwake control OFF or ON
            !if(flagwakeread.eq.0) flagwake = 0
          endif

!-------------------------------------------------------------------
! print out beam information using BPM 
          if(bitype.eq.-1) then
            !call shift_BPM(Bpts%Pts1,bitype,Nplocal,Np)
            !bitype=-1, shift so <x>=<y>=0
            !bitype=-2, shift so 6D in controid
            call shift_BPM(Bpts%Pts1,-1,Nplocal,Np)
          endif
          
          !for multi-turns tracking, output phase space every ofreq turns
          if(bitype.eq.-2) then
            !biaobin, watch, fort.1000
            !(watch,RCS), for 11 turns tracking, outfq=5:
            !fort.1000, fort.1005, fort.1010
            !refers to: initial, after 5th turn, after 10th turn output.
            if (mod(ith_turn-1,outfq)==0 .or. ith_turn.eq.1) then
                bmpstp = bmpstp+ith_turn-1
                call getparam_BeamLineElem(Blnelem(i),drange)
                phaseopt = drange(2)
                integerSamplePeriod = abs(drange(3))
                !phaseopt=0/1/2/3 => impactz,impactt,normal,astra type phase space
                call phase_Output(bmpstp,Bpts,phaseopt,integerSamplePeriod)
            end if

          else if(bitype.eq.-3) then
            call getparam_BeamLineElem(Blnelem(i),drange)
            call accdens1d_Output(nstep,8,Bpts,Np,drange(2),-drange(3),&
            drange(3),-drange(5),drange(5))
          else if(bitype.eq.-4) then
            call getparam_BeamLineElem(Blnelem(i),drange)
            call dens1d_Output(nstep,8,Bpts,Np,drange(2),-drange(3),&
            drange(3),-drange(5),drange(5))
          else if(bitype.eq.-5) then
            call getparam_BeamLineElem(Blnelem(i),drange)
            call dens2d_Output(nstep,8,Bpts,Np,-drange(3),drange(3),&
            -drange(4),drange(4),-drange(5),drange(5),-drange(6),drange(6),&
            -drange(7),drange(7),-drange(8),drange(8))
          else if(bitype.eq.-6) then
            call dens3d_Output(nstep,8,Bpts,Np,-drange(3),drange(3),&
              -drange(5),drange(5),-drange(7),drange(7))
          else if(bitype.eq.-7) then
            !output all particles in 6d phase space in files fort.bmpstp+myid
            !output all geomtry information in file fort.bmpstp+myid.
            call outpoint_Output(myid+bmpstp,Bpts,z,i,j,ibal,nstep,npx,npy,Ageom)
            
          else if(bitype.eq.-8) then
            !every ofreq turns output 
            if (mod(ith_turn,outfq).eq.0 .or. ith_turn.eq.1) then
                call getparam_BeamLineElem(Blnelem(i),drange)
                qchg = Bpts%Current/Scfreq
                pmass = Bpts%Mass
                nfile =bmpstp
                nslice = drange(2)+0.1
                alphax0 = drange(3)
                betax0 = drange(4)
                if(betax0.eq.0.0d0) betax0 = 1.0d0
                alphay0 = drange(5)
                betay0 = drange(6)
                if(betax0.eq.0.0d0) betay0 = 1.0d0
                gamma0 = -Bpts%refptcl(6)

                nfile = nfile+ith_turn
                !for 1st turn, back to initial nfile ID
                if (ith_turn.eq.1) then
                    nfile = nfile-1 
                end if

                call sliceprocdep_Output(Bpts%Pts1,Nplocal,Np,nslice,qchg,pmass,&
                 nfile,alphax0,betax0,alphay0,betay0,gamma0)
            end if
          else if(bitype.eq.-10) then
            !mismatch the beam at given location.
            !here, drange(3:8) stores the mismatch factor.
            call getparam_BeamLineElem(Blnelem(i),drange)
            call scale_BPM(Bpts%Pts1,Nplocal,drange(3),&
            drange(4),drange(5),drange(6),drange(7),drange(8))
          else if(bitype.eq.-11) then
            print*,"Not available in current version!"
            stop
          else if(bitype.eq.-13) then !collimator slit
            call getparam_BeamLineElem(Blnelem(i),drange)
            xradmin = drange(3)
            xradmax = drange(4)
            yradmin = drange(5)
            yradmax = drange(6)
            call lostcountXY_BeamBunch(Bpts,Nplocal,Np,xradmin,&
                  xradmax,yradmin,yradmax)
            call chgupdate_BeamBunch(Bpts,nchrg,nptlist0,qmcclist0)
          else if(bitype.eq.-21)then
            !shift the beam centroid in the 6D phase space.
            !This element can be used to model steering magnets etc.
            !here, drange(3:8) stores the amount of shift.
            !drange(3); shift in x (m)
            !drange(4); shift in Px (rad)
            !drange(5); shift in y (m)
            !drange(6); shift in Py (rad)
            !drange(7); shift in z (deg)
            !drange(8); shift in Pz (MeV)
            call getparam_BeamLineElem(Blnelem(i),drange)
            call kick_BPM(Bpts%Pts1,Nplocal,drange(3),drange(4),drange(5),&
            drange(6),drange(7),drange(8),-Bpts%refptcl(6),Bpts%Mass)
!            Bpts%refptcl(6) = Bpts%refptcl(6) - drange(8)*1.d6/Bpts%Mass

          !EMATRIX element, temporary only support: m11, m33, m56, m65
          else if(bitype.eq.-22)then
            call getparam_BeamLineElem(Blnelem(i),drange)
            !length steps maps type radius m11 m33 m56 m65
            !drange(1): 0 
            !drange(2): radius, not used
            !drange(3): m11
            !drange(4): m33
            !drange(5): m55
            !drange(6): m56, since we use z>0 head convention, m56>0 for chicane.
            !drange(7): m65
            !drange(8): m66
            !drange(9): T566
            !drange(10):T655
            !drange(11):U5666
            !drange(12):U6555
            call kick_matrix(Bpts%Pts1,Nplocal,drange(3),drange(4),&
            drange(5),drange(6),drange(7),drange(8),drange(9),&
            drange(10),drange(11),drange(12),-Bpts%refptcl(6),Bpts%Mass)

          else if(bitype.eq.-40)then
            call getparam_BeamLineElem(Blnelem(i),drange)
            call kickRF_BPM(Bpts%Pts1,Nplocal,drange(3),drange(4),drange(5),&
                            Bpts%Mass)

          !biaobin, RingRF thin cavity model.
          !AC model: read rfdata_ac.in for time changing (volt,phi0)
          else if(bitype.eq.-42)then
            call getparam_BeamLineElem(Blnelem(i),drange)

            !drange(6)=1, DC model
            !drange(6)=2, AC model
            if (int(drange(6)).eq.2) then
              !for AC model, get the time based on sync particle
              t_ref = Bpts%refptcl(5)*Scxl/Clight
              vhphi = math%get_vhphi(t_ref)
              !update volt, phi and harmonic number
              drange(3) = vhphi(1)   ![V]
              drange(4) = vhphi(2)   !harmonic number
              drange(5) = vhphi(3)   !degree, in cos func      
            endif

            call RingRF_BPM(Bpts,Nplocal,drange(3),drange(4),drange(5),&
                            Bpts%Mass,Lc)

          !biaobin, GAP model in low beam energy range, similar with
          ! TraceWin's GAP element
          else if(bitype.eq.-43)then
            call getparam_BeamLineElem(Blnelem(i),drange)
            !drange(2) is pipe radius, not used yet
            call GAP_BPM(Bpts,Nplocal,drange(3),drange(4),drange(5),&
                            Bpts%Mass)

          !read in discrete wakefield
          !biaobin,2022-03-07
          !rfile < 0, analytical wakefunction
          !rfile > 0, read in wake file
          else if(bitype.eq.-41)then
            call getparam_BeamLineElem(Blnelem(i),2,tmpwk)
            call getparam_BeamLineElem(Blnelem(i),3,rfile)
            if(rfile.gt.0.0d0) then
              flagwakeread=1
              ifile = int(rfile + 0.1)
              call getparam_BeamLineElem(Blnelem(i),10,factor)
              call read1wk_Data(ifile,factor)
            elseif(rfile .lt. 0.0d0) then
              flagwakeread=0
              call getparam_BeamLineElem(Blnelem(i),5,aawk)
              call getparam_BeamLineElem(Blnelem(i),6,ggwk)
              call getparam_BeamLineElem(Blnelem(i),7,lengwk)
              !rfile=-1, SLAC32PI
              !rfile=-2, TESLA13G
              !rfile=-3, TESLA39G
              if(nint(rfile).eq.-1) then
                flagwaketype=-1
              elseif(nint(rfile).eq.-2) then
                flagwaketype=-2
              elseif(nint(rfile).eq.-3) then
                flagwaketype=-3
              else
                print*,"ERROR: not available RFwake type is given:", &
                       nint(rfile)
                stop
              endif
            else 
              print*,"ERROR: rfile should be lt or gt 0: rfile=",rfile
              stop
            endif
            call getparam_BeamLineElem(Blnelem(i),4,tmp1)
            !print*,"-41flagbc: ",tmpwk,rfile,tmp1
            !biaobin, wakefiled option:
              !ID < 0,     wake OFF
              !ID = (0,10),  Lwake
              !ID = (10,20), Twake
              !ID > 20,      Lwake+Twake
            if(tmp1.gt.0.0d0) then !turn on the wakefield.
              flagwake = 1
              if(tmp1<10.0 .and. tmp1>0.0) then !no transverse wakefield
                flagbtw = 2
              else if(tmp1>10.0 .and. tmp1<20.0) then !no longitudinal wakefiled
                flagbtw = 4
              endif
              scwk = tmpwk
            else !turn off
              flagwake = 0
              scwk = 1.0d0
            endif
            !biaobin, get the rfwake output file id
            call getparam_BeamLineElem(Blnelem(i),8,tmp3)
            call getparam_BeamLineElem(Blnelem(i),9,tmp4)
            wakeconvout = nint(tmp3)
            wakeconvfile = nint(tmp4)

          !laser heater from simplified sinusoidal model
          else if(bitype.eq.-52)then
            xylc = 0.0d0
            do ii = 1, Nplocal
              xylc(1) = xylc(1) + Bpts%Pts1(1,ii)
              xylc(2) = xylc(2) + Bpts%Pts1(1,ii)*Bpts%Pts1(1,ii)
              !xylc(3) = xylc(3) + Bpts%Pts1(3,ii)
              !xylc(4) = xylc(4) + Bpts%Pts1(3,ii)*Bpts%Pts1(3,ii)
            enddo
            call MPI_ALLREDUCE(xylc,xygl,2,MPI_DOUBLE_PRECISION,&
                        MPI_SUM,MPI_COMM_WORLD,ierr)
            xygl = xygl/Bpts%Npt
            sigx2 = (xygl(2) - xygl(1)*xygl(1))*Scxl*Scxl

            call getparam_BeamLineElem(Blnelem(i),drange)
            rsiglaser = drange(2)
            rlaserwvleng = drange(3)
            tmp1 = sqrt(2*(sigx2+rsiglaser**2)/rsiglaser**2)
            freqlaser = Clight/rlaserwvleng
            harm = freqlaser/Scfreq
            tmp2 = 4*rsiglaser*rsiglaser/Scxl/Scxl
            ezlaser = drange(4)/Bpts%Mass
            do ii = 1, Nplocal
              rr =(Bpts%Pts1(1,ii)**2+Bpts%Pts1(3,ii)**2)/tmp2
              Bpts%Pts1(6,ii) = Bpts%Pts1(6,ii) - &
                tmp1*ezlaser*sin(-harm*Bpts%Pts1(5,ii))*exp(-rr)
            enddo
          else if(bitype.eq.-55)then !thin lens multipole
            call getparam_BeamLineElem(Blnelem(i),drange)
            !k0 = drange(3) !dipole
            !k1 = drange(4) !quad
            !k2 = drange(5) !sext
            !k3 = drange(6) !oct
            !k4 = drange(7) !dec.
            !k5 = drange(8) !dodec.
            qmass = Bpts%Charge/Bpts%Mass
            gamma0 = -Bpts%refptcl(6)
            call thinMultipole_BPM(Bpts%Pts1,Nplocal,drange(3),drange(4),&
                 drange(5),drange(6),drange(7),drange(8),gamma0,qmass)
          endif
          if(bitype.eq.-99) then
            exit
          endif

          zedge = z
          call setparam_BeamLineElem(Blnelem(i),1,zedge)
          if(myid.eq.0 .and. turn.eq.1) print*,"zedge: ",zedge
          if(Flagerr.eq.1) then
              call geomerrL_BeamBunch(Bpts,Blnelem(i)) 
          end if
          !/bend using Transport transfer map
          if(bitype.eq.4 .or. bitype.eq.5) then
              call getparam_BeamLineElem(Blnelem(i),dparam)
              !transfter to the Transport coordinate (except the 5th coordinate 
              !is -v dt instead of v dt) and apply front edge transfer map
              dpi = 2*asin(1.0d0)
              gamma0 = -Bpts%refptcl(6)
              beta0 = sqrt(1.0d0-1.0d0/gamma0/gamma0)
              Bpts%refptcl(5) = Bpts%refptcl(5)+blength/(Scxl*beta0)
              gambet = beta0*gamma0
              hgap = 2*dparam(5)
              piperad2 = dparam(5)
              !ang0 = dparam(2)*dpi/180.0
              ang0 = dparam(2)
              hd1 = dparam(3) !k1
              !angF = dparam(6)*dpi/180.0 !e1
              angF = dparam(6) !e1
              !angB = dparam(7)*dpi/180.0 !e2
              angB = dparam(7) !e2
              hF = dparam(8) !1/r1
              hB = dparam(9) !/1/r2
              dstr1 = dparam(10) !fringe field K of entrance
              dstr2 = dstr1 !fringe field K of exit. here, assume Kb = Kf

              hd0 = ang0/blength !k0
              tanphiF = tan(angF)
              psi1 = hd0*hgap*dstr1*(1.0+sin(angF)*sin(angF))/cos(angF)
              tanphiFb = tan(angF-psi1)
              tanphiB = tan(angB)
              psi2 = hd0*hgap*dstr2*(1.0+sin(angB)*sin(angB))/cos(angB)
              tanphiBb = tan(angB-psi2)
              qm0 = Bpts%Charge/Bpts%Mass
              r0  = abs(1.0d0/hd0)

              !print*,"bend: ",hd0,tanphiF,psi1,tanphiFb,tanphiB,psi2,tanphiBb

              !Biaobin, 201907, options to choose linear or nonlinear map for dipole
              ! ID=(0,50),    linearMap+OFF-CSR
              ! ID=(50,100),  linearMap+ON-CSR
              ! ID=(100,200), nonlinearMap+OFF-CSR
              ! ID > 200,     nonlinearMap+ON-CSR
              if (bitype.eq.4) then  !for bitype=5, skip the map
                if(dparam(4).gt.0.0d0 .and. dparam(4).lt.100.0d0 ) then
                  call Fpol_Dipole_linearmap(hd0,hF,tanphiF,tanphiFb,hd1,&
                                   psi1,Bpts%Pts1,angF,Nplocal,gamma0,qm0)
                elseif(dparam(4).gt.100.0d0) then
                  call Fpol_Dipole_nonlinearmap(hd0,hF,tanphiF,tanphiFb,hd1,&
                                   psi1,Bpts%Pts1,angF,Nplocal,gamma0,qm0)
                else
                  ! in case ID is given <0
                  print*,"wrong ID flag given for dipole element!"
                  stop
                endif 
              endif
              angz = 0.0
          endif
!-------------------------------------------------------------------
! loop through 'bnseg' numerical segments in each beam element
! using 2 step symplectic integeration (ie. leap frog).
          ihlf = 0
          do j = 1, bnseg
!-------------------------------------------------------------------
! use linear map or nonlinear Lorentz integrator to advance particles.
            if(bitype.ne.4 .and. bitype.ne.5) then
              ! spatial drift.
              !linear map integrator
              if(Flagmap.eq.1) then
                !biaobin, 2021-04-02
                !for ideal drift, quad, rf-cavity maps, comes here
                call map1_BeamBunch(Bpts,Blnelem(i),z,tau1,bitype,&
                                    bnseg,j,ihlf,Lc,simutype)
              else
                call map1_BeamBunch(Bpts,z,tau2)
              endif
            else
              if(bitype.eq.4) then
                if(dparam(4).gt.0.0d0 .and. dparam(4).lt.100.0d0 ) then
                  call Sector_Dipole_linearmap(tau1,beta0,hd0,hd1,Bpts%Pts1,&
                                     Nplocal,qm0)
                elseif(dparam(4).gt.100.0d0) then
                  call Sector_Dipole_nonlinearmap(tau1,beta0,hd0,hd1,Bpts%Pts1,&
                                     Nplocal,qm0)
                else
                  !in case ID<0
                  print*,"wrong ID flag given for dipole element!"
                  stop
                endif
              endif
              !for bitype=5, only CSR kick.
              z = z + tau1
              angz = angz + tau1*hd0

            endif

!-------------------------------------------------------------------
            !escape the space charge calculation for 0 current case
            !if(Bcurr.lt.1.0e-10)  then !no space-charge

            !Biaobin Li, 2021-03-04
            !use Flagsc to control space charge behavior:
            !Flagsc=0 or current=0, SC OFF
            !Flagsc=1, LSC
            !Flagsc=2, TSC
            !Flagsc=3, LSC + TSC
            !Flagsc=4, SC OFF, wake or csr ON
            if (Bcurr.lt.1.0e-10 .or. Flagsc.eq.0)  then !no space-charge
               !biaobin, this func plays the same role as RingPhaseFold
               !1. aperture is considered
               !2. phase fold based on Ring Length

               call lostcount_BeamBunch(Bpts,Nplocal,Np,piperad, &
                      piperad2,Lc,simutype)
!              call chgupdate_BeamBunch(Bpts,nchrg,nptlist0,qmcclist0)

            else !calculate space charge forces
              call conv1st_BeamBunch(Bpts,tau2,Nplocal,Np,ptrange,&
                                   Flagbc,Perdlen,piperad,piperad2,&
                                   Lc,simutype)
              call chgupdate_BeamBunch(Bpts,nchrg,nptlist0,qmcclist0)
              flagcsr = 0
              if(bitype.eq.4 .or. bitype.eq.5) then
                !if(dparam(4).gt.200) then
                !  flagcsr = 1
                !endif
                !Biaobin, using ID to control CSR behavior
                !ID (50,100), Linear map + CSR
                !ID >200, nonlinear map + CSR
                if((dparam(4).gt.50.and.dparam(4).lt.100).or.(dparam(4).gt.200)) then
                    flagcsr = 1
                    !print*,"CSR for Dipole is ON."
                !endif
                else
                    flagcsr = 0
                    !print*,"CSR for Dipole is OFF."
                endif
              endif

              !fix the global range for sub-cycle of space charge potential.
              if(Flagsubstep.eq.1) then
                if((Flagbc.eq.3).or.(Flagbc.eq.4)) then
                else
                  ptrange(1) = -piperad
                  ptrange(2) = piperad
                  ptrange(3) = -piperad2
                  ptrange(4) = piperad2
                endif
                ptrange(5) = -Perdlen/2
                ptrange(6) = Perdlen/2
              endif

            ! get new boundary from the range of beam particles.
            if(Flagbc.eq.4) then
            else
              call update_CompDom(Ageom,ptrange,grid2d,Flagbc)
            endif
            call getlcmnum_CompDom(Ageom,lcgrid)
            Nxlocal = lcgrid(1) 
            if(npy.gt.1) then
              Nylocal = lcgrid(2) + 2
            else
              Nylocal = lcgrid(2) 
            endif
            if(npx.gt.1) then
              Nzlocal = lcgrid(3) + 2
            else
              Nzlocal = lcgrid(3)
            endif
            call getlcrange_CompDom(Ageom,lcrange)
            call getrange_CompDom(Ageom,range)

            if(totnp.gt.1) then
              ! pass particles to local space domain on new processor.
              if((Flagbc.eq.3).or.(Flagbc.eq.4)) then
              else
                call ptsmv2_Ptclmger(Bpts%Pts1,Nplocal,grid2d,Pdim,&
                                Nplcmax,lcrange)
              endif
            endif
            ! assign new 'Nplocal' local particles on each processor.
            call setnpt_BeamBunch(Bpts,Nplocal)
!-------------------------------------------------------------------
            if((mod(j-1,nsubstep).eq.0).or.(Flagsubstep.ne.1)) then

              call set_FieldQuant(Potential,Nx,Ny,Nz,Ageom,grid2d,npx,&
                                npy)
              deallocate(chgdens)
              allocate(chgdens(Nxlocal,Nylocal,Nzlocal))
             ! deposit particles onto grid to obtain charge density.
              call charge_BeamBunch(Bpts,Nplocal,Nxlocal,Nylocal,Nzlocal,Ageom,&
                                  grid2d,chgdens,Flagbc,Perdlen)

!-------------------------------------------------------------------
! start load balance. (at the location of new space charge calculation)
            if((mod(ibal,nbal).eq.0).and.(totnp.gt.1) ) then
              call MPI_BARRIER(comm2d,ierr)
              if(myid.eq.0 .and. turn.eq.1) then
                print*," load balance! "
              endif

              call getlctabnm_CompDom(Ageom,temptab)
              lctabnmx(0:npx-1) = temptab(1,0:npx-1,0)
              lctabnmy(0:npy-1) = temptab(2,0,0:npy-1)
              call getmsize_CompDom(Ageom,msize)
              hy = msize(2)
              hz = msize(3)
              call getrange_CompDom(Ageom,range)
              ymin = range(3)
              zmin = range(5)
              call balance_CompDom(chgdens,lctabnmx,&
                lctabnmy,lctabrgx,lctabrgy,npx,npy,commrow,commcol, &
                lcgrid(1),lcgrid(2),lcgrid(3),Ny,Nz,hy,hz,ymin,zmin)
              call setlctab_CompDom(Ageom,lctabnmx,lctabnmy,lctabrgx,&
                                     lctabrgy,npx,npy,myidx,myidy)
              call getlcmnum_CompDom(Ageom,lcgrid)
              Nxlocal = lcgrid(1)
              if(npy.gt.1) then
                Nylocal = lcgrid(2) + 2
              else
                Nylocal = lcgrid(2)
              endif
              if(npx.gt.1) then
                Nzlocal = lcgrid(3) + 2
              else
                Nzlocal = lcgrid(3)
              endif
              call getlcrange_CompDom(Ageom,lcrange)
              deallocate(chgdens)
              allocate(chgdens(Nxlocal,Nylocal,Nzlocal))
              call set_FieldQuant(Potential,Nx,Ny,Nz,Ageom,grid2d,npx,npy)

              ! pass particles to local space domain on new processor.
              call ptsmv2_Ptclmger(Bpts%Pts1,Nplocal,grid2d,Pdim,&
                                 Nplcmax,lcrange)
              ! assign new 'Nplocal' local particles on each processor.
              call setnpt_BeamBunch(Bpts,Nplocal)

              ! deposit particles onto grid to obtain charge density.
              call charge_BeamBunch(Bpts,Nplocal,Nxlocal,Nylocal,Nzlocal,&
                                    Ageom,grid2d,chgdens,Flagbc,Perdlen)
            endif
            ibal = ibal + 1
!end load balance.
!-------------------------------------------------------------------

              if(npx.gt.1) then
                nzlcr = Nzlocal-2
                kadd = 1
              else
                nzlcr = Nzlocal
                kadd = 0
              endif
              if(npy.gt.1) then
                nylcr = Nylocal-2
              else
                nylcr = Nylocal
              endif
!-------------------------------------------------------------------------
! solve 3D Poisson's equation
              if(Flagsc.eq.4) then
                  !biaobin, 2021-09-02, for SC OFF, but cavity-wake ON case 
                  !print*,"space charge is OFF, however, &
                  !        wake and csr could be ON."
                  Potential%FieldQ=0.0d0
              else
                if(Flagbc.eq.1) then
                  ! solve Poisson's equation using 3D isolated boundary condition.
                  call update3O_FieldQuant(Potential,chgdens,Ageom,&
                  grid2d,Nxlocal,Nylocal,Nzlocal,npx,npy,nylcr,nzlcr)
                else
                  print*,"no such boundary condition type!!!"
                  stop
                endif
              endif
            endif

              !includes wakefield
              if(flagwake.eq.1) then
                !hzwake = (range(6)-range(5))*1.0000001/(Nz-1) !avoid over index
                !no need to avoid over index since range already has 2 extra grids.
                hzwake = (range(6)-range(5))/(Nz-1) 
                xwakelc = 0.0
                ywakelc = 0.0
                denszlc = 0.0
                xwakez = 0.0
                ywakez = 0.0
                densz = 0.0
                !linear interpolation
                do ipt = 1, Nplocal
                  iizz = (Bpts%Pts1(5,ipt)-range(5))/hzwake + 1
                  iizz1 = iizz + 1
                  ab = ((range(5)-Bpts%Pts1(5,ipt))+iizz*hzwake)/hzwake
                  xwakelc(iizz) = xwakelc(iizz) + Bpts%Pts1(1,ipt)*ab
                  xwakelc(iizz1) = xwakelc(iizz1) + Bpts%Pts1(1,ipt)*(1.0-ab)
                  ywakelc(iizz) = ywakelc(iizz) + Bpts%Pts1(3,ipt)*ab
                  ywakelc(iizz1) = ywakelc(iizz1) + Bpts%Pts1(3,ipt)*(1.0-ab)
                  denszlc(iizz) = denszlc(iizz) + ab
                  denszlc(iizz1) = denszlc(iizz1) + 1.0 -ab
                enddo
                call MPI_ALLREDUCE(denszlc,densz,Nz,MPI_DOUBLE_PRECISION,&
                                   MPI_SUM,comm2d,ierr)
                call MPI_ALLREDUCE(xwakelc,xwakez,Nz,MPI_DOUBLE_PRECISION,&
                                   MPI_SUM,comm2d,ierr)
                call MPI_ALLREDUCE(ywakelc,ywakez,Nz,MPI_DOUBLE_PRECISION,&
                                   MPI_SUM,comm2d,ierr)

                !hzwake divided by gamma is due to fact that the particle z coordinate is in the beam
                !frame instead of the lab frame (during the T -> Z conversion).
                hzwake = hzwake/(-Bpts%refptcl(6))
                !get the line charge density along z
                do kz = 1, Nz
                  recvdensz(kz,1) = densz(kz)*Bpts%Current/Scfreq/Np/(hzwake)*&
                                    Bpts%Charge/abs(Bpts%Charge)
                enddo

                !due to the edge deposition
                !recvdensz(1,1) = recvdensz(1,1)*2
                !recvdensz(Nz,1) = recvdensz(Nz,1)*2
                do kz = 1, Nz
                  if(densz(kz).ne.0.0) then
                    xwakez(kz) = xwakez(kz)/densz(kz)
                    ywakez(kz) = ywakez(kz)/densz(kz)
                  else
                    xwakez(kz) = 0.0
                    ywakez(kz) = 0.0
                  endif
                  !recvdensz(kz,2) = sqrt(xwakez(kz)**2+ywakez(kz)**2)
                  recvdensz(kz,2) = ywakez(kz)
                enddo

                !calculate the longitudinal and transverse wakefield from
                !the line charge density and analytical wake function
                !if(myid.eq.0) print*,"aawk: ",aawk,ggwk,lengwk
                if(flagwakeread.eq.1) then
                  call wakefieldread_FieldQuant(Nz,xwakez,ywakez,recvdensz,exwake,eywake,ezwake,&
                     hzwake,aawk,ggwk,lengwk,flagbtw)
                else
                  !biaobin,2022-03-07, analytical model instead
                  call wakefield_FieldQuant(Nz,xwakez,ywakez,recvdensz,exwake,eywake,ezwake,&
                     hzwake,aawk,ggwk,lengwk,flagbtw,flagwaketype)
                endif
                !print*,"exwake0,eywake0,ezwake0:",sum(exwake),sum(eywake),sum(ezwake)
                exwake = scwk*exwake
                eywake = scwk*eywake
                !exwake = 0.0*exwake
                !eywake = 0.0*eywake
                ezwake = scwk*ezwake
                
                !biaobin,2022-03,output RF wake 
                if(myid.eq.0) then
                  if(wakeconvfile<10) then
                    formatstr="(I1,A7)"
                  elseif(wakeconvfile<100) then
                    formatstr="(I2,A7)"
                  else
                    print*,"rfwake output file id should be [0,100), &
                    rfwakefile id=",wakeconvfile
                    stop
                  endif
                  !only output the rfwake at the first step
                  if(wakeconvout.eq.1 .and. j==1) then 
                    write(filename,formatstr) wakeconvfile,".rfwake"
                    open(2,file=filename)
                    do k=1,Nz
                        !times the charge sign, minus for energy loss
                        write(2,101) &
                        range(5)/(-Bpts%refptcl(6))+hzwake*(k-1), &
                        Bpts%Charge/abs(Bpts%Charge)*recvdensz(k,1), &
                        Bpts%Charge/abs(Bpts%Charge)*exwake(k), &
                        Bpts%Charge/abs(Bpts%Charge)*eywake(k), &
                        Bpts%Charge/abs(Bpts%Charge)*ezwake(k)
                    enddo
                    101 format(5(2x,e13.7))
                  endif
                endif

              endif

              if(flagcsr.eq.1) then
                gam = -Bpts%refptcl(6)
                hzwake = (range(6)-range(5))/(Nz-1)
                denszlc = 0.0
                densz = 0.0
                !linear interpolation
                !biaobin,2022-03,get the density profile along
                !z-direction; Nz=64 is grid point, bin number=63
                !hzwake=dz, bin width
                do ipt = 1, Nplocal
                  iizz = (Bpts%Pts1(5,ipt)-range(5))/hzwake + 1
                  iizz1 = iizz + 1
                  ab = ((range(5)-Bpts%Pts1(5,ipt))+iizz*hzwake)/hzwake
                  denszlc(iizz) = denszlc(iizz) + ab
                  denszlc(iizz1) = denszlc(iizz1) + 1.0 -ab
                enddo
                !print*,"sum denszlc: ",sum(denszlc)
                call MPI_ALLREDUCE(denszlc,densz,Nz,MPI_DOUBLE_PRECISION,&
                                   MPI_SUM,comm2d,ierr)
                !print*,"sum densz: ",sum(densz),hzwake,Nplocal,range(5),range(6),Nz
                !hzwake divided by gamma is due to fact that the particle z coordinate is in the beam
                !frame instead of the lab frame (during the T -> Z conversion).
                hzwake = hzwake/(-Bpts%refptcl(6))
                !get the line charge density along z
                do kz = 1, Nz
                  densz(kz) = densz(kz)*Bpts%Current/Scfreq/Np/(hzwake)*&
                                    Bpts%Charge/abs(Bpts%Charge)
                enddo
 
                !due to the edge deposition
                !densz(1) = densz(1)*2
                !densz(Nz) = densz(Nz)*2

                if(bitype.eq.4 .or. bitype.eq.5) then
                      zwkmin = range(5)/(-Bpts%refptcl(6)) + (z-zbleng)
                      bendlen = blength !inside the bend
                else
                  print*,"wrong csr element"
                endif

                exwake = 0.0
                eywake = 0.0
                ezwake = 0.0
!using IGF for the s-s csr wake
                denszp = 0.0d0
                denszpp = 0.0d0
                call csrwakeTrIGF_FieldQuant(Nz,r0,zwkmin,hzwake,&
                              bendlen,densz,denszp,denszpp,gam,ezwake)

              !print*,"after csr: ",sum(ezwake)
              !biaobin, 2022-03, output csrwake
              if(myid.eq.0) then
                csrout=nint(dparam(16))
                csrfile=nint(dparam(17))
                if(csrfile<10) then
                  if(j<10) then
                    formatstr="(I1,A1,I1,A4)"
                  else 
                    formatstr="(I1,A1,I2,A4)"
                  endif
                elseif(csrfile<100) then
                  if(j<10) then
                    formatstr="(I2,A1,I1,A4)"
                  else 
                    formatstr="(I2,A1,I2,A4)"
                  endif
                else
                  print*,"csr output file id should in [0,100), &
                  csrfileid=", csrfile
                  stop
                endif
 
                if(csrout.eq.1) then 
                  write(filename,formatstr) csrfile,"_",j,".csr"

                  open(2,file=filename)
                  do k=1,Nz
                    write(2,100) &
                    range(5)/(-Bpts%refptcl(6))+hzwake*(k-1), &
                    Bpts%Charge/abs(Bpts%Charge)*densz(k), &
                    Bpts%Charge/abs(Bpts%Charge)*ezwake(k)
                  enddo
                  close(2)
                  100 format(3(2x,e13.7))
                  !biaobin, output the phase space
                  !call phase_Output(500+j,Bpts,-1)
                endif
              endif
              
              endif

              call cvbkforth1st_BeamBunch(Bpts)
              if(totnp.gt.1) then
                if((Flagbc.eq.3).or.(Flagbc.eq.4)) then
                else
                  call ptsmv2_Ptclmger(Bpts%Pts1,Nplocal,grid2d,Pdim,&
                                   Nplcmax,lcrange)
                endif
              endif
              call setnpt_BeamBunch(Bpts,Nplocal)

            endif
200         continue
! end space charge field calcualtion.
!-------------------------------------------------------------------

!-------------------------------------------------------------------
! use linear map or nonlinear Lorentz integrator to advance particles.
            !print*,"before kick:"
            if(Flagmap.eq.1) then
            ! kick particles in velocity space.
              if((flagwake.eq.1) .or. (flagcsr.eq.1)) then
                !biaobin,2022-03,Potential%FieldQ: space charge potential
                !exwake,eywake,ezwake: wake from CSR or RF wake
                !Potential%FieldQ = 0.0d0 !test wakefield
                call kick1wake_BeamBunch(Bpts,tau2,Nxlocal,Nylocal,Nzlocal,&
                   Potential%FieldQ,Ageom,grid2d,Flagbc,Perdlen,exwake,eywake,&
                   ezwake,Nz,npx,npy,Flagsc)
              else
                !biaobin,2022-03,No RF wake and CSR, 
                !only space charge kick
                call map2_BeamBunch(Bpts,tau2,Nxlocal,Nylocal,Nzlocal,&
                   Potential%FieldQ,Ageom,grid2d,Flagbc,Perdlen,Flagsc,&
                   scout,scfile)
              endif
              !biaobin,2022-03,dipole element or others, the other half 
              !seg after collective-effect kick
              if(bitype.ne.4 .and. bitype.ne.5) then
                call map1_BeamBunch(Bpts,Blnelem(i),z,tau1,bitype,&
                                    bnseg,j,ihlf,Lc,simutype)
              else
                if(bitype.eq.4) then
                  !print*,"before sec2: ",z,angz
                  if(dparam(4).gt.0.0d0 .and. dparam(4).lt.100.0d0 ) then
                    call Sector_Dipole_linearmap(tau1,beta0,hd0,hd1,Bpts%Pts1,&
                                       Nplocal,qm0)
                  elseif(dparam(4).gt.100.0d0) then
                    call Sector_Dipole_nonlinearmap(tau1,beta0,hd0,hd1,Bpts%Pts1,&
                                       Nplocal,qm0)
                  else
                    !in case ID<0
                    print*,"wrong ID flag given for dipole element!"
                    stop
                  endif
                endif
                z = z + tau1
                angz = angz + tau1*hd0
                !print*,"after sec2: ",z,angz
              endif
            else
              if((flagwake.eq.1) .or. (flagcsr.eq.1)) then
                call kick2wake_BeamBunch(Bpts,Blnelem(i),z,tau2,Nxlocal,Nylocal,&
                           Nzlocal,Potential%FieldQ,Ageom,grid2d,Flagbc,Flagerr,&
                           exwake,eywake,ezwake,Nz,npx,npy)
              else
                call map2_BeamBunch(Bpts,Blnelem(i),z,tau2,Nxlocal,Nylocal,&
                           Nzlocal,Potential%FieldQ,Ageom,grid2d,Flagbc,Flagerr)
              endif
              if(bitype.ne.4 .and. bitype.ne.5) then
                call map1_BeamBunch(Bpts,z,tau2)
              else
                !biaobin,2022-03, for type=4/5
                if(bitype.eq.4) then
                  if(dparam(4).gt.0.0d0 .and. dparam(4).lt.100.0d0 ) then
                    call Sector_Dipole_linearmap(tau1,beta0,hd0,hd1,Bpts%Pts1,&
                                       Nplocal,qm0)
                  elseif(dparam(4).gt.100.0d0) then
                    call Sector_Dipole_nonlinearmap(tau1,beta0,hd0,hd1,Bpts%Pts1,&
                                       Nplocal,qm0)
                  else
                    !in case ID<0
                    print*,"wrong ID flag given for dipole element!"
                    stop
                  endif
                endif
                z = z + tau1
                angz = angz + tau1*hd0
              endif
            endif
            !print*,"pass sec2: ",z
            
            !1. for one turn tracking, calculation beam information after
            !every element; for multi-turn tracking, only at the end of
            !one turn
            !2. for error and elem. rotation case, no output inside the
            !element, since we rotated the beam
            if(turn.eq.1 .and. Flagerr.eq.0) then
              if(Flagdiag.eq.1) then
                  call diagnostic1_Output(z,Bpts,nchrg,nptlist0, &
                                          turn,ith_turn)
              else
                  call diagnostic2_Output(Bpts,z,nchrg,nptlist0)
              endif
            endif

            nstep = nstep + 1
            if(myid.eq.0 .and. turn.eq.1) then 
              print*,"j, nstep, z",j,nstep,z
            endif
          end do
!end loop bnseg
!---------------------------------------------------------------------
          if(bitype.eq.4) then
              if(dparam(4).gt.0.0d0 .and. dparam(4).lt.100.0d0 ) then
                call Bpol_Dipole_linearmap(hd0,hB,tanphiB,tanphiBb,hd1,&
                               psi2,Bpts%Pts1,angB,Nplocal,gamma0,qm0)
              elseif(dparam(4).gt.100.0d0) then
                call Bpol_Dipole_nonlinearmap(hd0,hB,tanphiB,tanphiBb,hd1,&
                               psi2,Bpts%Pts1,angB,Nplocal,gamma0,qm0)
              else 
                ! in case ID is given <0
                print*,"wrong ID flag given for dipole element!"
                stop        
              endif
          endif

          !for error and rotate case, only output beam info 
          !at the exit of the elem.
          if(Flagerr.eq.1) then
            call geomerrT_BeamBunch(Bpts,Blnelem(i)) 
            if(Flagdiag.eq.1) then
                call diagnostic1_Output(z,Bpts,nchrg,nptlist0, &
                                       turn,ith_turn )
            else
                call diagnostic2_Output(Bpts,z,nchrg,nptlist0)
            endif
          end if

          zbleng = zbleng + blength
        enddo  !end loop through nbeam line element

        !do calculations for beam-sig values at the end of every turn
        if(turn.gt.1) then
          if(Flagdiag.eq.1) then
              call diagnostic1_Output(z,Bpts,nchrg,nptlist0, &
                                     turn,ith_turn )
          else
              call diagnostic2_Output(Bpts,z,nchrg,nptlist0)
          endif
        endif

        enddo  !end loop for multi-turns tracking
!------------------------------------------------

! final output.
        call MPI_BARRIER(comm2d,ierr)
        !output six 2-D phase projections.
        !call phase2dold_Output(30,Bpts,Np)
        !output all particles in 6d phase space.
        !call phase_Output(30,Bpts)
!        call phaserd2_Output(20,Bpts,Np,0.0,0.0,0.0,0.0,0.0)
        t_integ = t_integ + elapsedtime_Timer(t0)
        call showtime_Timer()

        deallocate(lctabnmx,lctabnmy)
        deallocate(lctabrgx,lctabrgy)
        deallocate(temptab)
        deallocate(chgdens)
        deallocate(tmpptcs)
        !deallocate(ztable)
        !deallocate(zdisp)
        deallocate(denszlc)
        deallocate(densz)
        deallocate(xwakelc)
        deallocate(xwakez)
        deallocate(ywakelc)
        deallocate(ywakez)
        deallocate(recvdensz)
        deallocate(sendensz)
        deallocate(exwake)
        deallocate(eywake)
        deallocate(ezwake)


        end subroutine run_AccSimulator

        subroutine destruct_AccSimulator(time)
        implicit none
        include 'mpif.h'
        double precision :: time
 
        call destruct_Data()
        call destruct_BeamBunch(Bpts)
        call destruct_FieldQuant(Potential)
        call destruct_CompDom(Ageom)

        deallocate(nptlist0)
        deallocate(currlist0)
        deallocate(qmcclist0)
 
        call end_Output(time)

        end subroutine destruct_AccSimulator

        !biaobin, RingRF func        
        !--------------------
        subroutine RingRF_BPM(this,innp,vmax,harm,phi0,mass,Lc)
        implicit none
        include 'mpif.h'
        type(BeamBunch),intent(inout) :: this

        integer, intent(in) :: innp
        !double precision, pointer, dimension(:,:) :: Pts1
        double precision, intent(in) :: vmax,phi0,mass,harm,Lc
        integer :: i
        real*8 :: vtmp,phi0lc,phi
        real*8 :: gam0,bet0,pilc
        real*8 :: gam1,bet1

        !print*,"debug, phi0=",phi0,"vmax=",vmax,"harm=",harm,"Lc=",Lc
        vtmp = vmax/mass
        phi0lc = phi0*asin(1.0)/90
        gam0 = -this%refptcl(6)
        bet0 = sqrt(1.0d0-1.0d0/gam0**2)
        pilc = 2.0d0*asin(1.0) 

        !update the ref particle energy
        this%refptcl(6) = this%refptcl(6) - vtmp*cos(phi0lc)
        gam1 = -this%refptcl(6)
        bet1 = sqrt(1.0d0-1.0d0/gam1**2)

        !update particle i energy
        do i = 1,innp
          !phi = phi0lc + harm*this%Pts1(5,i)  !if refers to freq_scale

          !harm refers to evo-frequency in ring:
          phi = phi0lc + 2*pilc*harm*bet0/Lc*this%Pts1(5,i)*Scxl
          this%Pts1(6,i) = this%Pts1(6,i)+vtmp*(cos(phi0lc)-cos(phi))

          !update X5, since X5 actually refers to ti
          this%Pts1(5,i) = this%Pts1(5,i)*bet0/bet1
        enddo 
        end subroutine RingRF_BPM

        subroutine GAP_BPM(this,innp,vmax,freq,phi0,mass)
        implicit none
        include 'mpif.h'
        type(BeamBunch),intent(inout) :: this

        integer, intent(in) :: innp
        !double precision, pointer, dimension(:,:) :: Pts1
        double precision, intent(in) :: vmax,freq,phi0,mass
        integer :: i
        real*8 :: vtmp,phi0lc,phi,harm
        real*8 :: gam0,bet0,pilc
        real*8 :: gam1,bet1
        real*8 :: betbar,gambar,lamda,kxy,kz
        real*8 :: gami,gambeti,gambet0,gambet1,X6,z

        vtmp = vmax/mass
        phi0lc = phi0*asin(1.0)/90
        gam0 = -this%refptcl(6)
        bet0 = sqrt(1.0d0-1.0d0/gam0**2)
        pilc = 2.0d0*asin(1.0) 
        harm = freq/Scfreq

        !print*,"debug, vmax=",vmax,"freq=",freq,"phi0=",phi0,"harm=",harm

        !update the ref particle energy
        this%refptcl(6) = this%refptcl(6) - vtmp*cos(phi0lc)
        gam1 = -this%refptcl(6)
        bet1 = sqrt(1.0d0-1.0d0/gam1**2)

        !for thin gap in low energy checking with TraceWin
        betbar = (bet0+bet1)/2.0d0
        gambar = (gam0+gam1)/2.0d0
        lamda = 2.0d0*pilc*Scxl/harm
        kxy = -pilc*vtmp*sin(phi0lc)/(betbar**2*gambar**2*lamda) 
        kz = 2.0d0*pilc*vtmp*sin(phi0lc)/(betbar**2*lamda)

        !update particle i 
        do i = 1,innp
          phi = phi0lc + harm*this%Pts1(5,i)
          !==============
          !OPTION ONE:
          !--------------
          !use linear map, dgambet~dgam/bet
          !this%Pts1(2,i) = kxy*this%Pts1(1,i)*Scxl+this%Pts1(2,i)
          !this%Pts1(4,i) = kxy*this%Pts1(3,i)*Scxl+this%Pts1(4,i)
          !this%Pts1(6,i) = this%Pts1(6,i)*bet1/bet0 +Scxl*kz*bet0*bet1*this%Pts1(5,i)

          !OPTION TWO:
          !--------------
          !use nonlinear map
          this%Pts1(2,i) = kxy*this%Pts1(1,i)*Scxl+this%Pts1(2,i)
          this%Pts1(4,i) = kxy*this%Pts1(3,i)*Scxl+this%Pts1(4,i)
          this%Pts1(6,i) = this%Pts1(6,i)+vtmp*(cos(phi0lc)-cos(phi))

          !!OPTION THREE:
          !--------------
          !!map based on dgambet => dgam, I think this is not right 
          !this%Pts1(2,i) = kxy*this%Pts1(1,i)*Scxl+this%Pts1(2,i)
          !this%Pts1(4,i) = kxy*this%Pts1(3,i)*Scxl+this%Pts1(4,i)
          !
          !gami = -this%Pts1(6,i)+gam0 
          !gambeti = sqrt(gami**2-1.0d0)
          !gambet0 = gam0*bet0
          !gambet1 = gam1*bet1

          !X6 = gambeti-gambet0
          !z  = -Scxl*bet0*this%Pts1(5,i)
          !X6 = kz*z+X6
          !gambeti = X6+gambet1 
          !gami = sqrt(gambeti**2+1.0d0)
          !this%Pts1(6,i) = gam1-gami
          !==============

          !update X5, since X5 actually refers to ti
          this%Pts1(5,i) = this%Pts1(5,i)*bet0/bet1
        enddo 
        end subroutine GAP_BPM

      end module AccSimulatorclass
