!----------------------------------------------------------------
! (c) Copyright, 2016 by the Regents of the University of California.
! BeamBunchclass: Charged beam bunch class in Beam module of APPLICATION 
!                 layer.
! Version: 2.0
! Author: Ji Qiang, LBNL
! Description: This class defines the charged particle beam bunch 
!              information in the accelerator.
! Comments: 1) I have added the 3 attributes to the particle array:
!           x,px,y,py,t,pt,charge/mass,charge weight,id. We have moved
!           the charge*curr/freq/Ntot into the charge density calculation,
!           which is represented by the "charge weight" of a particle.
!           2) The map integrator does not work for multiple species, only
!              the Lorenze integrator works for the multiple species.
!----------------------------------------------------------------
      module BeamBunchclass
        use CompDomclass
        use Pgrid2dclass
        use BeamLineElemclass
        use Timerclass
        use Fldmgerclass
        use PhysConstclass
        use MathModule
        type BeamBunch
!          private
          !beam freq, current, part. mass and charge.
          double precision :: Current,Mass,Charge
          !# of total global macroparticles and local particles
          integer :: Npt,Nptlocal
          !particles type one.
          double precision, pointer, dimension(:,:) :: Pts1
          !reference particle
          double precision, dimension(6) :: refptcl
        end type BeamBunch
        interface map1_BeamBunch
          module procedure drift1_BeamBunch,drift2_BeamBunch
        end interface
        interface map2_BeamBunch
          module procedure kick1_BeamBunch,kick2_BeamBunch
        end interface
      contains
        subroutine construct_BeamBunch(this,incurr,inkin,inmass,incharge,innp,&
                                       phasini)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(in) :: incurr,inkin,inmass,&
                                        incharge,phasini
        integer, intent(in) :: innp
        integer :: myid, myidx, myidy,comm2d,commrow,commcol,ierr
        integer :: nptot,nprocrow,nproccol
   
        this%Current = incurr
        this%Mass = inmass
        this%Charge = incharge
        this%Npt = innp

        this%refptcl = phasini
        this%refptcl(6) = -(inkin/this%Mass + 1.0)

        end subroutine construct_BeamBunch

        !shift and rotate the beam at the leading edge of the element
        subroutine geomerrL_BeamBunch(this,beamln)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(in) :: beamln
        double precision  :: xerr,yerr,anglerrx,anglerry,anglerrz
        double precision :: dx,dy,anglex,xl,angley,anglez
        double precision, dimension(6) :: temp,tmp
        integer :: i
        real*8 :: gam0,gambetz0,gam,gambetz,betz

        xl = Scxl
        
        call geterr_BeamLineElem(beamln,xerr,yerr,anglerrx,anglerry,anglerrz)
        dx = xerr/xl
        dy = yerr/xl
        anglex = anglerrx
        angley = anglerry
        anglez = anglerrz
        
        !To avoid every elem. go into the loop which is not tilted
        if(abs(dx)+abs(dy)+abs(anglex)+abs(angley)+abs(anglez) &
           .gt.1.0d-12) then
        !print*,"errorL: ",xerr,yerr,anglerrx,anglerry,anglerrz
        gam0 = -this%refptcl(6)
        gambetz0 = sqrt(gam0**2-1.0d0)

        !print*,"before1: ",this%Pts1(1:6,1)
        do i = 1, this%Nptlocal
          temp(1) = this%Pts1(1,i) - dx 
          temp(2) = this%Pts1(2,i)
          temp(3) = this%Pts1(3,i) - dy
          temp(4) = this%Pts1(4,i)
          tmp(1) = temp(1)*cos(anglez) - temp(3)*sin(anglez)
          tmp(2) = temp(2)*cos(anglez) - temp(4)*sin(anglez)
          tmp(3) = temp(1)*sin(anglez) + temp(3)*cos(anglez)
          tmp(4) = temp(2)*sin(anglez) + temp(4)*cos(anglez)
          !5 and 6 corresponds to relative phase and energy. you can not
          !simply transform them and combine with space and momentum.
          gam = gam0 - this%Pts1(6,i)
          gambetz = sqrt(gam**2-1.0-this%Pts1(2,i)**2-this%Pts1(4,i)**2)
          betz = gambetz/gam
          tmp(5) = -this%Pts1(5,i)*betz
          tmp(6) = gambetz - gambetz0
          temp(1) = tmp(1)*cos(angley)-tmp(5)*sin(angley)
          temp(2) = tmp(2)*cos(angley)-tmp(6)*sin(angley)
          temp(3) = tmp(3)
          temp(4) = tmp(4)
          temp(5) = tmp(1)*sin(angley)+tmp(5)*cos(angley)
          temp(6) = tmp(2)*sin(angley)+tmp(6)*cos(angley)
          tmp(1) = temp(1)
          tmp(2) = temp(2)
          tmp(3) = temp(3)*cos(anglex)-temp(5)*sin(anglex)
          tmp(4) = temp(4)*cos(anglex)-temp(6)*sin(anglex)
          tmp(5) = temp(3)*sin(anglex)+temp(5)*cos(anglex) 
          tmp(6) = temp(4)*sin(anglex)+temp(6)*cos(anglex) 
          this%Pts1(1,i) = tmp(1)
          this%Pts1(2,i) = tmp(2)
          this%Pts1(3,i) = tmp(3)
          this%Pts1(4,i) = tmp(4)
          gambetz = gambetz0 + tmp(6)
          gam = sqrt(1.d0+gambetz**2+tmp(2)**2+tmp(4)**2)
          betz = gambetz/gam
          this%Pts1(5,i) = -tmp(5)/betz 
          this%Pts1(6,i) = gam0-gam 
        enddo
        endif
        !print*,"after1: ",this%Pts1(1:6,1)

        end subroutine geomerrL_BeamBunch

        !shift and rotate the beam at the tail edge of the element
        subroutine geomerrT_BeamBunch(this,beamln)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(in) :: beamln
        double precision  :: xerr,yerr,anglerrx,anglerry,anglerrz
        double precision :: dx,dy,anglex,xl,angley,anglez
        double precision, dimension(6) :: temp,tmp
        integer :: i
        real*8 :: gam0,gambetz0,gam,gambetz,betz

        xl = Scxl
        
        call geterr_BeamLineElem(beamln,xerr,yerr,anglerrx,anglerry,anglerrz)
        dx = xerr/xl
        dy = yerr/xl
        !rotate back
        anglex = -anglerrx
        angley = -anglerry
        anglez = -anglerrz

        !To avoid every elem. go into the loop which is not tilted
        if(abs(dx)+abs(dy)+abs(anglex)+abs(angley)+abs(anglez) &
           .gt.1.0d-12) then
        !print*,"errorT: ",xerr,yerr,anglerrx
        !print*,"before2: ",this%Pts1(1:6,1)
        gam0 = -this%refptcl(6)
        gambetz0 = sqrt(gam0**2-1.0d0)

        do i = 1, this%Nptlocal
          !5 and 6 corresponds to relative phase and energy. you can not
          !simply transform them and combine with space and momentum.
          tmp(1) = this%Pts1(1,i)
          tmp(2) = this%Pts1(2,i)
          tmp(3) = this%Pts1(3,i)
          tmp(4) = this%Pts1(4,i)
          gam = gam0 - this%Pts1(6,i)
          gambetz = sqrt(gam**2-1.0-this%Pts1(2,i)**2-this%Pts1(4,i)**2)
          betz = gambetz/gam
          tmp(5) = -this%Pts1(5,i)*betz
          tmp(6) = gambetz - gambetz0
          temp(1) = tmp(1)
          temp(2) = tmp(2)
          temp(3) = tmp(3)*cos(anglex)-tmp(5)*sin(anglex)
          temp(4) = tmp(4)*cos(anglex)-tmp(6)*sin(anglex)
          temp(5) = tmp(3)*sin(anglex)+tmp(5)*cos(anglex) 
          temp(6) = tmp(4)*sin(anglex)+tmp(6)*cos(anglex) 
          tmp(1) = temp(1)*cos(angley)-temp(5)*sin(angley)
          tmp(2) = temp(2)*cos(angley)-temp(6)*sin(angley)
          tmp(3) = temp(3)
          tmp(4) = temp(4)
          tmp(5) = temp(1)*sin(angley)+temp(5)*cos(angley)
          tmp(6) = temp(2)*sin(angley)+temp(6)*cos(angley)
          temp(1) = tmp(1)*cos(anglez) - tmp(3)*sin(anglez)
          temp(2) = tmp(2)*cos(anglez) - tmp(4)*sin(anglez)
          temp(3) = tmp(1)*sin(anglez) + tmp(3)*cos(anglez)
          temp(4) = tmp(2)*sin(anglez) + tmp(4)*cos(anglez)
          temp(5) = tmp(5)
          temp(6) = tmp(6)
          this%Pts1(1,i) = temp(1) + dx 
          this%Pts1(2,i) = temp(2)
          this%Pts1(3,i) = temp(3) + dy 
          this%Pts1(4,i) = temp(4)
          gambetz = gambetz0 + temp(6)
          gam = sqrt(1.d0+gambetz**2+temp(2)**2+temp(4)**2)
          betz = gambetz/gam
          this%Pts1(5,i) = -temp(5)/betz
          this%Pts1(6,i) = gam0-gam 
        enddo
        endif
        !print*,"after2: ",this%Pts1(1:6,1)

        end subroutine geomerrT_BeamBunch

        ! Drift beam half step using linear map for external field.
        subroutine drift1org_BeamBunch(this,beamln,z,tau)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(inout) :: beamln
        double precision, intent(inout) :: z
        double precision, intent (in) :: tau
        double precision, dimension(6) :: temp
        double precision, dimension(6,6) :: xm
        double precision :: t0
        integer :: i,j,k

        call starttime_Timer(t0)

        call maplinear_BeamLineElem(beamln,z,tau,xm,this%refptcl,this%Charge,&
                       this%Mass)

        do i = 1, this%Nptlocal
!          temp(1) = this%Pts1(1,i)*xm(1,1)+this%Pts1(2,i)*xm(1,2)
!          temp(2) = this%Pts1(1,i)*xm(2,1)+this%Pts1(2,i)*xm(2,2)
!          temp(3) = this%Pts1(3,i)*xm(3,3)+this%Pts1(4,i)*xm(3,4)
!          temp(4) = this%Pts1(3,i)*xm(4,3)+this%Pts1(4,i)*xm(4,4)
!          temp(5) = this%Pts1(5,i)*xm(5,5)+this%Pts1(6,i)*xm(5,6)
!          temp(6) = this%Pts1(5,i)*xm(6,5)+this%Pts1(6,i)*xm(6,6)
!          this%Pts1(1,i) = temp(1)
!          this%Pts1(2,i) = temp(2)
!          this%Pts1(3,i) = temp(3)
!          this%Pts1(4,i) = temp(4)
!          this%Pts1(5,i) = temp(5)
!          this%Pts1(6,i) = temp(6)
          do j = 1, 6
            temp(j) = 0.0
            do k = 1, 6
              temp(j) = temp(j) + this%Pts1(k,i)*xm(j,k)
            enddo
          enddo
          do j = 1,6
            this%Pts1(j,i) = temp(j)
          enddo
        enddo

        z=z+tau

        t_map1 = t_map1 + elapsedtime_Timer(t0)

        end subroutine drift1org_BeamBunch

        ! Drift beam half step using linear map for external field.
        subroutine drift1_BeamBunch(this,beamln,z,tau,bitype,nseg,nst,&
                   ihlf,Lc,simutype)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(inout) :: beamln
        double precision, intent(inout) :: z
        double precision, intent (in) :: tau
        integer, intent(in) :: bitype,nseg,nst,simutype
        integer, intent(inout) :: ihlf
        double precision, dimension(6) :: temp
        double precision, dimension(6,6) :: xm
        double precision :: t0
        integer :: i,j,k
        real*8 :: beta0,gam0,gambet0,tmppx,tmppy,tmppt,tmph,x3,qmass
        integer :: idealrf
        real*8, dimension(12) :: drange
        real*8, dimension(3) :: vhphi
        real*8 :: t_ref, brho, K1
        real*8, intent(in) :: Lc

        call starttime_Timer(t0)

        qmass = this%Charge/this%Mass

        if(bitype.eq.0) then
          gam0 = -this%refptcl(6)
          gambet0 = sqrt(gam0**2-1.0)
          beta0 = gambet0/gam0
          !add a parameter following pip radius:
          !ID<0, linear map
          !otherwise, or left unsetted blank, real map
          !This keeps compatibility with previous version. 
          call getparam_BeamLineElem(beamln,3,x3)
          if (x3<0) then   
                !print*,"drift linear map,x3= ",x3            
                do i = 1, this%Nptlocal
                  tmppx = this%Pts1(2,i)
                  tmppy = this%Pts1(4,i)
                  tmppt = this%Pts1(6,i)
                  this%Pts1(1,i) = this%Pts1(1,i)+tmppx/gambet0*tau/Scxl 
                  this%Pts1(3,i) = this%Pts1(3,i)+tmppy/gambet0*tau/Scxl
                  !frozen model
                  this%Pts1(5,i) = this%Pts1(5,i)+tmppt/gambet0*tau/Scxl/gambet0**2                                               
                enddo
                this%refptcl(5) = this%refptcl(5) + tau/(Scxl*beta0)
          else
                !print*,"drift real map,x3= ",x3
                do i = 1, this%Nptlocal
                  tmppx = this%Pts1(2,i)
                  tmppy = this%Pts1(4,i)
                  tmppt = this%Pts1(6,i)
                  tmph = sqrt((tmppt-gam0)**2-1-tmppx**2-tmppy**2) !gambetz**2
                  this%Pts1(1,i) = this%Pts1(1,i)+tmppx/tmph*tau/Scxl
                  this%Pts1(3,i) = this%Pts1(3,i)+tmppy/tmph*tau/Scxl
                  this%Pts1(5,i) = this%Pts1(5,i)-(1./beta0+(tmppt-gam0)/tmph)*&
                                   tau/Scxl
                enddo
                this%refptcl(5) = this%refptcl(5) + tau/(Scxl*beta0)       
          endif   
        else if(bitype.eq.1) then
          call getparam_BeamLineElem(beamln,3,x3)
          !file ID=-5,-15, input value is K1, K1=1/(B\rho_0)*\frac{\partial By}{\partial x},
          !file ID=-6,-16, input value is gradient [T/m].
          if( abs(x3+6.0)<1.0d-6 .or. abs(x3+16.0)<1.0d-6 ) then
            !means input is gradient, change it to K1
            gam0 = -this%refptcl(6)
            gambet0 = sqrt(gam0**2-1.0)
            brho = gambet0/qmass/Clight  !gradient>0, focus, no matter electron or proton
            K1 = beamln%pquad%Param(2)/brho   !K1=gradient/Brho, gradient [T/m]
          else if( abs(x3+5.0)<1.0d-6 .or. abs(x3+15.0)<1.0d-6) then
            ! input value is K1  
            K1 = beamln%pquad%Param(2) 
          else 
            print*,"Unkown ID for QUAD is given: ", x3
            stop
          endif
          !print*,"K1=",K1," ,ID=", x3

          !abs(ID) in (0,10), linear map
          !abs(ID) > 10, nonlinear map
          if( abs(x3)>0.0d0 .and. abs(x3)<10.0d0 ) then
            call transfmapK_Quadrupole_linearmap(z,tau,K1,this%refptcl,this%Nptlocal,&
                                    this%Pts1,qmass)
          else if(abs(x3)>10.0d0) then
            call transfmapK_Quadrupole_nonlinearmap(z,tau,K1,this%refptcl,this%Nptlocal,&
                                    this%Pts1,qmass)
          
          endif                        
          !Ji use this section for linear map 6*6 matrix, I comment it.                         
          !else
          !  call maplinear_BeamLineElem(beamln,z,tau,xm,this%refptcl,this%Charge,&
          !             this%Mass)
          !  do i = 1, this%Nptlocal
          !    do j = 1, 6
          !      temp(j) = 0.0
          !      do k = 1, 6
          !        temp(j) = temp(j) + this%Pts1(k,i)*xm(j,k)
          !      enddo
          !    enddo
          !    do j = 1,6
          !      this%Pts1(j,i) = temp(j)
          !    enddo
          !  enddo
          !endif

        else
          !ideal RF cavity model with entrance and exit focusing
          call getparam_BeamLineElem(beamln,drange)
          if (abs(drange(5)+0.55)<1.0d-6 .or. abs(drange(5)+0.65)<1.0d-6) then
             !Biaobin Li, 2021-04-02
             !For RCS AC mode, volt and phase is changing, which read from
             !rfdata_ac.in
             !----------------------
             !read in volt and phase based on t_ref
             !ID=-0.55, end focus, nonlinear map
             !ID=-0.65, no end focus, nonlinear map

             !get the time based on sync particle
             t_ref = this%refptcl(5)*Scxl/Clight 
             vhphi = math%get_vhphi(t_ref)  
             !update volt/tau, phi, and harmonic number
             drange(2) = vhphi(1)/(2*nseg*tau)    !volt/Lcav,gradient,V/m
             drange(3) = vhphi(2)*Scfreq          !frf=h*f0
             drange(4) = vhphi(3)                 !degree, already
                                                  !changed to cos func, 
             !map ID to -1.0 or -0.75 for transfer map choice
             if (abs(drange(5)+0.55)<1.0d-6) then
                 drange(5) = -1.0
             else if (abs(drange(5)+0.65)<1.0d-6) then
                 drange(5) = -0.75
             end if
          end if

          !Biaobin, add options to control cavity behavior:
          !ID=-0.25,   linear map, comment end focus
          !ID=-0.75,   nonlinear map, comment end focus
          !ID=-0.5,    linear map
          !ID=-1.0,    nonlinear map
          !otherwise, call maplinear_BeamLineElem()       
          if(abs(drange(5)+0.25)<1.0d-6.or.abs(drange(5)+0.5)<1.0d-6) then         
            call idealrf_linearmap(this,drange,tau,nseg,nst,ihlf)
          
          else if(abs(drange(5)+0.75)<1.0d-6.or.abs(drange(5)+1.0)<1.0d-6) then
            call idealrf_nonlinearmap(this,drange,tau,nseg,nst,ihlf,&
                 Lc,simutype)
          
          else
            ! original 103 element?       
            call maplinear_BeamLineElem(beamln,z,tau,xm,this%refptcl,this%Charge,&
                       this%Mass)
            do i = 1, this%Nptlocal
              do j = 1, 6
                temp(j) = 0.0
                do k = 1, 6
                  temp(j) = temp(j) + this%Pts1(k,i)*xm(j,k)
                enddo
              enddo
              do j = 1,6
                this%Pts1(j,i) = temp(j)
              enddo
            enddo
          endif

        endif

        z=z+tau
        ihlf = ihlf + 1

        t_map1 = t_map1 + elapsedtime_Timer(t0)

        end subroutine drift1_BeamBunch

! drift half step using nonlinear Lorentz integrator
        subroutine drift2_BeamBunch(this,z,tau)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(inout) :: z
        double precision, intent (in) :: tau
        double precision :: xl,pz
        double precision :: t0,beta0,gamma0
        double precision, dimension(9) :: blparam
        integer :: mapstp,itype,bsg,ierr,my_rank
        double precision :: blg,gt,frqhz,thdeg,escale,theta0,qmcc,ww,tau1
        integer :: i
        real*8 :: pztmp

        call starttime_Timer(t0)

        xl = Scxl
        gamma0 = -this%refptcl(6)
        beta0 = sqrt(1.0-1.0/gamma0/gamma0)
        !print*,"beta0: ",gamma0
        do i = 1, this%Nptlocal
          pz = sqrt((gamma0-this%Pts1(6,i))**2-1.0-this%Pts1(2,i)**2- &
                    this%Pts1(4,i)**2)
          !pztmp = (gamma0-this%Pts1(6,i))**2-1.0-this%Pts1(2,i)**2- &
          !          this%Pts1(4,i)**2
          !if(pztmp.lt.0.0) then
          !  print*,"pztmp: ",pztmp,i,this%Pts1(:,i),gamma0
          !else
          !  pz = sqrt(pztmp) 
          !endif
          this%Pts1(1,i) = this%Pts1(1,i)+0.5*tau*this%Pts1(2,i)/(xl*pz)
          this%Pts1(3,i) = this%Pts1(3,i)+0.5*tau*this%Pts1(4,i)/(xl*pz)
          this%Pts1(5,i) = this%Pts1(5,i)+0.5*tau*((gamma0-this%Pts1(6,i))/&
                           (xl*pz)-1.0/(beta0*xl))
        enddo

        this%refptcl(5) = this%refptcl(5) + 0.5*tau/(xl*beta0)

        z=z+0.5*tau

        t_map1 = t_map1 + elapsedtime_Timer(t0)

        end subroutine drift2_BeamBunch

! drift half step using nonlinear Lorentz integrator for halo study
        subroutine drift2halo_BeamBunch(this,z,tau)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(inout) :: z
        double precision, intent (in) :: tau
        double precision :: xl,pz
        double precision :: t0,beta0,gamma0
        double precision, dimension(9) :: blparam
        integer :: mapstp,itype,bsg,ierr,my_rank
        double precision :: blg,gt,frqhz,thdeg,escale,theta0,qmcc,ww,tau1
        integer :: i

        call starttime_Timer(t0)

        xl = Scxl
        gamma0 = -this%refptcl(6)
        beta0 = sqrt(1.0-1.0/gamma0/gamma0)
        pz = gamma0*beta0
        do i = 1, this%Nptlocal
!          pz = sqrt((gamma0-this%Pts1(6,i))**2-1.0-this%Pts1(2,i)**2- &
!                    this%Pts1(4,i)**2)
          this%Pts1(1,i) = this%Pts1(1,i)+0.5*tau*this%Pts1(2,i)/(xl*pz)
          this%Pts1(3,i) = this%Pts1(3,i)+0.5*tau*this%Pts1(4,i)/(xl*pz)
!          this%Pts1(5,i) = this%Pts1(5,i)+0.5*tau*((gamma0-this%Pts1(6,i))/&
!                           (xl*pz)-1.0/(beta0*xl))
          this%Pts1(5,i) = this%Pts1(5,i)+0.5*tau*this%Pts1(6,i)/&
                           (xl*pz*pz*pz)
        enddo

        this%refptcl(5) = this%refptcl(5) + 0.5*tau/(xl*beta0)

        z=z+0.5*tau

        t_map1 = t_map1 + elapsedtime_Timer(t0)

        end subroutine drift2halo_BeamBunch

        !counter the particles get lost outside the xrad and yrad.
        !we have not put the lost through rf bucket yet.
        subroutine lostcount_BeamBunch(this,nplc,nptot,xrad,yrad,Lc, &
                   simutype)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(in) :: xrad,yrad
        integer, intent(out) :: nplc,nptot
        integer :: i
        double precision :: tmpx,tmpy,pilc,xl,rad,tmp5
        integer :: ilost,i0,ierr,ntmp5
        real*8 :: tmpbet,rcpgammai,gam
        real*8, intent(in) :: Lc
        integer, intent(in) :: simutype
        real*8 :: bet0,f0,fs,radtest

        pilc = 2.0*asin(1.0)
        xl = Scxl
        rad = (xrad+yrad)/2 
        gam = -this%refptcl(6)
        bet0= sqrt(1.0d0-1.0d0/gam**2)

        !biaobin, for ring simulation, phase should be fold 
        !based on f0
        !simutype=1, Linac, no folding
        !simutype=2, Ring
        fs = Scfreq    !scaling freq set in ImpactZ.in 
        f0 = bet0*Clight/Lc

        ilost = 0
        do i0 = 1, this%Nptlocal
          i = i0 - ilost

          rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
          tmpbet = (1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )

          this%Pts1(1,i) = this%Pts1(1,i0)
          this%Pts1(2,i) = this%Pts1(2,i0)
          this%Pts1(3,i) = this%Pts1(3,i0)
          this%Pts1(4,i) = this%Pts1(4,i0)

          !biaobin, only apply phase fold for RING simu;
          !for linac, phase outside (-pi,pi), lost 
          !--------------------------------------------
          if (simutype.eq.1) then
            if(abs(this%Pts1(5,i0)).ge.pilc) then
              ilost = ilost + 1
            end if
          elseif (simutype.eq.2) then
            !biaobin, change the phase refer to f0
            this%Pts1(5,i0) = f0/fs*this%Pts1(5,i0)
            !phase folding
            ntmp5 = this%Pts1(5,i0)/pilc
            tmp5 = this%Pts1(5,i0) - ntmp5*pilc
            this%Pts1(5,i0) = tmp5 - mod(ntmp5,2)*pilc
            !biaobin, back to phase based on fs
            this%Pts1(5,i0) = fs/f0*this%Pts1(5,i0)
          endif

          this%Pts1(5,i) = this%Pts1(5,i0)
          this%Pts1(6,i) = this%Pts1(6,i0)
          this%Pts1(7,i) = this%Pts1(7,i0)
          this%Pts1(8,i) = this%Pts1(8,i0)
          this%Pts1(9,i) = this%Pts1(9,i0)
          tmpx = this%Pts1(1,i0)*xl
          tmpy = this%Pts1(3,i0)*xl

          !Following lines are for round pipe
          !----------------------------------
          radtest = sqrt(tmpx**2+tmpy**2)
          if(radtest.ge.rad) then
            ilost = ilost + 1
          endif
        
          !Following lines are for rectangular pipe
          !----------------------------------
          !if(tmpx.le.(-xrad)) then
          !  ilost = ilost + 1
          !  !print*,"lostx ",tmpbet,rcpgammai,this%refptcl(6),this%Pts1(1,i0),tmpx
          !else if(tmpx.ge.xrad) then
          !  ilost = ilost + 1
          !  !print*,"lostx ",tmpbet,rcpgammai,this%refptcl(6),this%Pts1(1,i0),tmpx
          !else if(tmpy.le.(-yrad)) then
          !  ilost = ilost + 1
          !  !print*,"losty ",tmpbet,rcpgammai,this%refptcl(6),this%Pts1(3,i0),tmpy
          !else if(tmpy.ge.yrad) then
          !  ilost = ilost + 1
          !endif

          if(tmpbet.le.0.0) then
            ilost = ilost + 1
          endif
 
          !print*,"losty ",tmpbet,rcpgammai,this%refptcl(6),this%Pts1(3,i0),tmpy
          ! print*,"lost ",tmpbet,rcpgammai,this%refptcl(6),this%Pts1(2,i0),&
          !           this%Pts1(4,i0),this%Pts1(5,i0),this%Pts1(6,i0) 
        enddo

        this%Nptlocal = this%Nptlocal - ilost
        nplc = this%Nptlocal
        call MPI_ALLREDUCE(nplc,nptot,1,MPI_INTEGER,&
                           MPI_SUM,MPI_COMM_WORLD,ierr)
        this%Npt = nptot

        end subroutine lostcount_BeamBunch

        !counter the particles get lost outside the xrad and yrad.
        !we have not put the lost through rf bucket yet.
        subroutine lostcountXY_BeamBunch(this,nplc,nptot,x1,x2,&
                                         y1,y2)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(inout) :: x1,x2,y1,y2
        integer, intent(out) :: nplc,nptot
        integer :: i
        double precision :: tmpx,tmpy,xl
        integer :: ilost,i0,ierr
        double precision :: xapmin,xapmax,yapmin,yapmax

        xl = Scxl
        xapmin = x1/xl
        xapmax = x2/xl
        yapmin = y1/xl
        yapmax = y2/xl
   
        ilost = 0

        do i0 = 1, this%Nptlocal
          i = i0 - ilost

          this%Pts1(1,i) = this%Pts1(1,i0)
          this%Pts1(2,i) = this%Pts1(2,i0)
          this%Pts1(3,i) = this%Pts1(3,i0)
          this%Pts1(4,i) = this%Pts1(4,i0)
          this%Pts1(5,i) = this%Pts1(5,i0)
          this%Pts1(6,i) = this%Pts1(6,i0)
          this%Pts1(7,i) = this%Pts1(7,i0)
          this%Pts1(8,i) = this%Pts1(8,i0)
          this%Pts1(9,i) = this%Pts1(9,i0)
          tmpx = this%Pts1(1,i0)
          tmpy = this%Pts1(3,i0)

          if(tmpx.le.xapmin) then
            ilost = ilost + 1
          else if(tmpx.ge.xapmax) then
            ilost = ilost + 1
          else if(tmpy.le.yapmin) then
            ilost = ilost + 1
          else if(tmpy.ge.yapmax) then
            ilost = ilost + 1
          endif
        enddo

        this%Nptlocal = this%Nptlocal - ilost
        nplc = this%Nptlocal
        call MPI_ALLREDUCE(nplc,nptot,1,MPI_INTEGER,&
                           MPI_SUM,MPI_COMM_WORLD,ierr)
        this%Npt = nptot

        end subroutine lostcountXY_BeamBunch

        !//update the total current fraction of each charge state
        !//update total # of ptcl for each charge state
        subroutine chgupdate_BeamBunch(this,nchge,idchgold,qmcclist)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: nchge
        integer, dimension(:), intent(inout) :: idchgold
        double precision, dimension(:), intent(in) :: qmcclist
        integer :: i, j, ierr
        integer, dimension(nchge) :: idchglc,idchg
        double precision :: dd,eps

        !eps = 1.0e-8
        eps = 1.0e-4
        idchglc = 0 !//local # of ptcl of each charge state
        do i = 1, this%Nptlocal
          do j = 1, nchge
            dd = abs((this%Pts1(7,i)-qmcclist(j))/qmcclist(j))
            if(dd.lt.eps) then
              idchglc(j) = idchglc(j) + 1
            endif
          enddo
        enddo

        !//get total # of ptcl for each charge state
        call MPI_ALLREDUCE(idchglc,idchg,nchge,MPI_INTEGER,&
                           MPI_SUM,MPI_COMM_WORLD,ierr)

        !//update the total current fraction of each charge state
!        do i = 1, this%Nptlocal
!          do j = 1, nchge
!            dd = abs((this%Pts1(7,i)-qmcclist(j))/qmcclist(j))
!            if(dd.lt.eps) then
!              this%Pts1(8,i) = this%Pts1(8,i)*idchg(j)/idchgold(j)
!            endif
!          enddo
!        enddo

        !//update total # of ptcl for each charge state
        idchgold = idchg

        end subroutine chgupdate_BeamBunch

        !0th order algorithm to transfer from z to t frame.
        subroutine convforth0th_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer :: i
        double precision :: gam,bet,gammai,betai,xl,rcpgammai

        xl = Scxl
        gam = -this%refptcl(6)
        bet = sqrt(gam**2-1.0)/gam
      
        do i = 1, this%Nptlocal
           rcpgammai = 1.0/(-this%Pts1(6,i)+gam)
           betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i)**2+ &
                        this%Pts1(4,i)**2) )
           this%Pts1(1,i) = this%Pts1(1,i)*xl
           this%Pts1(3,i) = this%Pts1(3,i)*xl
           this%Pts1(5,i) = -betai*this%Pts1(5,i)*xl
           this%Pts1(6,i) = betai/rcpgammai
        enddo

        end subroutine convforth0th_BeamBunch

        !Linear(1st order) algorithm to transfer from z to t frame.
        subroutine convforth1st_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer :: i
        double precision :: gam,bet,rcpgammai,betai,xl

        xl = Scxl
        gam = -this%refptcl(6)
        bet = sqrt(gam**2-1.0)/gam
      
        do i = 1, this%Nptlocal
           rcpgammai = 1.0/(-this%Pts1(6,i)+gam)
           betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i)**2+ &
                        this%Pts1(4,i)**2) )
           this%Pts1(1,i) = (this%Pts1(1,i)-this%Pts1(2,i) &
                            *this%Pts1(5,i)*rcpgammai)*xl
           this%Pts1(3,i) = (this%Pts1(3,i)-this%Pts1(4,i) &
                            *this%Pts1(5,i)*rcpgammai)*xl
           this%Pts1(5,i) = -betai*this%Pts1(5,i)*xl
           this%Pts1(6,i) = betai/rcpgammai
        enddo

        end subroutine convforth1st_BeamBunch

        !0th order algorithm to transfer from t to z frame.
        subroutine convback0th_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer :: i
        double precision :: gamma0,xk,xl
        double precision :: rcpgammai,betai,beta

        xl = Scxl
        xk = 1/xl

        gamma0 = -this%refptcl(2)
        beta = sqrt(gamma0*gamma0 - 1.0)/gamma0

        do i = 1, this%Nptlocal
          rcpgammai = 1.0/sqrt(1.0+this%Pts1(2,i)**2+this%Pts1(4,i)**2+this%Pts1(6,i)**2)
          betai = this%Pts1(6,i)*rcpgammai
          this%Pts1(6,i) = gamma0 - 1.0/rcpgammai 
          this%Pts1(5,i) = this%Pts1(5,i)*xk/(-betai)
          this%Pts1(1,i) = this%Pts1(1,i)*xk
          this%Pts1(3,i) = this%Pts1(3,i)*xk
        enddo

        end subroutine convback0th_BeamBunch

        !Linear algorithm to transfer from t to z frame.
        subroutine convback1st_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer :: i
        double precision :: gamma0,xk,xl
        double precision :: rcpgammai,betai,beta

        xl = Scxl
        xk = 1/xl

        gamma0 = -this%refptcl(6)
        beta = sqrt(gamma0*gamma0 - 1.0)/gamma0

        do i = 1, this%Nptlocal
          rcpgammai = 1.0/sqrt(1.0+this%Pts1(2,i)**2+this%Pts1(4,i)**2+this%Pts1(6,i)**2)
          betai = this%Pts1(6,i)*rcpgammai
          this%Pts1(6,i) = gamma0 - 1.0/rcpgammai 
          this%Pts1(5,i) = this%Pts1(5,i)*xk/(-betai)
          this%Pts1(1,i) = this%Pts1(1,i)*xk+this%Pts1(2,i) &
                            *this%Pts1(5,i)*rcpgammai
          this%Pts1(3,i) = this%Pts1(3,i)*xk+this%Pts1(4,i) &
                            *this%Pts1(5,i)*rcpgammai
        enddo

        end subroutine convback1st_BeamBunch

        !from z to t beam frame 0th order approximation.
        subroutine conv0thold_BeamBunch(this,tau,rad,nplc,nptot)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(in) :: tau
        double precision, intent(in) :: rad
        integer, intent(out) :: nplc,nptot
        integer :: i
        double precision :: xk,xl
        double precision :: pilc,gam,bet,bbyk,rcpgammai,betai
        double precision :: twopi,radtest,tmp0,tmpx,tmpy
        integer :: ilost,i0,ierr

        pilc = 2.0*asin(1.0)
        twopi = 2.0*pilc
        xl = Scxl
        xk = 1/xl

        gam = -this%refptcl(6)
        bet = sqrt(gam**2-1.0)/gam
      
        ilost = 0
        do i0 = 1, this%Nptlocal
          i = i0 - ilost
          ! The following steps go from z to t frame.
          this%Pts1(1,i) = this%Pts1(1,i0)*xl
          this%Pts1(2,i) = this%Pts1(2,i0)
          this%Pts1(3,i) = this%Pts1(3,i0)*xl
          this%Pts1(4,i) = this%Pts1(4,i0)
          ! multiply by gamma (=-a(2)) to go to the bunch frame:
          rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                      this%Pts1(4,i0)**2) )
          this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
          this%Pts1(6,i) = this%Pts1(6,i0)

          radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                    this%Pts1(3,i)*this%Pts1(3,i))
          if(radtest.ge.rad) then
            ilost = ilost + 1
          endif
        enddo
        this%Nptlocal = this%Nptlocal - ilost
        nplc = this%Nptlocal
        call MPI_ALLREDUCE(nplc,nptot,1,MPI_INTEGER,&
                           MPI_SUM,MPI_COMM_WORLD,ierr)

        this%Current = this%Current*nptot/this%Npt
        this%Npt = nptot

        end subroutine conv0thold_BeamBunch

        !from z to t beam frame 0th order transformation.
        subroutine conv0th_BeamBunch(this,tau,nplc,nptot,ptrange,&
                                     Flagbc,perd,xrad,yrad)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(in) :: tau,xrad,yrad,perd
        integer, intent(in) :: Flagbc
        double precision, dimension(6), intent(out) :: ptrange
        integer, intent(out) :: nplc,nptot
        integer :: i
        double precision :: xk,xl
        double precision :: pilc,gam,bet,bbyk,rcpgammai,betai,rad
        double precision :: twopi,radtest,tmp0,tmpx,tmpy,tmp5,halfperd
        integer :: ilost,i0,ierr,ntmp5

        pilc = 2.0*asin(1.0)
        twopi = 2.0*pilc
        xl = Scxl
        xk = 1/xl

        gam = -this%refptcl(6)
        bet = sqrt(gam**2-1.0)/gam
        bbyk = bet/xk
        rad = (xrad+yrad)/2 
      
        do i = 1, 3
          ptrange(2*i-1) = 1.0e20
          ptrange(2*i) = -1.0e20
        enddo

        halfperd = 0.5*perd

        if(Flagbc.eq.1) then ! open 3D
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            !if(abs(this%Pts1(5,i0)).ge.pilc) then
            !  ilost = ilost + 1
            !  goto 100
            !endif
            ! The following steps go from z to t frame.
            ! 2) zeroth algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )
            tmp0 = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = this%Pts1(1,i0)*xl

            if(ptrange(1)>tmp0) then
              ptrange(1) = tmp0
            endif
            if(ptrange(2)<tmp0) then
              ptrange(2) = tmp0
            endif

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmp0 = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = this%Pts1(3,i0)*xl

            if(ptrange(3)>tmp0) then
              ptrange(3) = tmp0
            endif
            !tmp0 = max(tmpy,this%Pts1(3,i))
            if(ptrange(4)<tmp0) then
              ptrange(4) = tmp0
            endif
 
            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            if(ptrange(5)>this%Pts1(5,i)) then
              ptrange(5) = this%Pts1(5,i)
            endif
            if(ptrange(6)<this%Pts1(5,i)) then
              ptrange(6) = this%Pts1(5,i)
            endif

            this%Pts1(6,i) = this%Pts1(6,i0)
            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            if(radtest.ge.rad) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
100         continue
          enddo
        else if(Flagbc.eq.2) then ! open 2D, 1D z periodic
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                       this%Pts1(4,i0)**2) )

!            ntmp5 = this%Pts1(5,i0)/pilc
!            tmp5 = this%Pts1(5,i0) - ntmp5*pilc 
!            if(mod(ntmp5,2).eq.0) then
!              this%Pts1(5,i0) = tmp5
!            else
!              if(tmp5.gt.0.0) then
!                this%Pts1(5,i0) = tmp5 - pilc
!              else
!                this%Pts1(5,i0) = tmp5 + pilc
!              endif 
!            endif
 
            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            ntmp5 = this%Pts1(5,i)/halfperd
            tmp5 = this%Pts1(5,i) - ntmp5*halfperd 
            this%Pts1(5,i) = tmp5 - mod(ntmp5,2)*halfperd
            tmp5 = -this%Pts1(5,i)/(gam*betai*xl)

            this%Pts1(6,i) = this%Pts1(6,i0)
            tmp0 = this%Pts1(1,i0)*xl
! for perd bunch
            this%Pts1(1,i) = this%Pts1(1,i0)*xl

            if(ptrange(1)>tmp0) then
               ptrange(1) = tmp0
            endif
            if(ptrange(2)<tmp0) then
               ptrange(2) = tmp0
            endif

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmp0 = this%Pts1(3,i0)*xl
! for perd bunch
            this%Pts1(3,i) = this%Pts1(3,i0)*xl

            if(ptrange(3)>tmp0) then
              ptrange(3) = tmp0
            endif
            if(ptrange(4)<tmp0) then
               ptrange(4) = tmp0
            endif

! for perd bunch
!            this%Pts1(4,i) = this%Pts1(4,i0)
!            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
!            this%Pts1(6,i) = this%Pts1(6,i0)

            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            if(radtest.ge.rad) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
          enddo
          ptrange(5) = -halfperd
          ptrange(6) = halfperd
        else if(Flagbc.eq.3) then !round pipe, 1D z open
          ptrange(1) = 0.0
          ptrange(2) = xrad
          ptrange(3) = 0.0
          ptrange(4) = 4*asin(1.0)
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )
            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = this%Pts1(1,i0)*xl

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = this%Pts1(3,i0)*xl

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            if(ptrange(5)>this%Pts1(5,i)) then
              ptrange(5) = this%Pts1(5,i)
            endif
            if(ptrange(6)<this%Pts1(5,i)) then
              ptrange(6) = this%Pts1(5,i)
            endif

            this%Pts1(6,i) = this%Pts1(6,i0)
            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            tmp5 = sqrt(tmpx*tmpx+tmpy*tmpy)
            if((radtest.ge.rad).or.(tmp5.ge.rad)) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
          enddo
        else if(Flagbc.eq.4) then
          ptrange(1) = 0.0
          ptrange(2) = xrad
          ptrange(3) = 0.0
          ptrange(4) = 4*asin(1.0)
          ptrange(5) = -halfperd
          ptrange(6) = halfperd
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
            ntmp5 = this%Pts1(5,i)/halfperd
            !if(ntmp5.eq.1) then
            !  print*,"ntmp5: ",ntmp5,this%Pts1(5,i),halfperd,xl,gam*betai
            !endif
            tmp5 = this%Pts1(5,i) - ntmp5*halfperd
            this%Pts1(5,i) = tmp5 - mod(ntmp5,2)*halfperd
            this%Pts1(6,i) = this%Pts1(6,i0)

            tmp5 = -this%Pts1(5,i)/(gam*betai*xl)

            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = this%Pts1(1,i0)*xl
            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = this%Pts1(3,i0)*xl

            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            tmp5 = sqrt(tmpx*tmpx+tmpy*tmpy)
            if((radtest.ge.rad).or.(tmp5.ge.rad)) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
          enddo
        else if(Flagbc.eq.5) then !2D rectangular finite, 1D z open
          ptrange(1) = -xrad
          ptrange(2) = xrad
          ptrange(3) = -yrad
          ptrange(4) = yrad
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )
            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = this%Pts1(1,i0)*xl
            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = this%Pts1(3,i0)*xl
            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            if(ptrange(5)>this%Pts1(5,i)) then
              ptrange(5) = this%Pts1(5,i)
            endif
            if(ptrange(6)<this%Pts1(5,i)) then
              ptrange(6) = this%Pts1(5,i)
            endif

            this%Pts1(6,i) = this%Pts1(6,i0)

            if(tmpx.le.(-xrad)) then
              ilost = ilost + 1
            else if(tmpx.ge.xrad) then
              ilost = ilost + 1
            else if(tmpy.le.(-yrad)) then
              ilost = ilost + 1
            else if(tmpy.gt.yrad) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).le.(-xrad)) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).ge.xrad) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).le.(-yrad)) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).ge.yrad) then
              ilost = ilost + 1
            else
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
          enddo
        else if(Flagbc.eq.6) then
          ptrange(1) = -xrad
          ptrange(2) = xrad
          ptrange(3) = -yrad
          ptrange(4) = yrad
          ptrange(5) = -halfperd
          ptrange(6) = halfperd
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
            ntmp5 = this%Pts1(5,i)/halfperd
            tmp5 = this%Pts1(5,i) - ntmp5*halfperd 
            this%Pts1(5,i) = tmp5 - mod(ntmp5,2)*halfperd
            this%Pts1(6,i) = this%Pts1(6,i0)

            tmp5 = -this%Pts1(5,i)/(gam*betai*xl)

            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = this%Pts1(1,i0)*xl
            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = this%Pts1(3,i0)*xl

            if(tmpx.le.(-xrad)) then
              ilost = ilost + 1
            else if(tmpx.ge.xrad) then
              ilost = ilost + 1
            else if(tmpy.le.(-yrad)) then
              ilost = ilost + 1
            else if(tmpy.gt.yrad) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).le.(-xrad)) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).ge.xrad) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).le.(-yrad)) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).ge.yrad) then
              ilost = ilost + 1
            else
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
          enddo
        else
          print*,"no such boundary condition!!!"
          stop
        endif

        this%Nptlocal = this%Nptlocal - ilost
        nplc = this%Nptlocal
        call MPI_ALLREDUCE(nplc,nptot,1,MPI_INTEGER,&
                           MPI_SUM,MPI_COMM_WORLD,ierr)

        this%Current = this%Current*nptot/this%Npt
        this%Npt = nptot

        end subroutine conv0th_BeamBunch

        !from z to t beam frame 1st order transformation.
        subroutine conv1st_BeamBunch(this,tau,nplc,nptot,ptrange,&
                                     Flagbc,perd,xrad,yrad,Lc,simutype)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(in) :: tau,xrad,yrad,perd,Lc
        integer, intent(in) :: Flagbc,simutype
        double precision, dimension(6), intent(out) :: ptrange
        integer, intent(out) :: nplc,nptot
        integer :: i
        double precision :: xk,xl
        double precision :: pilc,gam,bet,bbyk,rcpgammai,betai,rad
        double precision :: twopi,radtest,tmp0,tmpx,tmpy,tmp5,halfperd
        integer :: ilost,i0,ierr,ntmp5
        real*8 :: tmpbet,f0,fs

        pilc = 2.0*asin(1.0)
        twopi = 2.0*pilc
        xl = Scxl
        xk = 1/xl

        gam = -this%refptcl(6)
        bet = sqrt(gam**2-1.0)/gam
        
        !biaobin, for ring simu, phase should be fold based on f0
        fs = Scfreq
        f0 = bet*Clight/Lc

        bbyk = bet/xk
        rad = (xrad+yrad)/2 
        do i = 1, 3
          ptrange(2*i-1) = 1.0e20
          ptrange(2*i) = -1.0e20
        enddo

        halfperd = 0.5*perd

        if(Flagbc.eq.1) then ! open 3D
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
           
            if(simutype.eq.1) then
              !for linac, no phase folding; uncomment Ji's particle loss
              !mechanism, particle outside (-pi,pi), lost
              if(abs(this%Pts1(5,i0)).ge.pilc) then
               ilost = ilost + 1
               goto 100
              endif

            else if(simutype.eq.2) then
              !biaobin, the ring length is (-pi,pi), outside particle
              !should fold into (-pi,pi) based on the f0 
              this%Pts1(5,i0) = f0/fs*this%Pts1(5,i0)      

              ntmp5 = this%Pts1(5,i0)/pilc
              tmp5 = this%Pts1(5,i0) - ntmp5*pilc
              this%Pts1(5,i0) = tmp5 - mod(ntmp5,2)*pilc

              this%Pts1(5,i0) = fs/f0*this%Pts1(5,i0)      
            end if

            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            tmpbet = (1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )
            betai = sqrt(abs(tmpbet))
            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
                             *this%Pts1(5,i0)*rcpgammai)*xl

            tmp0 = min(tmpx,this%Pts1(1,i))
            if(ptrange(1)>tmp0) then
              ptrange(1) = tmp0
            endif
            tmp0 = max(tmpx,this%Pts1(1,i))
            if(ptrange(2)<tmp0) then
              ptrange(2) = tmp0
            endif

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
                             *this%Pts1(5,i0)*rcpgammai)*xl

            tmp0 = min(tmpy,this%Pts1(3,i))
            if(ptrange(3)>tmp0) then
              ptrange(3) = tmp0
            endif
            tmp0 = max(tmpy,this%Pts1(3,i))
            if(ptrange(4)<tmp0) then
              ptrange(4) = tmp0
            endif
 
            this%Pts1(4,i) = this%Pts1(4,i0)

!            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i)*xl
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            if(ptrange(5)>this%Pts1(5,i)) then
              ptrange(5) = this%Pts1(5,i)
            endif
            if(ptrange(6)<this%Pts1(5,i)) then
              ptrange(6) = this%Pts1(5,i)
            endif

            this%Pts1(6,i) = this%Pts1(6,i0)
            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            if(radtest.ge.rad .or. tmpbet.le.0.0) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
100         continue
          enddo
          !if(ilost.ne.0) then
          !    print*,"ilost=",ilost
          !endif
        else if(Flagbc.eq.2) then ! open 2D, 1D z periodic
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                       this%Pts1(4,i0)**2) )

!            ntmp5 = this%Pts1(5,i0)/pilc
!            tmp5 = this%Pts1(5,i0) - ntmp5*pilc 
!            if(mod(ntmp5,2).eq.0) then
!              this%Pts1(5,i0) = tmp5
!            else
!              if(tmp5.gt.0.0) then
!                this%Pts1(5,i0) = tmp5 - pilc
!              else
!                this%Pts1(5,i0) = tmp5 + pilc
!              endif 
!            endif
 
            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            ntmp5 = this%Pts1(5,i)/halfperd
            tmp5 = this%Pts1(5,i) - ntmp5*halfperd 
            this%Pts1(5,i) = tmp5 - mod(ntmp5,2)*halfperd
            tmp5 = -this%Pts1(5,i)/(gam*betai*xl)

            this%Pts1(6,i) = this%Pts1(6,i0)
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)

            tmpx = this%Pts1(1,i0)*xl
! for perd bunch
!            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
!                              *this%Pts1(5,i0)*rcpgammai)*xl
            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
                              *tmp5*rcpgammai)*xl
!            this%Pts1(1,i) = tmpx

            tmp0 = min(tmpx,this%Pts1(1,i))
            !tmp0 = this%Pts1(1,i)
            if(ptrange(1)>tmp0) then
               ptrange(1) = tmp0
            endif
            tmp0 = max(tmpx,this%Pts1(1,i))
            !tmp0 = this%Pts1(1,i)
            if(ptrange(2)<tmp0) then
               ptrange(2) = tmp0
            endif

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
! for perd bunch
!            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
!                              *this%Pts1(5,i0)*rcpgammai)*xl
            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
                              *tmp5*rcpgammai)*xl
!            this%Pts1(3,i) = tmpy

            tmp0 = min(tmpy,this%Pts1(3,i))
            !tmp0 = this%Pts1(3,i)
            if(ptrange(3)>tmp0) then
              ptrange(3) = tmp0
            endif
            tmp0 = max(tmpy,this%Pts1(3,i))
            !tmp0 = this%Pts1(3,i)
            if(ptrange(4)<tmp0) then
               ptrange(4) = tmp0
            endif

! for perd bunch
!            this%Pts1(4,i) = this%Pts1(4,i0)
!            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
!            this%Pts1(6,i) = this%Pts1(6,i0)

            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            if(radtest.ge.rad) then
              ilost = ilost + 1
            endif
          enddo
          ptrange(5) = -halfperd
          ptrange(6) = halfperd
        else if(Flagbc.eq.3) then !round pipe, 1D z open
          ptrange(1) = 0.0
          ptrange(2) = xrad
          ptrange(3) = 0.0
          ptrange(4) = 4*asin(1.0)
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )
            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
                             *this%Pts1(5,i0)*rcpgammai)*xl

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
                             *this%Pts1(5,i0)*rcpgammai)*xl

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            if(ptrange(5)>this%Pts1(5,i)) then
              ptrange(5) = this%Pts1(5,i)
            endif
            if(ptrange(6)<this%Pts1(5,i)) then
              ptrange(6) = this%Pts1(5,i)
            endif

            this%Pts1(6,i) = this%Pts1(6,i0)
            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            tmp5 = sqrt(tmpx*tmpx+tmpy*tmpy)
            if((radtest.ge.rad).or.(tmp5.ge.rad)) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)

          enddo
        else if(Flagbc.eq.4) then
          ptrange(1) = 0.0
          ptrange(2) = xrad
          ptrange(3) = 0.0
          ptrange(4) = 4*asin(1.0)
          ptrange(5) = -halfperd
          ptrange(6) = halfperd
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
            ntmp5 = this%Pts1(5,i)/halfperd
            tmp5 = this%Pts1(5,i) - ntmp5*halfperd
            this%Pts1(5,i) = tmp5 - mod(ntmp5,2)*halfperd
            this%Pts1(6,i) = this%Pts1(6,i0)

            tmp5 = -this%Pts1(5,i)/(gam*betai*xl)

            tmpx = this%Pts1(1,i0)*xl
!            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
!                             *this%Pts1(5,i0)*rcpgammai)*xl
            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
                             *tmp5*rcpgammai)*xl
!            this%Pts1(1,i) = tmpx

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
!            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
!                             *this%Pts1(5,i0)*rcpgammai)*xl
            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
                             *tmp5*rcpgammai)*xl
!            this%Pts1(3,i) = tmpy

            radtest = sqrt(this%Pts1(1,i)*this%Pts1(1,i)+ &
                      this%Pts1(3,i)*this%Pts1(3,i))
            tmp5 = sqrt(tmpx*tmpx+tmpy*tmpy)
            if((radtest.ge.rad).or.(tmp5.ge.rad)) then
              ilost = ilost + 1
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)

          enddo
        else if(Flagbc.eq.5) then !2D rectangular finite, 1D z open
          ptrange(1) = -xrad
          ptrange(2) = xrad
          ptrange(3) = -yrad
          ptrange(4) = yrad
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )
            tmpx = this%Pts1(1,i0)*xl
            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
                             *this%Pts1(5,i0)*rcpgammai)*xl

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
                             *this%Pts1(5,i0)*rcpgammai)*xl

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl

            if(ptrange(5)>this%Pts1(5,i)) then
              ptrange(5) = this%Pts1(5,i)
            endif
            if(ptrange(6)<this%Pts1(5,i)) then
              ptrange(6) = this%Pts1(5,i)
            endif

            this%Pts1(6,i) = this%Pts1(6,i0)

            if(tmpx.le.(-xrad)) then
              ilost = ilost + 1
            else if(tmpx.ge.xrad) then
              ilost = ilost + 1
            else if(tmpy.le.(-yrad)) then
              ilost = ilost + 1
            else if(tmpy.gt.yrad) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).le.(-xrad)) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).ge.xrad) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).le.(-yrad)) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).ge.yrad) then
              ilost = ilost + 1
            else
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)

          enddo
        else if(Flagbc.eq.6) then
          ptrange(1) = -xrad
          ptrange(2) = xrad
          ptrange(3) = -yrad
          ptrange(4) = yrad
          ptrange(5) = -halfperd
          ptrange(6) = halfperd
          ilost = 0
          do i0 = 1, this%Nptlocal
            i = i0 - ilost
            ! The following steps go from z to t frame.
            ! 2) Linear algorithm to transfer from z to t frame.
            rcpgammai = 1.0/(-this%Pts1(6,i0)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i0)**2+ &
                        this%Pts1(4,i0)**2) )

            this%Pts1(4,i) = this%Pts1(4,i0)
            this%Pts1(5,i) = -gam*betai*this%Pts1(5,i0)*xl
            ntmp5 = this%Pts1(5,i)/halfperd
            tmp5 = this%Pts1(5,i) - ntmp5*halfperd 
            this%Pts1(5,i) = tmp5 - mod(ntmp5,2)*halfperd
            this%Pts1(6,i) = this%Pts1(6,i0)

            tmp5 = -this%Pts1(5,i)/(gam*betai*xl)

            tmpx = this%Pts1(1,i0)*xl
!            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
!                             *this%Pts1(5,i0)*rcpgammai)*xl
            this%Pts1(1,i) = (this%Pts1(1,i0)-this%Pts1(2,i0) &
                             *tmp5*rcpgammai)*xl

            this%Pts1(2,i) = this%Pts1(2,i0)
            tmpy = this%Pts1(3,i0)*xl
!            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
!                             *this%Pts1(5,i0)*rcpgammai)*xl
            this%Pts1(3,i) = (this%Pts1(3,i0)-this%Pts1(4,i0) &
                             *tmp5*rcpgammai)*xl

            if(tmpx.le.(-xrad)) then
              ilost = ilost + 1
            else if(tmpx.ge.xrad) then
              ilost = ilost + 1
            else if(tmpy.le.(-yrad)) then
              ilost = ilost + 1
            else if(tmpy.gt.yrad) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).le.(-xrad)) then
              ilost = ilost + 1
            else if(this%Pts1(1,i).ge.xrad) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).le.(-yrad)) then
              ilost = ilost + 1
            else if(this%Pts1(3,i).ge.yrad) then
              ilost = ilost + 1
            else
            endif
            this%Pts1(7,i) = this%Pts1(7,i0)
            this%Pts1(8,i) = this%Pts1(8,i0)
            this%Pts1(9,i) = this%Pts1(9,i0)
          enddo
        else
          print*,"no such boundary condition!!!"
          stop
        endif

        this%Nptlocal = this%Nptlocal - ilost
        nplc = this%Nptlocal
        call MPI_ALLREDUCE(nplc,nptot,1,MPI_INTEGER,&
                           MPI_SUM,MPI_COMM_WORLD,ierr)

        this%Current = this%Current*nptot/this%Npt
        this%Npt = nptot

        end subroutine conv1st_BeamBunch

        subroutine cvbkforth1st_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer :: i
        double precision :: gamma0,xk,xl
        double precision :: rcpgammai,betai,beta

        xl = Scxl
        xk = 1/xl

        gamma0 = -this%refptcl(6)
        beta = sqrt(gamma0*gamma0 - 1.0)/gamma0

        do i = 1, this%Nptlocal
          rcpgammai = 1.0/(-this%Pts1(6,i)+gamma0)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i)**2+ &
                                            this%Pts1(4,i)**2) )
          this%Pts1(5,i) = this%Pts1(5,i)*xk/(-gamma0*betai)
          this%Pts1(1,i) = this%Pts1(1,i)*xk+this%Pts1(2,i) &
                            *this%Pts1(5,i)*rcpgammai
          this%Pts1(3,i) = this%Pts1(3,i)*xk+this%Pts1(4,i) &
                            *this%Pts1(5,i)*rcpgammai
        enddo

        do i = 1, this%Nptlocal
          rcpgammai = 1.0/(-this%Pts1(6,i)+gamma0)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i)**2+ &
                       this%Pts1(4,i)**2) ) 
          this%Pts1(1,i) = this%Pts1(1,i)*xl
          this%Pts1(3,i) = this%Pts1(3,i)*xl
          this%Pts1(5,i) = -gamma0*betai*this%Pts1(5,i)*xl
        enddo

        end subroutine cvbkforth1st_BeamBunch

        ! Here, all indices of potential are local to processor.
        ! Advance the particles in the velocity space using the force
        ! from the external field and the self space charge force
        ! interpolated from the grid to particles. (linear map)
        !biaobin, space charge kick is here
        subroutine kick1_BeamBunch(this,tau,innx,inny,innz,temppotent,&
                              ptsgeom,grid,Flagbc,perdlen,Flagsc,&
                              scout,scfile)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: innx, inny, innz, Flagbc, Flagsc, &
                               scout,scfile
        type (CompDom), intent(in) :: ptsgeom
        double precision, dimension(innx,inny,innz), intent(inout) :: temppotent
        type (Pgrid2d), intent(in) :: grid
        double precision, intent(in) :: tau,perdlen
        double precision, dimension(innx,inny,innz) :: egx,egy,egz
        double precision, dimension(3) :: msize
        double precision :: hxi, hyi, hzi,gam,curr,mass
        double precision :: t0,chrg
        integer :: totnp,nproccol,nprocrow,myid,myidx,myidy
        integer :: i, j, k, yadd, zadd, innp,ierr
        character(len=20) :: filename,formatstr
!        integer :: comm2d,commcol,commrow
!        double precision :: sumex,sumey,sumez,sumextot,sumeytot,sumeztot,&
!                            sumpot,sumpotot
!        integer :: jj,jdisp

        call starttime_Timer(t0)

        !if(this%Current.lt.1.0e-20) goto 1000
        !Flagsc=0, space charge is OFF
        if(Flagsc.eq.0 .OR. this%Current.lt.1.0e-20) goto 1000

        call getsize_Pgrid2d(grid,totnp,nproccol,nprocrow)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        if(nproccol.gt.1) then
          yadd = 1
        else
          yadd = 0
        endif
        if(nprocrow.gt.1) then
          zadd = 1
        else
          zadd = 0
        endif

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"before guardexch:"
        !endif
        
!        if(myidy.eq.0) then
!          jdisp = 0
!        else
!          jdisp = 33
!        endif
!        do k = 1+zadd, innz-zadd
!          do j = 1+yadd, inny-yadd
!            do i = 1, innx
!              jj = j -yadd + jdisp
!              temppotent(i,j,k) = i+jj+(k-zadd)*jj/100.0
!            enddo
!          enddo
!        enddo

        ! Exchange potential information on guard grid cells.
        if((Flagbc.eq.1).or.(Flagbc.eq.5) ) then  
          ! Transverse open or finite with longitudinal opend
!          if(totnp.ne.1) then
            call guardexch1_Fldmger(temppotent,innx,inny,innz,grid)
!          endif
        else
          print*,"no such boundary conditions!!!"
          stop
        endif

! cache optimization here.
        !print*,"yadd: ",yadd,zadd,innx,inny,innz,1.0/hxi,1.0/hyi,1.0/hzi
        !Ex
        !egx = 0.0
        do k = zadd+1, innz-zadd
          do j = yadd+1, inny-yadd
            egx(1,j,k) = hxi*(temppotent(1,j,k)-temppotent(2,j,k))
            do i = 2, innx-1
              egx(i,j,k) = 0.5*hxi*(temppotent(i-1,j,k)- &
                           temppotent(i+1,j,k))
            enddo
            egx(innx,j,k) = hxi*(temppotent(innx-1,j,k)- &
                                 temppotent(innx,j,k))
          enddo
        enddo

        !print*,"pass Ex:",myidx,myidy,yadd,zadd
        !Ey
        !egy = 0.0
        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then !periodic in theta, E_{theta}

        if(nproccol.gt.1) then
          do k = 1+zadd, innz-zadd
            do j = 1+yadd, inny-yadd
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi
            enddo
          enddo

        else

          do k = 1+zadd, innz-zadd
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi
            enddo
          enddo

          do k = 1+zadd, innz-zadd
            do i = 2, innx
              egy(i,1,k) = 0.5*hyi*(temppotent(i,inny-1,k) -  &
                           temppotent(i,2,k))*hxi/(i-1)
              egy(i,inny,k) = egy(i,1,k)
            enddo
            !egy(1,1,k) = 0.5*hyi*(temppotent(1,inny-1,k) -  &
            !               temppotent(1,2,k))*hxi
            egy(1,1,k) = 0.0
            egy(1,inny,k) = egy(1,1,k)
          enddo
        endif

        else  ! open in Y

        if(nproccol.gt.1) then 
          if(myidy.eq.0) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,yadd+1,k) = hyi*(temppotent(i,yadd+1,k)- &
                                       temppotent(i,yadd+2,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+2, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else if(myidy.eq.(nproccol-1)) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,inny-yadd,k) = hyi*(temppotent(i,inny-yadd-1,k)- &
                                          temppotent(i,inny-yadd,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd-1
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          endif
        else
          do k = zadd+1, innz-zadd
            do i = 1, innx
              egy(i,1,k) = hyi*(temppotent(i,1,k)-temppotent(i,2,k))
            enddo
            do j = 2, inny-1
              do i = 1, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                             temppotent(i,j+1,k))
              enddo
            enddo
            do i = 1, innx
              egy(i,inny,k) = hyi*(temppotent(i,inny-1,k)- &
                                   temppotent(i,inny,k))
            enddo
          enddo
        endif

        endif

!        print*,"pass Ey:",myidx,myidy,inny,innx,innz

        !Ez
        !egz = 0.0
        if(nprocrow.gt.1) then 
          ! 3D open,or z open
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then 
            if(myidx.eq.0) then
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,zadd+1) = hzi*(temppotent(i,j,zadd+1)- &
                                         temppotent(i,j,zadd+2))
                enddo
              enddo
              do k = zadd+2, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            else if(myidx.eq.(nprocrow-1)) then
              do k = zadd+1, innz-zadd-1
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,innz-zadd) = hzi*(temppotent(i,j,innz-zadd-1)- &
                                            temppotent(i,j,innz-zadd))
                enddo
              enddo
            else
              do k = zadd+1, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            endif
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                               temppotent(i,j,k+1))
                enddo
              enddo
            enddo
          else
            print*,"no such boundary condition!!!"
            stop
          endif
        else
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1) = hzi*(temppotent(i,j,1)-temppotent(i,j,2))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1)=0.5*hzi*(temppotent(i,j,innz-1)-temppotent(i,j,2))
              enddo
            enddo
          else
          endif
          do k = 2, innz-1
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                      temppotent(i,j,k+1))
              enddo
            enddo
          enddo
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,innz))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = 0.5*hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,2))
              enddo
            enddo
          else
          endif
        endif

        !biaobin,2022-03, output space charge field
        !ez_j.sc, ez along z in different x
        !ex_j.sc, ex along x in different z
        if(myid.eq.0) then
          if(scout.eq.1) then
            if(scfile<10) then
              formatstr="(A3,I1,A3)"
            elseif(scfile<100) then
              formatstr="(A3,I2,A3)"
            else
              print*,"ERROR: scfile should be [0,100)."
              stop
            endif

            write(filename,formatstr)"ez_",scfile,".sc" 
            open(2,file=filename)
            do k=1,innz
                write(2,105)egz(innx/2,inny/2,k),&
                egz(innx*3/4,inny/2,k),egz(innx,inny/2,k)
            enddo
            close(2)
            105 format(3(2x,e13.7))

            write(filename,formatstr)"ex_",scfile,".sc" 
            open(2,file=filename)
            do i=1,innx
                write(2,106)egx(i,inny/2,1),egx(i,inny/2,innz/4),&
                egx(i,inny/2,innz/2),egx(i,inny/2,innz*3/4), &
                egx(i,inny/2,innz)
            enddo
            close(2)
            106 format(5(2x,e13.7))
          endif
        endif

        !Send the E field to the neibhoring guard grid to do the CIC
        !interpolation.
!        if(totnp.ne.1) then
          call boundint4_Fldmger(egx,egy,egz,innx,inny,innz,grid)
!        endif

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"before scatter:"
        !endif

        gam = -this%refptcl(6)
        curr = this%Current
        mass = this%Mass
        innp = this%Nptlocal
        chrg = this%Charge
        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then
        else
          call scatter1_BeamBunch(innp,innx,inny,innz,this%Pts1,egx,egy,egz,&
          ptsgeom,nprocrow,nproccol,myidx,myidy,gam,curr,tau,mass,chrg,Flagsc)
        endif

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"after scatter:"
        !endif

1000    continue

        t_force = t_force + elapsedtime_Timer(t0)

        end subroutine kick1_BeamBunch

        ! scatter grid quantity onto particles using linear map.
        subroutine scatter1_BeamBunch(innp,innx,inny,innz,rays,exg,&
                   eyg,ezg,ptsgeom,npx,npy,myidx,myidy,gam,curr,tau,mass,chrg,Flagsc)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (in), dimension (innx,inny,innz) :: exg,eyg,ezg 
        double precision, intent (in) :: gam,curr,tau,mass,chrg
        integer, intent(in) :: innp,innx,inny,innz,npx,npy,myidx,myidy,&
                               Flagsc
        integer, dimension(2,0:npx-1,0:npy-1) :: table
        integer, dimension(0:npx-1) :: xtable
        integer, dimension(0:npy-1) :: ytable
        double precision :: ab, cd, ef
        integer :: n,i
        double precision :: t0
        double precision :: hx,hxi,hy,hyi,hz,hzi,xmin,ymin,zmin
        double precision, dimension(3) :: msize
        double precision, dimension(6) :: range
        type (CompDom) :: ptsgeom
        integer :: ix,jx,kx,ix1,jx1,kx1,ierr,kadd,jadd
        double precision :: sumx,sumy,sumz,totsumx,totsumy,totsumz
        double precision :: twopi,fpei,xk,bet,bbyk,gambet,brho,vz0,&
            perv0,xycon,tcon,rcpgammai,exn,eyn,ezn,betai,tmpsq
        double precision :: tmpscale

        call starttime_Timer( t0 )

        !tmpscale = curr*chrg/Scfreq
        tmpscale = curr/Scfreq

        twopi = 2.0*Pi
        fpei = Clight*Clight*1.0e-7
        xk = 1/Scxl

        bet = sqrt(gam**2-1.0)/gam
        bbyk = bet/xk
        gambet = gam*bet
        brho = gambet/(Clight*chrg)*mass
        vz0 = bet*Clight
        perv0 = 2.0*curr*fpei/(brho*vz0*vz0*gam*gam)
!        xycon = 0.5*perv0*gambet*bbyk*twopi
!        tcon = bet*xycon*gam**2
! the curr*charge/freq has been included in the charge density
        xycon = 0.5*perv0*gambet*bbyk*twopi/tmpscale
        tcon = bet*xycon*gam**2

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)
        hx = msize(1)
        hy = msize(2)
        hz = msize(3)

        call getrange_CompDom(ptsgeom,range)
        xmin = range(1)
        ymin = range(3)
        zmin = range(5)

        call getlctabnm_CompDom(ptsgeom,table)
        xtable(0) = 0
        do i = 1, npx - 1
          xtable(i) = xtable(i-1) + table(1,i-1,0)
        enddo

        ytable(0) = 0
        do i = 1, npy - 1
          ytable(i) = ytable(i-1) + table(2,0,i-1)
        enddo

        if(npx.gt.1) then
          kadd = -xtable(myidx) + 1
        else
          kadd = 0
        endif
        if(npy.gt.1) then
          jadd = -ytable(myidy) + 1
        else
          jadd = 0
        endif

        do n = 1, innp
          ix=(rays(1,n)-xmin)*hxi + 1
          ab=((xmin-rays(1,n))+ix*hx)*hxi
          jx=(rays(3,n)-ymin)*hyi + 1 + jadd
          cd=((ymin-rays(3,n))+(jx-jadd)*hy)*hyi
          kx=(rays(5,n)-zmin)*hzi + 1 + kadd
          ef=((zmin-rays(5,n))+(kx-kadd)*hz)*hzi

          ix1 = ix + 1
          jx1 = jx + 1
          kx1 = kx + 1

          exn = (exg(ix,jx,kx)*ab*cd*ef  &
                  +exg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +exg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +exg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +exg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +exg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +exg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +exg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          eyn = (eyg(ix,jx,kx)*ab*cd*ef  &
                  +eyg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +eyg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +eyg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +eyg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +eyg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +eyg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +eyg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          ezn = ezg(ix,jx,kx)*ab*cd*ef  &
                  +ezg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +ezg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +ezg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +ezg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +ezg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +ezg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +ezg(ix1,jx,kx)*(1.0-ab)*cd*ef

          !Biaobin Li, 2021-03-04
          !space charge kick behavior control:
          !Flagsc=0, SC OFF
          !Flagsc=1, LSC
          !Flagsc=2, TSC
          !Flagsc=3, LSC + TSC
          !print*,"Biaobin, Flagsc=",Flagsc
          if (Flagsc.eq.1) then 
              !print*,"TSC is turned OFF, only LSC is ON."
              exn = 0.0d0
              eyn = 0.0d0
          else if (Flagsc.eq.2) then
              !print*,"LSC is turned OFF, only TSC is ON."
              ezn = 0.0d0
          else if (Flagsc.eq.3) then
              !print*,"Both LSC and TSC are turned ON."
          else if (Flagsc.eq.4) then
              !print*,"SC is OFF, however, wake and csr could be ON."
          else
              print*,"ERROR, wrong Flagsc is given, Flagsc=", Flagsc
              stop
          end if

          !0th order algorithm to transfer back from t beam frame to z.
          rcpgammai = 1.0/(-rays(6,n)+gam)

          tmpsq = 1.0-rcpgammai*rcpgammai*(1+rays(2,n)**2+ &
                                                rays(4,n)**2) 
          !if(tmpsq.lt.0.0) then
          !  print*,"tmpsq: ",tmpsq,rcpgammai,rays(2,n),rays(4,n),myidx,myidy
          !  stop
          !else
            betai = sqrt(tmpsq)
          !endif
          rays(1,n) = rays(1,n)*xk
          rays(2,n) = rays(2,n)+tau*xycon*exn
          rays(3,n) = rays(3,n)*xk
          rays(4,n) = rays(4,n)+tau*xycon*eyn
          rays(5,n) = rays(5,n)*xk/(-gam*betai)
          rays(6,n) = rays(6,n)-tau*tcon*ezn
        enddo

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatter1_BeamBunch

        ! Here, all indices of potential are local to processor.
        ! Advance the particles in the velocity space using the force
        ! from the external field and the self space charge force
        ! interpolated from the grid to particles. (Lorentz force)
        subroutine kick2_BeamBunch(this,beamelem,z,tau,innx,inny,innz, &
                             temppotent,ptsgeom,grid,Flagbc,flagerr)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(in) :: beamelem
        integer, intent(in) :: innx, inny, innz, Flagbc,flagerr
        type (CompDom), intent(in) :: ptsgeom
        double precision,dimension(innx,inny,innz),intent(inout) :: temppotent
        type (Pgrid2d), intent(in) :: grid
        double precision, intent(in) :: z, tau
        double precision, dimension(innx,inny,innz) :: egx,egy,egz
        double precision, dimension(3) :: msize
        double precision :: hxi, hyi, hzi
        double precision :: t0,tg,chge,mass,curr,gam
        integer :: totnp,nproccol,nprocrow,myid,myidx,myidy
        integer :: i, j, k, yadd, zadd, innp
!        integer :: comm2d,commcol,commrow

        call starttime_Timer(t0)

        call getsize_Pgrid2d(grid,totnp,nproccol,nprocrow)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        if(nproccol.gt.1) then
          yadd = 1
        else
          yadd = 0
        endif
        if(nprocrow.gt.1) then
          zadd = 1
        else
          zadd = 0
        endif

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"before guardexch:"
        !endif

        curr = this%Current
        innp = this%Nptlocal
        tg = this%refptcl(5)
        gam = -this%refptcl(6)
        mass = this%Mass
        chge = this%Charge

        if(curr.gt.0.0) then
!------------------------------------------------------------------
! current greater than 0
    
        ! Exchange potential information on guard grid cells.
        if((Flagbc.eq.1).or.(Flagbc.eq.5)) then ! 3D open 
          if(totnp.ne.1) then
            call guardexch1_Fldmger(temppotent,innx,inny,innz,grid)
          endif
        else
          print*,"no such boundary condition!!!!"
          stop
        endif

! cache optimization here.
        !print*,"yadd: ",yadd,zadd,innx,inny,innz,1.0/hxi,1.0/hyi,1.0/hzi
        !Ex
        !egx = 0.0
        do k = zadd+1, innz-zadd
          do j = yadd+1, inny-yadd
            egx(1,j,k) = hxi*(temppotent(1,j,k)-temppotent(2,j,k))
            do i = 2, innx-1
              egx(i,j,k) = 0.5*hxi*(temppotent(i-1,j,k)- &
                           temppotent(i+1,j,k))
            enddo
            egx(innx,j,k) = hxi*(temppotent(innx-1,j,k)- &
                                 temppotent(innx,j,k))
          enddo
        enddo

        !Ey
        !egy = 0.0
        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then  ! periodic in theta

        if(nproccol.gt.1) then
          do k = 1, innz
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi

            enddo
          enddo
        else
          do k = 1, innz
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi
            enddo
          enddo
          do k = 1, innz
            do i = 2, innx
              egy(i,1,k) = 0.5*hyi*(temppotent(i,inny-1,k) -  &
                           temppotent(i,2,k))*hxi/(i-1)
              egy(i,inny,k) = egy(i,1,k)
            enddo
            egy(1,1,k) = 0.0
            !egy(1,1,k) = 0.5*hyi*(temppotent(1,inny-1,k) -  &
            !               temppotent(1,2,k))*hxi
            egy(1,inny,k) = 0.0
            !egy(1,inny,k) = egy(1,1,k)
          enddo
        endif

        else  ! open in Y

        if(nproccol.gt.1) then 
          if(myidy.eq.0) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,yadd+1,k) = hyi*(temppotent(i,yadd+1,k)- &
                                       temppotent(i,yadd+2,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+2, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else if(myidy.eq.(nproccol-1)) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,inny-yadd,k) = hyi*(temppotent(i,inny-yadd-1,k)- &
                                          temppotent(i,inny-yadd,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd-1
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          endif
        else
          do k = zadd+1, innz-zadd
            do i = 1, innx
              egy(i,1,k) = hyi*(temppotent(i,1,k)-temppotent(i,2,k))
            enddo
            do j = 2, inny-1
              do i = 1, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                             temppotent(i,j+1,k))
              enddo
            enddo
            do i = 1, innx
              egy(i,inny,k) = hyi*(temppotent(i,inny-1,k)- &
                                   temppotent(i,inny,k))
            enddo
          enddo
        endif

        endif

        !Ez
        !egz = 0.0
        if(nprocrow.gt.1) then 
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            if(myidx.eq.0) then
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,zadd+1) = hzi*(temppotent(i,j,zadd+1)- &
                                         temppotent(i,j,zadd+2))
                enddo
              enddo
              do k = zadd+2, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            else if(myidx.eq.(nprocrow-1)) then
              do k = zadd+1, innz-zadd-1
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,innz-zadd) = hzi*(temppotent(i,j,innz-zadd-1)- &
                                            temppotent(i,j,innz-zadd))
                enddo
              enddo
            else
              do k = zadd+1, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            endif
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                               temppotent(i,j,k+1))
                enddo
              enddo
            enddo
          else
            print*,"no such boundary condition!!!"
            stop
          endif
        else
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1) = hzi*(temppotent(i,j,1)-temppotent(i,j,2))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1)=0.5*hzi*(temppotent(i,j,innz-1)-temppotent(i,j,2))
              enddo
            enddo
          else
          endif
          do k = 2, innz-1
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                      temppotent(i,j,k+1))
              enddo
            enddo
          enddo
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,innz))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = 0.5*hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,2))
              enddo
            enddo
          else
          endif
        endif

        !Send the E field to the neibhoring guard grid to do the CIC
        !interpolation.
        if(totnp.ne.1) then
          call boundint4_Fldmger(egx,egy,egz,innx,inny,innz,grid)
        endif

        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then ! round pipe
        else
            call scatter2_BeamBunch(innp,innx,inny,innz,this%Pts1,egx,egy,egz,&
            ptsgeom,nprocrow,nproccol,myidx,myidy,tg,gam,curr,chge,mass,tau,z,&
            beamelem)
        endif

        else
!------------------------------------------------------------------
! current is 0
          if(flagerr.eq.1) then
            call scatter20_BeamBunch(innp,this%Pts1,tg,gam,chge,mass,tau,z,&
                                     beamelem)
          else
            call scatter20_BeamBunch(innp,this%Pts1,tg,gam,chge,mass,tau,z,&
                                     beamelem)
          endif
        endif

        this%refptcl(6) = -gam

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.0) then
        !  print*,"after kick:"
        !endif

        t_force = t_force + elapsedtime_Timer(t0)

        end subroutine kick2_BeamBunch

        subroutine scatter2_BeamBunch(innp,innx,inny,innz,rays,exg,&
        eyg,ezg,ptsgeom,npx,npy,myidx,myidy,tg,gam,curr,chge,mass,tau,z,&
        beamelem)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (in), dimension (innx,inny,innz) :: exg,eyg,ezg 
        double precision, intent (in) :: curr,tau,mass,chge,tg,z
        double precision, intent (inout) :: gam
        integer, intent(in) :: innp,innx,inny,innz,npx,npy,myidx,myidy
        type (BeamLineElem), intent(in) :: beamelem
        integer, dimension(2,0:npx-1,0:npy-1) :: table
        integer, dimension(0:npx-1) :: xtable
        integer, dimension(0:npy-1) :: ytable
        double precision :: ab, cd, ef
        integer :: n,i,ii
        double precision :: t0
        double precision :: hx,hxi,hy,hyi,hz,hzi,xmin,ymin,zmin
        double precision, dimension(3) :: msize
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: range, extfld
        type (CompDom) :: ptsgeom
        integer :: ix,jx,kx,ix1,jx1,kx1,ierr,kadd,jadd
        double precision :: twopi,xk,xl,bfreq,tmpscale,tmpgamma0,tmpgamma00,&
        beta0,qmcc,rcpgammai,betai,ez0,tmp1,tmp2,tmp3,tmp4,tmp5,tmp12,tmp23,&
        tmp13,pz,p1,p2,p3,a12,a13,a23,b1,b2,b3,s11,s12,s13,s21,s22,s23,&
        s31,s32,s33,det,tmpsq2,exn,eyn,ezn,ex,ey,ez,bx,by,bz
        double precision, dimension(6,NrIntvRf+1) :: extfld6
        double precision :: rr,hr,hri,mu0,te,tb,escale,rffreq,theta0,efr,&
                            er,btheta,ww,et,bt
        integer :: ir,ir1,FlagCart,FlagDisc
        !3D Cartesian coordinate.
        double precision,dimension(6,NxIntvRfg+1,NyIntvRfg+1)::extfld6xyz
        double precision :: xx,yy,hxx,hyy,hxxi,hyyi,efx,efy
        integer :: iy,iy1
        double precision, dimension(4,innp) :: postmp
        double precision, dimension(6,innp) :: extfldtmp
        real*8, dimension(6) :: tmprays

        call starttime_Timer( t0 )

        twopi = 2.0*Pi
        xk = 1/Scxl
        xl = Scxl
        bfreq = Scfreq
        !tmpscale = Clight*Clight*1.0e-7*curr/bfreq*chge
        tmpscale = Clight*Clight*1.0e-7 !curr*chge/bfreq are included in the charge density
        beta0 = sqrt(gam**2-1.0)/gam
        qmcc = chge/mass

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)
        hx = msize(1)
        hy = msize(2)
        hz = msize(3)

        call getrange_CompDom(ptsgeom,range)
        xmin = range(1)
        ymin = range(3)
        zmin = range(5)

        call getlctabnm_CompDom(ptsgeom,table)
        xtable(0) = 0
        do i = 1, npx - 1
          xtable(i) = xtable(i-1) + table(1,i-1,0)
        enddo

        ytable(0) = 0
        do i = 1, npy - 1
          ytable(i) = ytable(i-1) + table(2,0,i-1)
        enddo

        if(npx.gt.1) then
          kadd = -xtable(myidx) + 1
        else
          kadd = 0
        endif
        if(npy.gt.1) then
          jadd = -ytable(myidy) + 1
        else
          jadd = 0
        endif

        FlagDisc = 0
        FlagCart = 1
        if(associated(beamelem%pemfld)) then
          escale=beamelem%pemfld%Param(2)
          rffreq=beamelem%pemfld%Param(3)
          ww = rffreq/Scfreq
          theta0=beamelem%pemfld%Param(4)*asin(1.0)/90
          FlagDisc = 0.1+beamelem%pemfld%Param(13)
          FlagCart = 0.1+beamelem%pemfld%Param(14)

          if(FlagDisc.eq.1) then
            if(FlagCart.eq.1) then
              call getfld6_EMfld(beamelem%pemfld,z,extfld6)
              et = escale*cos(ww*tg+theta0)
              ez0 = extfld6(3,1)*et
              hr = (RmaxRf-RminRf)/NrIntvRf
              hri = 1.0/hr
            else if(FlagCart.eq.2) then
              call getfld6xyz_EMfld(beamelem%pemfld,z,extfld6xyz)
              hxx = (XmaxRfg-XminRfg)/NxIntvRfg
              hyy = (YmaxRfg-YminRfg)/NyIntvRfg
              hxxi = 1.0/hxx
              hyyi = 1.0/hyy
              xx = 0.0
              yy = 0.0
              ix = (xx-XminRfg)/hxx + 1
              ix1 = ix+1
              efx = (XminRfg-xx+ix*hxx)/hxx
              iy = (yy-YminRfg)/hyy + 1
              iy1 = iy+1
              efy = (YminRfg-yy+iy*hyy)/hyy
              ezn = extfld6xyz(3,ix,iy)*efx*efy + &
                    extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                    extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                    extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy)
              et = escale*cos(ww*tg+theta0)
              ez0 = ezn*et
            endif
          else if(FlagDisc.eq.2) then
            pos(1) = 0.0
            pos(2) = 0.0
            pos(3) = z
            pos(4) = tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
            ez0 = extfld(3)
            if(FlagCart.eq.1) then
              call getfld6_EMfld(beamelem%pemfld,z,extfld6)
              et = escale*cos(ww*tg+theta0)
              ez0 = ez0 + extfld6(3,1)*et
              hr = (RmaxRf-RminRf)/NrIntvRf
              hri = 1.0/hr
            else if(FlagCart.eq.2) then
              call getfld6xyz_EMfld(beamelem%pemfld,z,extfld6xyz)
              hxx = (XmaxRfg-XminRfg)/NxIntvRfg
              hyy = (YmaxRfg-YminRfg)/NyIntvRfg
              hxxi = 1.0/hxx
              hyyi = 1.0/hyy
              xx = 0.0
              yy = 0.0
              ix = (xx-XminRfg)/hxx + 1
              ix1 = ix+1
              efx = (XminRfg-xx+ix*hxx)/hxx
              iy = (yy-YminRfg)/hyy + 1
              iy1 = iy+1
              efy = (YminRfg-yy+iy*hyy)/hyy
              ezn = extfld6xyz(3,ix,iy)*efx*efy + &
                    extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                    extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                    extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy)
              et = escale*cos(ww*tg+theta0)
              ez0 = ez0 + ezn*et
            endif
          else
            pos(1) = 0.0
            pos(2) = 0.0
            pos(3) = z
            pos(4) = tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
            ez0 = extfld(3)
          endif
        else
          pos(1) = 0.0
          pos(2) = 0.0
          pos(3) = z
          pos(4) = tg
          call getfld_BeamLineElem(beamelem,pos,extfld)
          ez0 = extfld(3)
        endif

        tmpgamma0 = gam + 0.5*tau*qmcc*ez0

        if(associated(beamelem%pdtl)) then
          !  print*,"into dtl"
          do n=1,innp
            !Linear algorithm to transfer back from t to z.
            rcpgammai = 1.0/(-rays(6,n)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+rays(2,n)**2+ &
                                                rays(4,n)**2) )
            tmprays(5) = rays(5,n)*xk/(-gam*betai)
            tmprays(1) = rays(1,n)*xk
            tmprays(3) = rays(3,n)*xk
            postmp(1,n) = tmprays(1)*xl
            postmp(2,n) = tmprays(3)*xl
            postmp(3,n) = z
            postmp(4,n) = tmprays(5) + tg
          enddo
          call getfldpts_DTL(postmp,extfldtmp,beamelem%pdtl,innp)
        else if(associated(beamelem%pccl)) then
          do n=1,innp
            !Linear algorithm to transfer back from t to z.
            rcpgammai = 1.0/(-rays(6,n)+gam)
            betai = sqrt(1.0-rcpgammai*rcpgammai*(1+rays(2,n)**2+ &
                                                rays(4,n)**2) )
            tmprays(5) = rays(5,n)*xk/(-gam*betai) 
            tmprays(1) = rays(1,n)*xk 
            tmprays(3) = rays(3,n)*xk 
            postmp(1,n) = tmprays(1)*xl 
            postmp(2,n) = tmprays(3)*xl 
            postmp(3,n) = z
            postmp(4,n) = tmprays(5) + tg 
          enddo
          call getfldpts_CCL(postmp,extfldtmp,beamelem%pccl,innp)
        endif

        do n = 1, innp
          ix=(rays(1,n)-xmin)*hxi + 1
          ab=((xmin-rays(1,n))+ix*hx)*hxi
          jx=(rays(3,n)-ymin)*hyi + 1 + jadd
          cd=((ymin-rays(3,n))+(jx-jadd)*hy)*hyi
          kx=(rays(5,n)-zmin)*hzi + 1 + kadd
          ef=((zmin-rays(5,n))+(kx-kadd)*hz)*hzi

          ix1 = ix + 1
          jx1 = jx + 1
          kx1 = kx + 1

          exn = (exg(ix,jx,kx)*ab*cd*ef  &
                  +exg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +exg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +exg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +exg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +exg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +exg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +exg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          eyn = (eyg(ix,jx,kx)*ab*cd*ef  &
                  +eyg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +eyg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +eyg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +eyg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +eyg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +eyg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +eyg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          ezn = ezg(ix,jx,kx)*ab*cd*ef  &
                  +ezg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +ezg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +ezg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +ezg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +ezg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +ezg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +ezg(ix1,jx,kx)*(1.0-ab)*cd*ef

          !Linear algorithm to transfer back from t to z.
          rcpgammai = 1.0/(-rays(6,n)+gam)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+rays(2,n)**2+ &
                                                rays(4,n)**2) )
          rays(5,n) = rays(5,n)*xk/(-gam*betai)
          rays(1,n) = rays(1,n)*xk
          rays(3,n) = rays(3,n)*xk

          if(FlagDisc.eq.1) then !use discrete data only
              !calculate field in Cartesian coordinate from the discrete
              !field function (r) in cylindrical coordinate
              et = escale*cos(ww*(tg+rays(5,n))+theta0)
              bt = escale*sin(ww*(tg+rays(5,n))+theta0)
              if(FlagCart.eq.1) then
                rr = sqrt(rays(1,n)*rays(1,n)+rays(3,n)*rays(3,n))*xl
                ir = rr*hri + 1
                if(ir.eq.NrIntvRf) ir=ir-1
                ir1 = ir+1
                efr = (ir*hr - rr)*hri
                er = (extfld6(1,ir)*efr+extfld6(1,ir1)*(1.0-efr))*et
                extfld(1) = er*rays(1,n)*xl/rr
                extfld(2) = er*rays(3,n)*xl/rr
                extfld(3) = (extfld6(3,ir)*efr+extfld6(3,ir1)*(1.0-efr))*et
                btheta = (extfld6(5,ir)*efr+extfld6(5,ir1)*(1.0-efr))*bt
                extfld(4) = -btheta*rays(3,n)*xl/rr
                extfld(5) = btheta*rays(1,n)*xl/rr
                extfld(6) = 0.0
              else if(FlagCart.eq.2) then
                xx = rays(1,n)*xl
                yy = rays(3,n)*xl
                ix = (xx-XminRfg)*hxxi + 1
                ix1 = ix+1
                efx = (XminRfg-xx+ix*hxx)*hxxi
                iy = (yy-YminRfg)*hyyi + 1
                iy1 = iy+1
                efy = (YminRfg-yy+iy*hyy)*hyyi
                extfld(1) = (extfld6xyz(1,ix,iy)*efx*efy + &
                      extfld6xyz(1,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(1,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(1,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(2) = (extfld6xyz(2,ix,iy)*efx*efy + &
                      extfld6xyz(2,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(2,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(2,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(3) = (extfld6xyz(3,ix,iy)*efx*efy + &
                      extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(4) = (extfld6xyz(4,ix,iy)*efx*efy + &
                      extfld6xyz(4,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(4,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(4,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(5) = (extfld6xyz(5,ix,iy)*efx*efy + &
                      extfld6xyz(5,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(5,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(5,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(6) = (extfld6xyz(6,ix,iy)*efx*efy + &
                      extfld6xyz(6,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(6,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(6,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
              endif
          !use both analytical function and discrete data.
          else if(FlagDisc.eq.2) then
              pos(1) = rays(1,n)*xl
              pos(2) = rays(3,n)*xl
              pos(3) = z
              pos(4) = rays(5,n) + tg
              !get field in Cartesian coordinate from analytical function.
              call getfld_BeamLineElem(beamelem,pos,extfld)
              !calculate field in Cartesian coordinate from the discrete
              !field function (r) in cylindrical coordinate
              et = escale*cos(ww*(tg+rays(5,n))+theta0)
              bt = escale*sin(ww*(tg+rays(5,n))+theta0)
              if(FlagCart.eq.1) then
                rr = sqrt(rays(1,n)*rays(1,n)+rays(3,n)*rays(3,n))*xl
                ir = rr*hri + 1
                if(ir.eq.NrIntvRf) ir=ir-1
                ir1 = ir+1
                efr = (ir*hr - rr)*hri
                er = (extfld6(1,ir)*efr+extfld6(1,ir1)*(1.0-efr))*et
                extfld(1) = extfld(1) + er*rays(1,n)*xl/rr
                extfld(2) = extfld(2) + er*rays(3,n)*xl/rr
                extfld(3) = extfld(3) + &
                            (extfld6(3,ir)*efr+extfld6(3,ir1)*(1.0-efr))*et
                btheta = (extfld6(5,ir)*efr+extfld6(5,ir1)*(1.0-efr))*bt
                extfld(4) = extfld(4) - btheta*rays(3,n)*xl/rr
                extfld(5) = extfld(5) + btheta*rays(1,n)*xl/rr
!                extfld(6) = extfld(6)
              else if(FlagCart.eq.2) then
                xx = rays(1,n)*xl
                yy = rays(3,n)*xl
                ix = (xx-XminRfg)*hxxi + 1
                ix1 = ix+1
                efx = (XminRfg-xx+ix*hxx)*hxxi
                iy = (yy-YminRfg)*hyyi + 1
                iy1 = iy+1
                efy = (YminRfg-yy+iy*hyy)*hyyi
                extfld(1) = (extfld6xyz(1,ix,iy)*efx*efy + &
                      extfld6xyz(1,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(1,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(1,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(2) = (extfld6xyz(2,ix,iy)*efx*efy + &
                      extfld6xyz(2,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(2,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(2,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(3) = (extfld6xyz(3,ix,iy)*efx*efy + &
                      extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(4) = (extfld6xyz(4,ix,iy)*efx*efy + &
                      extfld6xyz(4,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(4,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(4,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(5) = (extfld6xyz(5,ix,iy)*efx*efy + &
                      extfld6xyz(5,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(5,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(5,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(6) = (extfld6xyz(6,ix,iy)*efx*efy + &
                      extfld6xyz(6,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(6,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(6,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
              endif
          else !use analytical function data only
            if(associated(beamelem%pdtl)) then
              extfld(:)=extfldtmp(:,n)
            else if(associated(beamelem%pccl)) then
              extfld(:)=extfldtmp(:,n)
            else
              !get field in Cartesian coordinate from analytical function.
              pos(1) = rays(1,n)*xl
              pos(2) = rays(3,n)*xl
              pos(3) = z
              pos(4) = rays(5,n) + tg
              call getfld_BeamLineElem(beamelem,pos,extfld)
            endif
          endif

          ex = tmpscale*exn+extfld(1)
          ey = tmpscale*eyn+extfld(2)
          ez = tmpscale*ezn+extfld(3)
          bx = -beta0/Clight*tmpscale*eyn+extfld(4)
          by = beta0/Clight*tmpscale*exn+extfld(5)
          bz = extfld(6)
          tmp12 = -tau*Clight*bz*rays(7,n)/2
          tmp13 = tau*ex*rays(7,n)/2
          tmp23 = tau*ey*rays(7,n)/2
          tmp1 = tmpgamma0*ex*tau*rays(7,n)
          tmp2 = Clight*by*tau*rays(7,n)
          tmp3 = tmpgamma0*ey*tau*rays(7,n)
          tmp4 = Clight*bx*tau*rays(7,n)
!          tmp5 = (ez0-ez)*tau*rays(7,n)
          !for multi-charge state, qmcc not equal to rays(7,n)
          tmp5 = (ez0*qmcc-ez*rays(7,n))*tau
          pz = sqrt((gam-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2)
          p1 = rays(2,n)
          p2 = rays(4,n)
          p3 = rays(6,n)
          do ii = 1, 2
            a12 = tmp12/pz
            a13 = tmp13/pz
            a23 = tmp23/pz
            b1 = p1-a12*p2-a13*p3+tmp1/pz - tmp2
            b2 = a12*p1+p2-a23*p3+tmp3/pz + tmp4
            b3 = -a13*p1-a23*p2+p3 + tmp5
            det = 1+a12*a12-a13*a13-a23*a23
            s11 = 1-a23*a23
            s12 = -a12+a13*a23
            s13 = a12*a23-a13
            s21 = a12+a13*a23
            s22 = 1-a13*a13
            s23 = -a23-a13*a12
            s31 = -a12*a23-a13
            s32 = -a23+a12*a13
            s33 = 1+a12*a12
            rays(2,n) = (s11*b1+s12*b2+s13*b3)/det
            rays(4,n) = (s21*b1+s22*b2+s23*b3)/det
            rays(6,n) = (s31*b1+s32*b2+s33*b3)/det
            tmpgamma00 = gam + tau*qmcc*ez0
            tmpsq2 = (tmpgamma00-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2
            if(tmpsq2.gt.0.0) then
              pz = 0.5*pz + 0.5*sqrt(tmpsq2)
            endif
          enddo
        enddo
        gam = gam + tau*qmcc*ez0

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatter2_BeamBunch

        ! scatter grid quantity onto particles.
        ! only external fields are included
        subroutine scatter20_BeamBunch(innp,rays,tg,gam,chge,mass,&
                                       tau,z,beamelem)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (in) :: tau,mass,chge,tg,z
        double precision, intent (inout) :: gam
        integer, intent(in) :: innp
        type (BeamLineElem), intent(in) :: beamelem
        integer :: n,i,ii
        double precision :: t0
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: extfld
        double precision :: twopi,xl,tmpgamma0,tmpgamma00,&
        beta0,qmcc,ez0,tmp1,tmp2,tmp3,tmp4,tmp5,tmp12,tmp23,&
        tmp13,pz,p1,p2,p3,a12,a13,a23,b1,b2,b3,s11,s12,s13,s21,s22,s23,&
        s31,s32,s33,det,tmpsq2,ex,ey,ez,bx,by,bz
        double precision, dimension(6,NrIntvRf+1) :: extfld6
        double precision :: rr,hr,hri,te,tb,escale,rffreq,theta0,efr,&
                            er,btheta,ww,et,bt
        integer :: ir,ir1,FlagCart,FlagDisc
        !3D Cartesian coordinate.
        double precision,dimension(6,NxIntvRfg+1,NyIntvRfg+1)::extfld6xyz
        double precision :: xx,yy,hxx,hyy,hxxi,hyyi,efx,efy,ezn
        integer :: iy,iy1,ix,ix1
        double precision, dimension(4,innp) :: postmp
        double precision, dimension(6,innp) :: extfldtmp

        call starttime_Timer( t0 )

        twopi = 2.0*Pi
        xl = Scxl
        beta0 = sqrt(gam**2-1.0)/gam
        qmcc = chge/mass

        FlagDisc = 0
        FlagCart = 1
        if(associated(beamelem%pemfld)) then
          escale=beamelem%pemfld%Param(2)
          rffreq=beamelem%pemfld%Param(3)
          ww = rffreq/Scfreq
          theta0=beamelem%pemfld%Param(4)*asin(1.0)/90
          FlagDisc = 0.1+beamelem%pemfld%Param(13)
          FlagCart = 0.1+beamelem%pemfld%Param(14)

          !print*,"FlagDisc, FlagCart: ",FlagDisc,FlagCart

          if(FlagDisc.eq.1) then
            if(FlagCart.eq.1) then
              call getfld6_EMfld(beamelem%pemfld,z,extfld6)
              et = escale*cos(ww*tg+theta0)
              ez0 = extfld6(3,1)*et
              hr = (RmaxRf-RminRf)/NrIntvRf
              hri = 1.0/hr
            else if(FlagCart.eq.2) then
              call getfld6xyz_EMfld(beamelem%pemfld,z,extfld6xyz)
              hxx = (XmaxRfg-XminRfg)/NxIntvRfg
              hyy = (YmaxRfg-YminRfg)/NyIntvRfg
              hxxi = 1.0/hxx
              hyyi = 1.0/hyy
              xx = 0.0
              yy = 0.0
              ix = (xx-XminRfg)/hxx + 1
              ix1 = ix+1
              efx = (XminRfg-xx+ix*hxx)/hxx
              iy = (yy-YminRfg)/hyy + 1
              iy1 = iy+1
              efy = (YminRfg-yy+iy*hyy)/hyy
              ezn = extfld6xyz(3,ix,iy)*efx*efy + &
                    extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                    extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                    extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy)
              et = escale*cos(ww*tg+theta0)
              ez0 = ezn*et
              !print*,"ezn: ",xx,yy,z,ezn
            endif
          else if(FlagDisc.eq.2) then
            pos(1) = 0.0
            pos(2) = 0.0
            pos(3) = z
            pos(4) = tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
            ez0 = extfld(3)
            if(FlagCart.eq.1) then
              call getfld6_EMfld(beamelem%pemfld,z,extfld6)
              et = escale*cos(ww*tg+theta0)
              ez0 = ez0 + extfld6(3,1)*et
              hr = (RmaxRf-RminRf)/NrIntvRf
              hri = 1.0/hr
            else if(FlagCart.eq.2) then
              call getfld6xyz_EMfld(beamelem%pemfld,z,extfld6xyz)
              hxx = (XmaxRfg-XminRfg)/NxIntvRfg
              hyy = (YmaxRfg-YminRfg)/NyIntvRfg
              hxxi = 1.0/hxx
              hyyi = 1.0/hyy
              xx = 0.0
              yy = 0.0
              ix = (xx-XminRfg)/hxx + 1
              ix1 = ix+1
              efx = (XminRfg-xx+ix*hxx)/hxx
              iy = (yy-YminRfg)/hyy + 1
              iy1 = iy+1
              efy = (YminRfg-yy+iy*hyy)/hyy
              ezn = extfld6xyz(3,ix,iy)*efx*efy + &
                    extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                    extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                    extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy)
              et = escale*cos(ww*tg+theta0)
              ez0 = ez0 + ezn*et
            endif
          else
            pos(1) = 0.0
            pos(2) = 0.0
            pos(3) = z
            pos(4) = tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
            ez0 = extfld(3)
          endif
        else
          pos(1) = 0.0
          pos(2) = 0.0
          pos(3) = z
          pos(4) = tg
          call getfld_BeamLineElem(beamelem,pos,extfld)
          ez0 = extfld(3)
        endif

        if(associated(beamelem%pdtl)) then
          !  print*,"into dtl"
          do n=1,innp
            postmp(1,n) = rays(1,n)*xl
            postmp(2,n) = rays(3,n)*xl
            postmp(3,n) = z
            postmp(4,n) = rays(5,n) + tg
          enddo
          call getfldpts_DTL(postmp,extfldtmp,beamelem%pdtl,innp)
        else if(associated(beamelem%pccl)) then
          do n=1,innp
            postmp(1,n) = rays(1,n)*xl
            postmp(2,n) = rays(3,n)*xl
            postmp(3,n) = z
            postmp(4,n) = rays(5,n) + tg
          enddo
          call getfldpts_CCL(postmp,extfldtmp,beamelem%pccl,innp)
        endif
        !print*,"ez0: ",z,ez0
        tmpgamma0 = gam + 0.5*tau*qmcc*ez0
        do n = 1, innp
          if(associated(beamelem%pemfld)) then
            if(FlagDisc.eq.1) then !use discrete data only
              !calculate field in Cartesian coordinate from the discrete
              !field function (r) in cylindrical coordinate
              et = escale*cos(ww*(tg+rays(5,n))+theta0)
              bt = escale*sin(ww*(tg+rays(5,n))+theta0)
              if(FlagCart.eq.1) then
                rr = sqrt(rays(1,n)*rays(1,n)+rays(3,n)*rays(3,n))*xl
                ir = rr*hri + 1
                if(ir.eq.NrIntvRf) ir=ir-1
                ir1 = ir+1
                efr = (ir*hr - rr)*hri
                er = (extfld6(1,ir)*efr+extfld6(1,ir1)*(1.0-efr))*et
                extfld(1) = er*rays(1,n)*xl/rr
                extfld(2) = er*rays(3,n)*xl/rr
                extfld(3) = (extfld6(3,ir)*efr+extfld6(3,ir1)*(1.0-efr))*et
                btheta = (extfld6(5,ir)*efr+extfld6(5,ir1)*(1.0-efr))*bt
                extfld(4) = -btheta*rays(3,n)*xl/rr
                extfld(5) = btheta*rays(1,n)*xl/rr
                extfld(6) = 0.0
              else if(FlagCart.eq.2) then
                xx = rays(1,n)*xl
                yy = rays(3,n)*xl
                ix = (xx-XminRfg)*hxxi + 1
                ix1 = ix+1
                efx = (XminRfg-xx+ix*hxx)*hxxi
                iy = (yy-YminRfg)*hyyi + 1
                iy1 = iy+1
                efy = (YminRfg-yy+iy*hyy)*hyyi
                extfld(1) = (extfld6xyz(1,ix,iy)*efx*efy + &
                      extfld6xyz(1,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(1,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(1,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(2) = (extfld6xyz(2,ix,iy)*efx*efy + &
                      extfld6xyz(2,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(2,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(2,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(3) = (extfld6xyz(3,ix,iy)*efx*efy + &
                      extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(4) = (extfld6xyz(4,ix,iy)*efx*efy + &
                      extfld6xyz(4,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(4,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(4,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(5) = (extfld6xyz(5,ix,iy)*efx*efy + &
                      extfld6xyz(5,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(5,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(5,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(6) = (extfld6xyz(6,ix,iy)*efx*efy + &
                      extfld6xyz(6,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(6,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(6,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
              endif
            !use both analytical function and discrete data.
            else if(FlagDisc.eq.2) then 
              pos(1) = rays(1,n)*xl
              pos(2) = rays(3,n)*xl
              pos(3) = z
              pos(4) = rays(5,n) + tg
              !get field in Cartesian coordinate from analytical function.
              call getfld_BeamLineElem(beamelem,pos,extfld)
              !calculate field in Cartesian coordinate from the discrete
              !field function (r) in cylindrical coordinate
              et = escale*cos(ww*(tg+rays(5,n))+theta0)
              bt = escale*sin(ww*(tg+rays(5,n))+theta0)
              if(FlagCart.eq.1) then
                rr = sqrt(rays(1,n)*rays(1,n)+rays(3,n)*rays(3,n))*xl
                ir = rr*hri + 1
                if(ir.eq.NrIntvRf) ir=ir-1
                ir1 = ir+1
                efr = (ir*hr - rr)*hri
                er = (extfld6(1,ir)*efr+extfld6(1,ir1)*(1.0-efr))*et
                extfld(1) = extfld(1) + er*rays(1,n)*xl/rr
                extfld(2) = extfld(2) + er*rays(3,n)*xl/rr
                extfld(3) = extfld(3) + &
                          (extfld6(3,ir)*efr+extfld6(3,ir1)*(1.0-efr))*et
                btheta = (extfld6(5,ir)*efr+extfld6(5,ir1)*(1.0-efr))*bt
                extfld(4) = extfld(4) - btheta*rays(3,n)*xl/rr
                extfld(5) = extfld(5) + btheta*rays(1,n)*xl/rr
!                extfld(6) = extfld(6) 
              else if(FlagCart.eq.2) then
                xx = rays(1,n)*xl
                yy = rays(3,n)*xl
                ix = (xx-XminRfg)*hxxi + 1
                ix1 = ix+1
                efx = (XminRfg-xx+ix*hxx)*hxxi
                iy = (yy-YminRfg)*hyyi + 1
                iy1 = iy+1
                efy = (YminRfg-yy+iy*hyy)*hyyi
                extfld(1) = (extfld6xyz(1,ix,iy)*efx*efy + &
                      extfld6xyz(1,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(1,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(1,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(2) = (extfld6xyz(2,ix,iy)*efx*efy + &
                      extfld6xyz(2,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(2,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(2,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(3) = (extfld6xyz(3,ix,iy)*efx*efy + &
                      extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(4) = (extfld6xyz(4,ix,iy)*efx*efy + &
                      extfld6xyz(4,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(4,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(4,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(5) = (extfld6xyz(5,ix,iy)*efx*efy + &
                      extfld6xyz(5,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(5,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(5,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(6) = (extfld6xyz(6,ix,iy)*efx*efy + &
                      extfld6xyz(6,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(6,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(6,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
              endif
            else !use analytical function data only
              !get field in Cartesian coordinate from analytical function.
              pos(1) = rays(1,n)*xl
              pos(2) = rays(3,n)*xl
              pos(3) = z
              pos(4) = rays(5,n) + tg
              call getfld_BeamLineElem(beamelem,pos,extfld)
            endif
          else if(associated(beamelem%pdtl)) then
            extfld(:)=extfldtmp(:,n)
          else if(associated(beamelem%pccl)) then
            extfld(:)=extfldtmp(:,n)
          else
            pos(1) = rays(1,n)*xl
            pos(2) = rays(3,n)*xl
            pos(3) = z
            pos(4) = rays(5,n) + tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
          endif
          ex = extfld(1)
          ey = extfld(2)
          ez = extfld(3)
          bx = extfld(4)
          by = extfld(5)
          bz = extfld(6)
          tmp12 = -tau*Clight*bz*rays(7,n)/2
          tmp13 = tau*ex*rays(7,n)/2
          tmp23 = tau*ey*rays(7,n)/2
          tmp1 = tmpgamma0*ex*tau*rays(7,n)
          tmp2 = Clight*by*tau*rays(7,n)
          tmp3 = tmpgamma0*ey*tau*rays(7,n)
          tmp4 = Clight*bx*tau*rays(7,n)
!          tmp5 = (ez0-ez)*tau*rays(7,n)
          !for multi-charge state, qmcc not equal to rays(7,n)
          tmp5 = (ez0*qmcc-ez*rays(7,n))*tau
          pz = sqrt((gam-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2)
          p1 = rays(2,n)
          p2 = rays(4,n)
          p3 = rays(6,n)
          do ii = 1, 2
            a12 = tmp12/pz
            a13 = tmp13/pz
            a23 = tmp23/pz
            b1 = p1-a12*p2-a13*p3+tmp1/pz - tmp2
            b2 = a12*p1+p2-a23*p3+tmp3/pz + tmp4
            b3 = -a13*p1-a23*p2+p3 + tmp5
            det = 1+a12*a12-a13*a13-a23*a23
            s11 = 1-a23*a23
            s12 = -a12+a13*a23
            s13 = a12*a23-a13
            s21 = a12+a13*a23
            s22 = 1-a13*a13
            s23 = -a23-a13*a12
            s31 = -a12*a23-a13
            s32 = -a23+a12*a13
            s33 = 1+a12*a12
            rays(2,n) = (s11*b1+s12*b2+s13*b3)/det
            rays(4,n) = (s21*b1+s22*b2+s23*b3)/det
            rays(6,n) = (s31*b1+s32*b2+s33*b3)/det
            tmpgamma00 = gam + tau*qmcc*ez0
            tmpsq2 = (tmpgamma00-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2
            if(tmpsq2.gt.0.0) then
              pz = 0.5*pz + 0.5*sqrt(tmpsq2)
            endif
          enddo
        enddo
        gam = gam + tau*qmcc*ez0

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatter20_BeamBunch

        ! scatter grid quantity onto particles.
        subroutine scatter20err_BeamBunch(innp,rays,tg,gam,chge,mass,&
                                       tau,z,beamelem)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (in) :: tau,mass,chge,tg,z
        double precision, intent (inout) :: gam
        integer, intent(in) :: innp
        type (BeamLineElem), intent(in) :: beamelem
        integer :: n,i,ii
        double precision :: t0
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: extfld
        double precision :: twopi,xl,tmpgamma0,tmpgamma00,&
        beta0,qmcc,ez0,tmp1,tmp2,tmp3,tmp4,tmp5,tmp12,tmp23,&
        tmp13,pz,p1,p2,p3,a12,a13,a23,b1,b2,b3,s11,s12,s13,s21,s22,s23,&
        s31,s32,s33,det,tmpsq2,ex,ey,ez,bx,by,bz
        double precision, dimension(6) :: extfld6
        double precision :: rr,hr,hri,te,tb,escale,rffreq,theta0,efr,&
                            er,btheta,ww,et,bt
        integer :: ir,ir1,FlagCart,FlagDisc
        double precision :: dx,dy,anglex,angley,anglez
        double precision, dimension(4,innp) :: postmp
        double precision, dimension(6,innp) :: extfldtmp

        call starttime_Timer( t0 )

        twopi = 2.0*Pi
        xl = Scxl
        beta0 = sqrt(gam**2-1.0)/gam
        qmcc = chge/mass

        call geterr_BeamLineElem(beamelem,dx,dy,anglex,angley,anglez)

        FlagDisc = 0
        FlagCart = 1
        pos(1) = 0.0
        pos(2) = 0.0
        pos(3) = z
        pos(4) = tg
        if(associated(beamelem%pemfld)) then
          FlagDisc = 0.1+beamelem%pemfld%Param(13)
          FlagCart = 0.1+beamelem%pemfld%Param(14)

          if(FlagDisc.eq.1) then
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            endif
            ez0 = extfld6(3)
          else if(FlagDisc.eq.2) then
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
            ez0 = extfld(3)
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            endif
            ez0 = ez0 + extfld6(3)
          else
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
            ez0 = extfld(3)
          endif
        else
          call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                       angley,anglez)
          ez0 = extfld(3)
        endif

        if(associated(beamelem%pdtl)) then
          !  print*,"into dtl"
          do n=1,innp
            postmp(1,n) = rays(1,n)*xl
            postmp(2,n) = rays(3,n)*xl
            postmp(3,n) = z
            postmp(4,n) = rays(5,n) + tg
          enddo
          call getfldpts_DTL(postmp,extfldtmp,beamelem%pdtl,innp)
        else if(associated(beamelem%pccl)) then
          do n=1,innp
            postmp(1,n) = rays(1,n)*xl
            postmp(2,n) = rays(3,n)*xl
            postmp(3,n) = z
            postmp(4,n) = rays(5,n) + tg
          enddo
          call getfldpts_CCL(postmp,extfldtmp,beamelem%pccl,innp)
        endif

        tmpgamma0 = gam + 0.5*tau*qmcc*ez0
        !print*,"ez0: ",ez0
        do n = 1, innp
          pos(1) = rays(1,n)*xl
          pos(2) = rays(3,n)*xl
          pos(3) = z
          pos(4) = rays(5,n) + tg
          if(FlagDisc.eq.1) then !use discrete data only
            !calculate field in Cartesian coordinate from the discrete
            !field function (r) in cylindrical coordinate
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld,dx,dy,anglex,&
                                  angley,anglez)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld,dx,dy,anglex,&
                                  angley,anglez)
            endif
          !use both analytical function and discrete data.
          else if(FlagDisc.eq.2) then 
            !get field in Cartesian coordinate from analytical function.
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
            !calculate field in Cartesian coordinate from the discrete
            !field function (r) in cylindrical coordinate
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            endif
            extfld = extfld + extfld6
          else if(associated(beamelem%pdtl)) then
            extfld(:)=extfldtmp(:,n)
          else if(associated(beamelem%pccl)) then
            extfld(:)=extfldtmp(:,n)
          else !use analytical function data only
            !get field in Cartesian coordinate from analytical function.
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
          endif

          ex = extfld(1)
          ey = extfld(2)
          ez = extfld(3)
          bx = extfld(4)
          by = extfld(5)
          bz = extfld(6)
          tmp12 = -tau*Clight*bz*rays(7,n)/2
          tmp13 = tau*ex*rays(7,n)/2
          tmp23 = tau*ey*rays(7,n)/2
          tmp1 = tmpgamma0*ex*tau*rays(7,n)
          tmp2 = Clight*by*tau*rays(7,n)
          tmp3 = tmpgamma0*ey*tau*rays(7,n)
          tmp4 = Clight*bx*tau*rays(7,n)
!          tmp5 = (ez0-ez)*tau*rays(7,n)
          !for multi-charge state, qmcc not equal to rays(7,n)
          tmp5 = (ez0*qmcc-ez*rays(7,n))*tau
          pz = sqrt((gam-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2)
          p1 = rays(2,n)
          p2 = rays(4,n)
          p3 = rays(6,n)
          do ii = 1, 2
            a12 = tmp12/pz
            a13 = tmp13/pz
            a23 = tmp23/pz
            b1 = p1-a12*p2-a13*p3+tmp1/pz - tmp2
            b2 = a12*p1+p2-a23*p3+tmp3/pz + tmp4
            b3 = -a13*p1-a23*p2+p3 + tmp5
            det = 1+a12*a12-a13*a13-a23*a23
            s11 = 1-a23*a23
            s12 = -a12+a13*a23
            s13 = a12*a23-a13
            s21 = a12+a13*a23
            s22 = 1-a13*a13
            s23 = -a23-a13*a12
            s31 = -a12*a23-a13
            s32 = -a23+a12*a13
            s33 = 1+a12*a12
            rays(2,n) = (s11*b1+s12*b2+s13*b3)/det
            rays(4,n) = (s21*b1+s22*b2+s23*b3)/det
            rays(6,n) = (s31*b1+s32*b2+s33*b3)/det
            tmpgamma00 = gam + tau*qmcc*ez0
            tmpsq2 = (tmpgamma00-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2
            if(tmpsq2.gt.0.0) then
              pz = 0.5*pz + 0.5*sqrt(tmpsq2)
            endif
          enddo
        enddo
        gam = gam + tau*qmcc*ez0

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatter20err_BeamBunch

        !All indices here are local to the processor.
        !find charge density on grid from particles.
        subroutine charge_BeamBunch(this,innp,innx,inny,innz,ptsgeom,&
                                    grid,chgdens,Flagbc,perdlen)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: innp,innx,inny,innz,Flagbc
        type (CompDom), intent(in) :: ptsgeom
        type (Pgrid2d), intent(in) :: grid
        double precision, intent(in) :: perdlen
        double precision,dimension(innx,inny,innz),intent(out) :: chgdens
        double precision :: t0
        !double precision, dimension(innx,inny,innz) :: tmpchg
        double precision :: recpnpt,sumtest
        integer :: totnp,nproccol,nprocrow,myid,myidx,myidy
        integer :: comm2d,commcol,commrow,ierr
        integer :: i,j,k
!        integer :: jadd,kadd,jj,jdisp
 
        call starttime_Timer(t0)

        call getsize_Pgrid2d(grid,totnp,nproccol,nprocrow)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        call getcomm_Pgrid2d(grid,comm2d,commcol,commrow)

        ! call MPI_BARRIER(comm2d,ierr)
        ! if(myid.eq.0) then
        !   print*,"before deposit"
        ! endif

        !deposition local particles onto grids.
        !call deposit_BeamBunch(innp,innx,inny,innz,this%Pts1, &
        !tmpchg,ptsgeom,nprocrow,nproccol,myidx,myidy)
          call deposit_BeamBunch(innp,innx,inny,innz,this%Pts1, &
          chgdens,ptsgeom,nprocrow,nproccol,myidx,myidy)

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.0) then
        !  print*,"after deposit, before guard"
        !endif

        !sum up the contribution from neighboring guard grid to
        !the boundary grid in CIC scheme.
        if((Flagbc.eq.1).or.(Flagbc.eq.5)) then  ! 3D open
!          if(totnp.ne.1) then
            !gather contributions from guard cells.
            call guardsum1_Fldmger(chgdens,innx,inny,innz,grid)
!          endif
        else
          print*,"no such type of boundary conditions!!!"
          stop
        endif
!        recpnpt = 1.0/this%Npt
        recpnpt = 1.0 !//this%Npt has been included in rays(8,n)
!        sumtest = 0.0
        do k = 1, innz
          do j = 1, inny
            do i = 1, innx
              !this%ChargeDensity(i,j,k) = tmpchg(i,j,k)*recpnpt
              chgdens(i,j,k) = chgdens(i,j,k) &
                                          *recpnpt
!              sumtest = sumtest + chgdens(i,j,k)
            enddo
          enddo
        enddo
!        print*,"sumtest: ",sumtest

        !if(myid.eq.0) then
        !  print*,"after guard"
        !endif
!        if(nproccol.gt.1) then
!          jadd = 1
!        else
!          jadd = 0
!        endif
!        if(nprocrow.gt.1) then
!          kadd = 1
!        else
!          kadd = 0
!        endif
!        if(myidy.eq.0) then
!          jdisp = 0
!        else
!          jdisp = 33
!        endif
!        do k = 1+kadd, innz-kadd
!          do j = 1+jadd, inny-jadd
!            do i = 1, innx
!              jj = j -jadd + jdisp
!!              chgdens(i,j,k) = (i+jj/100.0+(k-kadd)*jj/10.0)*0.001
!            enddo
!          enddo
!        enddo

        t_charge = t_charge + elapsedtime_Timer(t0)

        end subroutine charge_BeamBunch
        
        subroutine setpts_BeamBunch(this,inparticles,nptsin)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(in), dimension(:,:) :: inparticles
        integer, intent(in) :: nptsin

        deallocate(this%Pts1)
        allocate(this%Pts1(9,nptsin))
        this%Pts1(:,1:nptsin) = inparticles(:,1:nptsin)

        end subroutine setpts_BeamBunch

        ! set local # of particles.
        subroutine setnpt_BeamBunch(this,innpt)
        implicit none
        include 'mpif.h'
        integer, intent(in) :: innpt
        type (BeamBunch), intent(inout) :: this

        this%Nptlocal = innpt

        end subroutine setnpt_BeamBunch  

        ! get local # of particles.
        subroutine getnpt_BeamBunch(this,outnpt)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(in) :: this
        integer, intent(out) :: outnpt

        outnpt = this%Nptlocal

        end subroutine getnpt_BeamBunch  

        subroutine getpts_BeamBunch(this,outparticles)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(in) :: this
        double precision, dimension(:,:), intent(out) :: outparticles

        outparticles(:,1:this%Nptlocal) = this%Pts1(:,1:this%Nptlocal)

        end subroutine getpts_BeamBunch

        ! deposit particles onto grid.
        subroutine deposit_BeamBunch(innp,innx,inny,innz,rays,rho,& 
                                ptsgeom,npx,npy,myidx,myidy)
        implicit none
        include 'mpif.h'
        integer, intent(in) :: innp,innx,inny,innz,npx,npy,myidx,myidy
        double precision, intent (in), dimension (9, innp) :: rays
        double precision, intent (out), dimension (innx,inny,innz) :: rho
!        logical, intent (in), dimension (innp) :: msk
        integer :: ix,jx,kx,ix1,jx1,kx1
        integer, dimension(2,0:npx-1,0:npy-1) :: table
        integer, dimension(0:npx-1) :: xtable
        integer, dimension(0:npy-1) :: ytable
        double precision :: ab,cd,ef
        integer :: ngood, i, j, k, kadd, jadd
        double precision :: t0
        double precision :: hx,hxi,hy,hyi,hz,hzi,xmin,ymin,zmin
        double precision, dimension(3) :: msize
        double precision, dimension(6) :: range
        type (CompDom) :: ptsgeom

        call starttime_Timer( t0 )

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)
        hx = msize(1)
        hy = msize(2)
        hz = msize(3)

        call getrange_CompDom(ptsgeom,range)
        xmin = range(1)
        ymin = range(3)
        zmin = range(5)

        call getlctabnm_CompDom(ptsgeom,table)
        xtable(0) = 0
        do i = 1, npx - 1
          xtable(i) = xtable(i-1) + table(1,i-1,0)
        enddo

        ytable(0) = 0
        do i = 1, npy - 1
          ytable(i) = ytable(i-1) + table(2,0,i-1)
        enddo

        if(npx.gt.1) then
          kadd = -xtable(myidx) + 1
        else
          kadd = 0
        endif
        if(npy.gt.1) then
          jadd = -ytable(myidy) + 1
        else
          jadd = 0
        endif

        rho=0.
        do i = 1, innp
          ix=(rays(1,i)-xmin)*hxi + 1
          ab=((xmin-rays(1,i))+ix*hx)*hxi
          jx=(rays(3,i)-ymin)*hyi + 1 + jadd
          cd=((ymin-rays(3,i))+(jx-jadd)*hy)*hyi
          kx=(rays(5,i)-zmin)*hzi + 1 + kadd
          ef=((zmin-rays(5,i))+(kx-kadd)*hz)*hzi
          ix1=ix+1
          jx1=jx+1
          kx1=kx+1
          ! (i,j,k):
          rho(ix,jx,kx) = rho(ix,jx,kx) + ab*cd*ef*rays(8,i)
          ! (i,j+1,k):
          rho(ix,jx1,kx) = rho(ix,jx1,kx) + ab*(1.0-cd)*ef*rays(8,i)
          ! (i,j+1,k+1):
          rho(ix,jx1,kx1) = rho(ix,jx1,kx1)+ab*(1.0-cd)*(1.0-ef)*rays(8,i)
          ! (i,j,k+1):
          rho(ix,jx,kx1) = rho(ix,jx,kx1)+ab*cd*(1.0-ef)*rays(8,i)
          ! (i+1,j,k+1):
          rho(ix1,jx,kx1) = rho(ix1,jx,kx1)+(1.0-ab)*cd*(1.0-ef)*rays(8,i)
          ! (i+1,j+1,k+1):
          rho(ix1,jx1,kx1) = rho(ix1,jx1,kx1)+(1.0-ab)*(1.0-cd)*(1.0-ef)*rays(8,i)
          ! (i+1,j+1,k):
          rho(ix1,jx1,kx) = rho(ix1,jx1,kx)+(1.0-ab)*(1.0-cd)*ef*rays(8,i)
          ! (i+1,j,k):
          rho(ix1,jx,kx) = rho(ix1,jx,kx)+(1.0-ab)*cd*ef*rays(8,i)
        enddo
        
        t_rhofas = t_rhofas + elapsedtime_Timer( t0 )

        end subroutine deposit_BeamBunch

        subroutine destruct_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(out) :: this

        deallocate(this%Pts1)

        end subroutine destruct_BeamBunch

        !transform the particle coordinates to local coordinate of "ptref". 
        !Here, "ptref" coordinate has a rotation "theta" in y-z plane with
        !respect to the orginal coordinate.
        subroutine transfto_BeamBunch(this,ptref)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, dimension(6) :: ptref 
        double precision  :: cs,ss
        double precision, dimension(6) :: temp
        integer :: i

        cs = ptref(6)/sqrt(ptref(6)**2 + ptref(4)**2)
        ss = ptref(4)/sqrt(ptref(6)**2 + ptref(4)**2)
        do i = 1, this%Nptlocal
          temp(1) = this%Pts1(1,i) - ptref(1)
          temp(2) = this%Pts1(2,i) - ptref(2)
          temp(3) = this%Pts1(3,i) - ptref(3)
          temp(4) = this%Pts1(4,i) - ptref(4)
          temp(5) = this%Pts1(5,i) - ptref(5)
          temp(6) = this%Pts1(6,i) - ptref(6)
          this%Pts1(1,i) = temp(1)
          this%Pts1(2,i) = temp(2)
          this%Pts1(3,i) = temp(3)*cs - temp(5)*ss
          this%Pts1(4,i) = temp(4)*cs - temp(6)*ss
          this%Pts1(5,i) = temp(3)*ss + temp(5)*cs
          this%Pts1(6,i) = temp(4)*ss + temp(6)*cs
        enddo

        end subroutine transfto_BeamBunch
        subroutine transfback_BeamBunch(this,ptref)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, dimension(6) :: ptref 
        double precision  :: cs,ss
        double precision, dimension(6) :: tmp
        integer :: i

        cs = ptref(6)/sqrt(ptref(6)**2 + ptref(4)**2)
        ss = ptref(4)/sqrt(ptref(6)**2 + ptref(4)**2)
        do i = 1, this%Nptlocal
          tmp(1) = this%Pts1(1,i) + ptref(1)
          tmp(2) = this%Pts1(2,i) + ptref(2)
          tmp(3) = this%Pts1(3,i)*cs + this%Pts1(5,i)*ss
          tmp(4) = this%Pts1(4,i)*cs + this%Pts1(6,i)*ss
          tmp(5) = -this%Pts1(3,i)*ss + this%Pts1(5,i)*cs
          tmp(6) = -this%Pts1(4,i)*ss + this%Pts1(6,i)*cs
          this%Pts1(1,i) = tmp(1)
          this%Pts1(2,i) = tmp(2)
          this%Pts1(3,i) = tmp(3) + ptref(3)
          this%Pts1(4,i) = tmp(4) + ptref(4)
          this%Pts1(5,i) = tmp(5) + ptref(5)
          this%Pts1(6,i) = tmp(6) + ptref(6)
        enddo

        end subroutine transfback_BeamBunch

        !rotate to the particle coordinates to local beam coordinate of "ptref".
        !Here, the local "z" direction has been enlarged by "gamma" for the space-charge
        !calculation.
        !Here, "ptref" coordinate has a rotation "theta" in x-z plane with
        !respect to the orginal coordinate.
        subroutine rotto_BeamBunch(this,ptref,ptrange)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, dimension(6) :: ptref
        double precision, dimension(6), intent(out) :: ptrange
        double precision  :: cs,ss,gamma
        double precision, dimension(6) :: temp
        integer :: i
 
        gamma = sqrt(1.0+ptref(6)**2+ptref(2)**2)
        cs = ptref(6)/sqrt(ptref(6)**2 + ptref(2)**2)
        ss = ptref(2)/sqrt(ptref(6)**2 + ptref(2)**2)
        do i = 1, 3
          ptrange(2*i-1) = 1.0e20
          ptrange(2*i) = -1.0e20
        enddo

        do i = 1, this%Nptlocal
          temp(1) = this%Pts1(1,i)*Scxl 
          temp(2) = this%Pts1(2,i)
          temp(3) = this%Pts1(3,i)*Scxl 
          temp(4) = this%Pts1(4,i)
          temp(5) = this%Pts1(5,i)*Scxl 
          temp(6) = this%Pts1(6,i)
          this%Pts1(1,i) = temp(1)*cs - temp(5)*ss
          this%Pts1(2,i) = temp(2)*cs - temp(6)*ss
          this%Pts1(3,i) = temp(3)
          this%Pts1(4,i) = temp(4)
          this%Pts1(5,i) = (temp(1)*ss + temp(5)*cs)*gamma
          this%Pts1(6,i) = temp(2)*ss + temp(6)*cs
          if(ptrange(1).gt.this%Pts1(1,i)) then
            ptrange(1) = this%Pts1(1,i) 
          endif
          if(ptrange(2).lt.this%Pts1(1,i)) then
            ptrange(2) = this%Pts1(1,i) 
          endif
          if(ptrange(3).gt.this%Pts1(3,i)) then
            ptrange(3) = this%Pts1(3,i) 
          endif
          if(ptrange(4).lt.this%Pts1(3,i)) then
            ptrange(4) = this%Pts1(3,i) 
          endif
          if(ptrange(5).gt.this%Pts1(5,i)) then
            ptrange(5) = this%Pts1(5,i) 
          endif
          if(ptrange(6).lt.this%Pts1(5,i)) then
            ptrange(6) = this%Pts1(5,i) 
          endif
        enddo
 
        end subroutine rotto_BeamBunch
        subroutine rotback_BeamBunch(this,ptref)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, dimension(6) :: ptref
        double precision, dimension(6) :: tmp
        double precision  :: cs,ss,gamma
        integer :: i
 
        gamma = sqrt(1.0+ptref(6)**2+ptref(2)**2)
        cs = ptref(6)/sqrt(ptref(6)**2 + ptref(2)**2)
        ss = ptref(2)/sqrt(ptref(6)**2 + ptref(2)**2)
        do i = 1, this%Nptlocal
          tmp(1) = this%Pts1(1,i)*cs + this%Pts1(5,i)*ss/gamma
          tmp(2) = this%Pts1(2,i)*cs + this%Pts1(6,i)*ss
          tmp(3) = this%Pts1(3,i)
          tmp(4) = this%Pts1(4,i)
          tmp(5) = -this%Pts1(1,i)*ss + this%Pts1(5,i)*cs/gamma
          tmp(6) = -this%Pts1(2,i)*ss + this%Pts1(6,i)*cs
          this%Pts1(1,i) = tmp(1)/Scxl
          this%Pts1(2,i) = tmp(2)
          this%Pts1(3,i) = tmp(3)/Scxl 
          this%Pts1(4,i) = tmp(4) 
          this%Pts1(5,i) = tmp(5)/Scxl
          this%Pts1(6,i) = tmp(6)
        enddo
 
        end subroutine rotback_BeamBunch

        !convert from z coordinates (x,px,y,py,phase,pt0-pt) to 
        !t frame coordinates (x,px,y,py,z,pz). Here, x normalized by xl, px = gamma beta_x.
        subroutine convZT_BeamBunch(this)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer :: i
        double precision :: gam,rcpgammai,betai
 
        gam = -this%refptcl(6)
 
        ! The following steps go from z to t frame.
        ! 2) Linear algorithm to transfer from z to t frame.
        do i = 1, this%Nptlocal
          rcpgammai = 1.0/(-this%Pts1(6,i)+gam)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+this%Pts1(2,i)**2+ &
                      this%Pts1(4,i)**2) )
          this%Pts1(1,i) = this%Pts1(1,i)-this%Pts1(2,i) &
                           *this%Pts1(5,i)*rcpgammai  !// x/L
          this%Pts1(2,i) = this%Pts1(2,i) !//gamma beta_x
          this%Pts1(3,i) = this%Pts1(3,i)-this%Pts1(4,i) &
                           *this%Pts1(5,i)*rcpgammai  !// y/L
          this%Pts1(4,i) = this%Pts1(4,i)  !//gamma beta_y
          this%Pts1(5,i) = -betai*this%Pts1(5,i) !// z/L
          this%Pts1(6,i) = betai/rcpgammai  !//gamma beta_z
        enddo

        this%refptcl = 0.0
        this%refptcl(6) = sqrt(gam**2 - 1.0)
!        do i = 1, this%Nptlocal
!          write(49,110)this%Pts1(1:6,i)
!        enddo
!110     format(6(1x,e14.6))
          
        end subroutine convZT_BeamBunch

        !Linear algorithm to transfer from t to z frame after bend.
        !The Cartesian coordinate has been rotated following the exit direction 
        !of the reference particle. The exit angle of the reference particle
        !should correspond to the bend angle.
        subroutine convTZ_BeamBunch(this,tout)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision :: tout
        integer :: i
        double precision :: gamma0
        double precision :: rcpgammai,betai,cs,ss
        double precision, dimension(6) :: temp
 
!        do i = 1, this%Nptlocal
!          write(50,110)this%Pts1(1:6,i)
!        enddo
!110     format(6(1x,e14.6))
        !rotate and shift to the local coordinates of the reference particle.
        !However, there is no shift of the momentum
        cs = this%refptcl(6)/sqrt(this%refptcl(6)**2 + this%refptcl(2)**2)
        ss = this%refptcl(2)/sqrt(this%refptcl(6)**2 + this%refptcl(2)**2)
        do i = 1, this%Nptlocal
          temp(1) = this%Pts1(1,i) - this%refptcl(1)
          temp(2) = this%Pts1(2,i) 
          temp(3) = this%Pts1(3,i) - this%refptcl(3)
          temp(4) = this%Pts1(4,i)
          temp(5) = this%Pts1(5,i) - this%refptcl(5)
          temp(6) = this%Pts1(6,i)
          this%Pts1(1,i) = temp(1)*cs - temp(5)*ss
          this%Pts1(2,i) = temp(2)*cs - temp(6)*ss
          this%Pts1(3,i) = temp(3)
          this%Pts1(4,i) = temp(4)
          this%Pts1(5,i) = temp(1)*ss + temp(5)*cs
          this%Pts1(6,i) = temp(2)*ss + temp(6)*cs
        enddo
        temp(2) = this%refptcl(2)
        temp(6) = this%refptcl(6)
        this%refptcl(2) = temp(2)*cs - temp(6)*ss
        this%refptcl(6) = temp(2)*ss + temp(6)*cs

!        print*,"refpt: ",this%refptcl
!        do i = 1, this%Nptlocal
!          write(64,110)this%Pts1(1:6,i)
!        enddo
!111     format(6(1x,e14.6))

        !//convert from the local T frame (dx,px,dy,py,dz,pz) to Z frame
        !//(x,px,y,py,phase,pt0-pt).
        gamma0 = sqrt(1+this%refptcl(2)**2+this%refptcl(6)**2)
        do i = 1, this%Nptlocal
          rcpgammai = 1.0/sqrt(1.0+this%Pts1(2,i)**2+this%Pts1(4,i)**2+this%Pts1(6,i)**2)
          betai = this%Pts1(6,i)*rcpgammai
          this%Pts1(6,i) = gamma0 - 1.0/rcpgammai
          this%Pts1(5,i) = this%Pts1(5,i)/(-betai)
          this%Pts1(1,i) = this%Pts1(1,i)+this%Pts1(2,i) &
                            *this%Pts1(5,i)*rcpgammai
          this%Pts1(3,i) = this%Pts1(3,i)+this%Pts1(4,i) &
                            *this%Pts1(5,i)*rcpgammai
        enddo

        this%refptcl = 0.0
        this%refptcl(5) = tout
        this%refptcl(6) = -gamma0
 
        end subroutine convTZ_BeamBunch

        !//drift half step in positions.
        !//Here, x, y, z are normalized by C * Dt
        !//tau - normalized step size (by Dt).
        !//the time "t" is normalized by the scaling frequency.
        subroutine drifthalfT_BeamBunch(this,t,tau)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        double precision, intent(inout) :: t
        double precision, intent (in) :: tau
        double precision :: xl,pz
        double precision :: t0,recpgam
        integer :: i
 
        call starttime_Timer(t0)
 
        do i = 1, this%Nptlocal
          !//get 1.0/gamma of each particle
          recpgam = 1.0/sqrt(1.0+this%Pts1(2,i)**2+this%Pts1(4,i)**2+&
                                 this%Pts1(6,i)**2)
          this%Pts1(1,i) = this%Pts1(1,i)+0.5*tau*this%Pts1(2,i)*recpgam
          this%Pts1(3,i) = this%Pts1(3,i)+0.5*tau*this%Pts1(4,i)*recpgam
          this%Pts1(5,i) = this%Pts1(5,i)+0.5*tau*this%Pts1(6,i)*recpgam
        enddo
        recpgam = 1.0/sqrt(1.0+this%refptcl(2)**2+this%refptcl(4)**2+&
                           this%refptcl(6)**2)
        this%refptcl(1) = this%refptcl(1)+0.5*tau*this%refptcl(2)*recpgam
        this%refptcl(3) = this%refptcl(3)+0.5*tau*this%refptcl(4)*recpgam
        this%refptcl(5) = this%refptcl(5)+0.5*tau*this%refptcl(6)*recpgam
 
        t_map1 = t_map1 + elapsedtime_Timer(t0)
 
        end subroutine drifthalfT_BeamBunch

        subroutine kickT_BeamBunch(this,beamelem,z,tau,innx,inny,innz, &
                             temppotent,ptsgeom,grid,Flagbc,flagerr)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(in) :: beamelem
        integer, intent(in) :: innx, inny, innz, Flagbc,flagerr
        type (CompDom), intent(in) :: ptsgeom
        double precision,dimension(innx,inny,innz),intent(inout) :: temppotent
        type (Pgrid2d), intent(in) :: grid
        double precision, intent(in) :: z, tau
        double precision, dimension(innx,inny,innz) :: egx,egy,egz
        double precision, dimension(3) :: msize
        double precision :: hxi, hyi, hzi
        double precision :: t0,tg,chge,mass,curr,gam
        integer :: totnp,nproccol,nprocrow,myid,myidx,myidy
        integer :: i, j, k, yadd, zadd, innp
!        integer :: comm2d,commcol,commrow

        call starttime_Timer(t0)

        call getsize_Pgrid2d(grid,totnp,nproccol,nprocrow)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        if(nproccol.gt.1) then
          yadd = 1
        else
          yadd = 0
        endif
        if(nprocrow.gt.1) then
          zadd = 1
        else
          zadd = 0
        endif

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"before guardexch:"
        !endif

        curr = this%Current
        innp = this%Nptlocal
        tg = z
        mass = this%Mass
        chge = this%Charge

        if(curr.gt.0.0) then
!------------------------------------------------------------------
! current greater than 0
    
        ! Exchange potential information on guard grid cells.
        if((Flagbc.eq.1).or.(Flagbc.eq.5)) then ! 3D open 
          if(totnp.ne.1) then
            call guardexch1_Fldmger(temppotent,innx,inny,innz,grid)
          endif
        else
          print*,"no such boundary condition!!!!"
          stop
        endif

! cache optimization here.
        !print*,"yadd: ",yadd,zadd,innx,inny,innz,1.0/hxi,1.0/hyi,1.0/hzi
        !Ex
        !egx = 0.0
        do k = zadd+1, innz-zadd
          do j = yadd+1, inny-yadd
            egx(1,j,k) = hxi*(temppotent(1,j,k)-temppotent(2,j,k))
            do i = 2, innx-1
              egx(i,j,k) = 0.5*hxi*(temppotent(i-1,j,k)- &
                           temppotent(i+1,j,k))
            enddo
            egx(innx,j,k) = hxi*(temppotent(innx-1,j,k)- &
                                 temppotent(innx,j,k))
          enddo
        enddo

        !Ey
        !egy = 0.0
        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then  ! periodic in theta

        if(nproccol.gt.1) then
          do k = 1, innz
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
            enddo
          enddo
        else
          do k = 1, innz
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
                egy(1,j,k) = 0.0
            enddo
          enddo
          do k = 1, innz
            do i = 2, innx
              egy(i,1,k) = 0.5*hyi*(temppotent(i,inny-1,k) -  &
                           temppotent(i,2,k))*hxi/(i-1)
              egy(i,inny,k) = egy(i,1,k)
            enddo
            egy(1,1,k) = 0.0
            egy(1,inny,k) = 0.0
          enddo
        endif

        else  ! open in Y

        if(nproccol.gt.1) then 
          if(myidy.eq.0) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,yadd+1,k) = hyi*(temppotent(i,yadd+1,k)- &
                                       temppotent(i,yadd+2,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+2, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else if(myidy.eq.(nproccol-1)) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,inny-yadd,k) = hyi*(temppotent(i,inny-yadd-1,k)- &
                                          temppotent(i,inny-yadd,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd-1
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          endif
        else
          do k = zadd+1, innz-zadd
            do i = 1, innx
              egy(i,1,k) = hyi*(temppotent(i,1,k)-temppotent(i,2,k))
            enddo
            do j = 2, inny-1
              do i = 1, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                             temppotent(i,j+1,k))
              enddo
            enddo
            do i = 1, innx
              egy(i,inny,k) = hyi*(temppotent(i,inny-1,k)- &
                                   temppotent(i,inny,k))
            enddo
          enddo
        endif

        endif

        !Ez
        !egz = 0.0
        if(nprocrow.gt.1) then 
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            if(myidx.eq.0) then
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,zadd+1) = hzi*(temppotent(i,j,zadd+1)- &
                                         temppotent(i,j,zadd+2))
                enddo
              enddo
              do k = zadd+2, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            else if(myidx.eq.(nprocrow-1)) then
              do k = zadd+1, innz-zadd-1
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,innz-zadd) = hzi*(temppotent(i,j,innz-zadd-1)- &
                                            temppotent(i,j,innz-zadd))
                enddo
              enddo
            else
              do k = zadd+1, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            endif
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                               temppotent(i,j,k+1))
                enddo
              enddo
            enddo
          else
            print*,"no such boundary condition!!!"
            stop
          endif
        else
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1) = hzi*(temppotent(i,j,1)-temppotent(i,j,2))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1)=0.5*hzi*(temppotent(i,j,innz-1)-temppotent(i,j,2))
              enddo
            enddo
          else
          endif
          do k = 2, innz-1
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                      temppotent(i,j,k+1))
              enddo
            enddo
          enddo
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,innz))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = 0.5*hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,2))
              enddo
            enddo
          else
          endif
        endif

        ! find field from potential.
!        egx = 0.5*hxi*(cshift(temppotent,-1,1) -  &
!                       cshift(temppotent,1,1))
!        egy = 0.5*hyi*(cshift(temppotent,-1,2) -  &
!                       cshift(temppotent,1,2))
!        egz = 0.5*hzi*(cshift(temppotent,-1,3) -  &
!                      cshift(temppotent,1,3))

!        if(totnp.eq.1) then
!          egz(:,:,2) = 0.5*hzi*(temppotent(:,:,innz-1)-&
!                                temppotent(:,:,3))
!          egz(:,:,innz-1) = 0.5*hzi*(temppotent(:,:,innz-2)-&
!                                temppotent(:,:,2))
!          egy(:,2,:) = 0.5*hyi*(temppotent(:,inny-1,:)-&
!                                temppotent(:,3,:))
!          egy(:,inny-1,:) = 0.5*hyi*(temppotent(:,inny-2,:)-&
!                                temppotent(:,2,:))
!        endif

        !Send the E field to the neibhoring guard grid to do the CIC
        !interpolation.
        if(totnp.ne.1) then
          call boundint4_Fldmger(egx,egy,egz,innx,inny,innz,grid)
        endif

        call scatterT_BeamBunch(innp,innx,inny,innz,this%Pts1,this%refptcl,&
        egx,egy,egz,ptsgeom,nprocrow,nproccol,myidx,myidy,tg,chge,mass,tau,z,&
        beamelem)

        else
!------------------------------------------------------------------
! current is 0
          call scatterT0_BeamBunch(innp,this%Pts1,this%refptcl,tg,chge,mass,tau,z,&
                                   beamelem)
        endif

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.0) then
        !  print*,"after kick:"
        !endif

        t_force = t_force + elapsedtime_Timer(t0)

        end subroutine kickT_BeamBunch

        !Here, the update of the momentum is in the rotated coordinates
        !since the boost direction is not along z but in the x-z plane
        !due to the bend magnet.
        subroutine scatterT_BeamBunch(innp,innx,inny,innz,rays,refpt,exg,&
        eyg,ezg,ptsgeom,npx,npy,myidx,myidy,tg,chge,mass,dt,z,&
        beamelem)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (inout), dimension (6) :: refpt
        double precision, intent (in), dimension (innx,inny,innz) :: exg,eyg,ezg 
        double precision, intent (in) :: dt,mass,chge,tg,z
        integer, intent(in) :: innp,innx,inny,innz,npx,npy,myidx,myidy
        type (BeamLineElem), intent(in) :: beamelem
        integer, dimension(2,0:npx-1,0:npy-1) :: table
        integer, dimension(0:npx-1) :: xtable
        integer, dimension(0:npy-1) :: ytable
        double precision :: ab, cd, ef
        integer :: n,i,ii
        double precision :: t0
        double precision :: hx,hxi,hy,hyi,hz,hzi,xmin,ymin,zmin
        double precision, dimension(3) :: msize
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: range, extfld
        type (CompDom) :: ptsgeom
        integer :: ix,jx,kx,ix1,jx1,kx1,ierr,kadd,jadd
        double precision :: tmpscale,qmcc,&
        a1,a2,a3,a4,s1,s2,s3,umx,umy,umz,upx,upy,upz,tmp,&
        exn,eyn,ezn,ex,ey,ez,bx,by,bz,recpgamma
        double precision :: cs,ss,gam,beta0,coefE0,coefB0

        call starttime_Timer( t0 )

        !tmpscale = Clight*Clight*1.0e-7*curr/bfreq*chge
        tmpscale = Clight*Clight*1.0e-7 !curr*chge/bfreq are included in the charge density
        qmcc = chge/mass
        coefE0 = Scxl
        coefB0 = Scxl*Clight
        gam = sqrt(1.0+refpt(2)**2+refpt(6)**2)
        beta0 = sqrt(gam**2-1.0)/gam
        !cos and sin of the rotation angle. In a straight machine,
        !the rotation angle is 0.
        cs = refpt(6)/sqrt(refpt(2)**2+refpt(6)**2)
        ss = refpt(2)/sqrt(refpt(2)**2+refpt(6)**2)

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)
        hx = msize(1)
        hy = msize(2)
        hz = msize(3)

        call getrange_CompDom(ptsgeom,range)
        xmin = range(1)
        ymin = range(3)
        zmin = range(5)

        call getlctabnm_CompDom(ptsgeom,table)
        xtable(0) = 0
        do i = 1, npx - 1
          xtable(i) = xtable(i-1) + table(1,i-1,0)
        enddo

        ytable(0) = 0
        do i = 1, npy - 1
          ytable(i) = ytable(i-1) + table(2,0,i-1)
        enddo

        if(npx.gt.1) then
          kadd = -xtable(myidx) + 1
        else
          kadd = 0
        endif
        if(npy.gt.1) then
          jadd = -ytable(myidy) + 1
        else
          jadd = 0
        endif

        !update the momentum of the reference particle using the external fields
        !get the external fields at given x,y,z,t
        pos(1) = refpt(1)*Scxl
        pos(2) = refpt(3)*Scxl
        pos(3) = refpt(5)*Scxl
        pos(4) = tg
        call getfld_BeamLineElem(beamelem,pos,extfld)
   
        ex = extfld(1)
        ey = extfld(2)
        ez = extfld(3)
        bx = extfld(4)
        by = extfld(5)
        bz = extfld(6)
        umx = refpt(2) + coefE0*qmcc*ex*0.5*dt
        umy = refpt(4) + coefE0*qmcc*ey*0.5*dt
        umz = refpt(6) + coefE0*qmcc*ez*0.5*dt
        recpgamma = 1.0/sqrt(1.0+umx*umx+umy*umy+umz*umz)
        tmp = 0.5*coefB0*qmcc*dt*recpgamma
        a1 = tmp*bx
        a2 = tmp*by
        a3 = tmp*bz
        a4 = 1.0+a1*a1+a2*a2+a3*a3
        s1 = umx + tmp*(umy*bz-umz*by)
        s2 = umy - tmp*(umx*bz-umz*bx)
        s3 = umz + tmp*(umx*by-umy*bx)
        upx = ((1.0+a1*a1)*s1+(a1*a2+a3)*s2+(a1*a3-a2)*s3)/a4
        upy = ((a1*a2-a3)*s1+(1.0+a2*a2)*s2+(a2*a3+a1)*s3)/a4
        upz = ((a1*a3+a2)*s1+(a2*a3-a1)*s2+(1.0+a3*a3)*s3)/a4
        refpt(2) = upx + coefE0*qmcc*ex*0.5*dt
        refpt(4) = upy + coefE0*qmcc*ey*0.5*dt
        refpt(6) = upz + coefE0*qmcc*ez*0.5*dt

        do n = 1, innp
          ix=(rays(1,n)-xmin)*hxi + 1
          ab=((xmin-rays(1,n))+ix*hx)*hxi
          jx=(rays(3,n)-ymin)*hyi + 1 + jadd
          cd=((ymin-rays(3,n))+(jx-jadd)*hy)*hyi
          kx=(rays(5,n)-zmin)*hzi + 1 + kadd
          ef=((zmin-rays(5,n))+(kx-kadd)*hz)*hzi

          ix1 = ix + 1
          jx1 = jx + 1
          kx1 = kx + 1

          exn = (exg(ix,jx,kx)*ab*cd*ef  &
                  +exg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +exg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +exg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +exg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +exg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +exg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +exg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          eyn = (eyg(ix,jx,kx)*ab*cd*ef  &
                  +eyg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +eyg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +eyg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +eyg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +eyg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +eyg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +eyg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          ezn = ezg(ix,jx,kx)*ab*cd*ef  &
                  +ezg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +ezg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +ezg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +ezg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +ezg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +ezg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +ezg(ix1,jx,kx)*(1.0-ab)*cd*ef

          !get field in Cartesian coordinate from analytical function.
          !we need to rotate the coordinate back to the orginal coordinate.
          pos(1) = cs*rays(1,n) + ss*rays(5,n)/gam
          pos(2) = rays(3,n)
          pos(3) = -ss*rays(1,n) + cs*rays(5,n)/gam
          pos(4) = tg
          call getfld_BeamLineElem(beamelem,pos,extfld)

          !//Here, E and B fields are in real units.
          !//after get the external we need to transform the external field into
          !//the rotated coordinate.
          ex = tmpscale*exn+extfld(1)*cs - extfld(3)*ss
          ey = tmpscale*eyn+extfld(2)
          ez = tmpscale*ezn+extfld(1)*ss + extfld(3)*cs
          bx = -beta0/Clight*tmpscale*eyn+extfld(4)*cs-extfld(6)*ss
          by = beta0/Clight*tmpscale*exn+extfld(5)
          bz = extfld(4)*ss + extfld(6)*cs

          !//advance the momenta of particles using implicit central
          !//difference scheme from Birdall and Longdon's book.
          umx = rays(2,n) + coefE0*rays(7,n)*ex*0.5*dt;
          umy = rays(4,n) + coefE0*rays(7,n)*ey*0.5*dt;
          umz = rays(6,n) + coefE0*rays(7,n)*ez*0.5*dt;
          recpgamma = 1.0/sqrt(1.0+umx*umx+umy*umy+umz*umz);
          tmp = 0.5*coefB0*rays(7,n)*dt*recpgamma;
          a1 = tmp*bx;
          a2 = tmp*by;
          a3 = tmp*bz;
          a4 = 1.0+a1*a1+a2*a2+a3*a3;
          s1 = umx + tmp*(umy*bz-umz*by);
          s2 = umy - tmp*(umx*bz-umz*bx);
          s3 = umz + tmp*(umx*by-umy*bx);
          upx = ((1.0+a1*a1)*s1+(a1*a2+a3)*s2+(a1*a3-a2)*s3)/a4;
          upy = ((a1*a2-a3)*s1+(1.0+a2*a2)*s2+(a2*a3+a1)*s3)/a4;
          upz = ((a1*a3+a2)*s1+(a2*a3-a1)*s2+(1.0+a3*a3)*s3)/a4;
          rays(2,n) = upx + coefE0*rays(7,n)*ex*0.5*dt;
          rays(4,n) = upy + coefE0*rays(7,n)*ey*0.5*dt;
          rays(6,n) = upz + coefE0*rays(7,n)*ez*0.5*dt;
        enddo

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatterT_BeamBunch

        !Here, the update of the momentum is in the rotated coordinates
        !since the boost direction is not along z but in the x-z plane
        !due to the bend magnet. (Without Current)
        subroutine scatterT0_BeamBunch(innp,rays,refpt,&
        tg,chge,mass,dt,z,beamelem)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (inout), dimension (6) :: refpt
        double precision, intent (in) :: dt,mass,chge,tg,z
        integer, intent(in) :: innp
        type (BeamLineElem), intent(in) :: beamelem
        integer :: n,i,ii
        double precision :: t0
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: extfld
        double precision :: qmcc,&
        a1,a2,a3,a4,s1,s2,s3,umx,umy,umz,upx,upy,upz,tmp,&
        exn,eyn,ezn,ex,ey,ez,bx,by,bz,recpgamma
        double precision :: cs,ss,gam,coefE0,coefB0

        call starttime_Timer( t0 )

        qmcc = chge/mass
        coefE0 = Scxl
        coefB0 = Scxl*Clight
        gam = sqrt(1.0+refpt(2)**2+refpt(6)**2)
        !cos and sin of the rotation angle. In a straight machine,
        !the rotation angle is 0.
        cs = refpt(6)/sqrt(refpt(2)**2+refpt(6)**2)
        ss = refpt(2)/sqrt(refpt(2)**2+refpt(6)**2)

        !update the momentum of the reference particle using the external fields
        !get the external fields at given x,y,z,t
        pos(1) = refpt(1)*Scxl
        pos(2) = refpt(3)*Scxl
        pos(3) = refpt(5)*Scxl
        pos(4) = tg
        call getfld_BeamLineElem(beamelem,pos,extfld)
   
        ex = extfld(1)
        ey = extfld(2)
        ez = extfld(3)
        bx = extfld(4)
        by = extfld(5)
        bz = extfld(6)
!        print*,"ex,..",ex,ey,ez,bx,by,bz,pos(1),pos(2),pos(3)
!        print*,"coef: ",coefE0,coefB0,dt,qmcc
!        print*,"refpt: ",refpt(1),refpt(2),refpt(3),refpt(4),refpt(5),refpt(6)
        umx = refpt(2) + coefE0*qmcc*ex*0.5*dt
        umy = refpt(4) + coefE0*qmcc*ey*0.5*dt
        umz = refpt(6) + coefE0*qmcc*ez*0.5*dt
        recpgamma = 1.0/sqrt(1.0+umx*umx+umy*umy+umz*umz)
        tmp = 0.5*coefB0*qmcc*dt*recpgamma
        a1 = tmp*bx
        a2 = tmp*by
        a3 = tmp*bz
        a4 = 1.0+a1*a1+a2*a2+a3*a3
        s1 = umx + tmp*(umy*bz-umz*by)
        s2 = umy - tmp*(umx*bz-umz*bx)
        s3 = umz + tmp*(umx*by-umy*bx)
        upx = ((1.0+a1*a1)*s1+(a1*a2+a3)*s2+(a1*a3-a2)*s3)/a4
        upy = ((a1*a2-a3)*s1+(1.0+a2*a2)*s2+(a2*a3+a1)*s3)/a4
        upz = ((a1*a3+a2)*s1+(a2*a3-a1)*s2+(1.0+a3*a3)*s3)/a4
        refpt(2) = upx + coefE0*qmcc*ex*0.5*dt
        refpt(4) = upy + coefE0*qmcc*ey*0.5*dt
        refpt(6) = upz + coefE0*qmcc*ez*0.5*dt

!        print*,"qmcc: ",rays(7,1),rays(7,2),rays(7,3),innp,qmcc
        do n = 1, innp
          !get field in Cartesian coordinate from analytical function.
          !we need to rotate the coordinate back to the orginal coordinate.
          pos(1) = cs*rays(1,n) + ss*rays(5,n)/gam
          pos(2) = rays(3,n)
          pos(3) = -ss*rays(1,n) + cs*rays(5,n)/gam
          pos(4) = tg
          call getfld_BeamLineElem(beamelem,pos,extfld)

          !//Here, E and B fields are in real units.
          !//after get the external we need to transform the external field into
          !//the rotated coordinate.
          ex = extfld(1)*cs - extfld(3)*ss
          ey = extfld(2)
          ez = extfld(1)*ss + extfld(3)*cs
          bx = extfld(4)*cs-extfld(6)*ss
          by = extfld(5)
          bz = extfld(4)*ss+extfld(6)*cs

          !//advance the momenta of particles using implicit central
          !//difference scheme from Birdall and Longdon's book.
          umx = rays(2,n) + coefE0*rays(7,n)*ex*0.5*dt;
          umy = rays(4,n) + coefE0*rays(7,n)*ey*0.5*dt;
          umz = rays(6,n) + coefE0*rays(7,n)*ez*0.5*dt;
          recpgamma = 1.0/sqrt(1.0+umx*umx+umy*umy+umz*umz);
          tmp = 0.5*coefB0*rays(7,n)*dt*recpgamma;
          a1 = tmp*bx;
          a2 = tmp*by;
          a3 = tmp*bz;
          a4 = 1.0+a1*a1+a2*a2+a3*a3;
          s1 = umx + tmp*(umy*bz-umz*by);
          s2 = umy - tmp*(umx*bz-umz*bx);
          s3 = umz + tmp*(umx*by-umy*bx);
          upx = ((1.0+a1*a1)*s1+(a1*a2+a3)*s2+(a1*a3-a2)*s3)/a4;
          upy = ((a1*a2-a3)*s1+(1.0+a2*a2)*s2+(a2*a3+a1)*s3)/a4;
          upz = ((a1*a3+a2)*s1+(a2*a3-a1)*s2+(1.0+a3*a3)*s3)/a4;
          rays(2,n) = upx + coefE0*rays(7,n)*ex*0.5*dt;
          rays(4,n) = upy + coefE0*rays(7,n)*ey*0.5*dt;
          rays(6,n) = upz + coefE0*rays(7,n)*ez*0.5*dt;
        enddo

        !print*,"ex2: : ",ex,ey,ez,bx,by,bz
        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatterT0_BeamBunch

        subroutine kick1wake_BeamBunch(this,tau,innx,inny,innz,temppotent,&
                              ptsgeom,grid,Flagbc,perdlen,&
                              exwake,eywake,ezwake,Nz,npx,npy,Flagsc)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        integer, intent(in) :: innx, inny, innz,Flagbc,Nz,npx,npy,Flagsc
        type (CompDom), intent(in) :: ptsgeom
        double precision, dimension(innx,inny,innz), intent(inout) :: temppotent
        type (Pgrid2d), intent(in) :: grid
        double precision, intent(in) :: tau,perdlen
        double precision, dimension(Nz) :: exwake,eywake,ezwake
        double precision, dimension(innx,inny,innz) :: egx,egy,egz
        double precision, dimension(3) :: msize
        double precision :: hxi, hyi, hzi,gam,curr,mass
        double precision :: t0,chrg
        integer :: totnp,nproccol,nprocrow,myid,myidx,myidy
        integer :: i, j, k, yadd, zadd, innp,ierr
        double precision, dimension(0:npx-1) :: ztable,zdisp
        integer, dimension(2,0:npx-1,0:npy-1) :: temptab
        integer :: ix,jy,kz,kst
        double precision :: twopi,tmpscale,fpei,xk,bet,bbyk,gambet,brho,&
                            vz0,perv0,xycon,tcon

        call starttime_Timer(t0)

        !if(this%Current.lt.1.0e-20) goto 1000
        !Flagsc=0, space charge is OFF
        if(Flagsc.eq.0 .OR. this%Current.lt.1.0e-20) goto 1000

        call getsize_Pgrid2d(grid,totnp,nproccol,nprocrow)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        if(nproccol.gt.1) then
          yadd = 1
        else
          yadd = 0
        endif
        if(nprocrow.gt.1) then
          zadd = 1
        else
          zadd = 0
        endif

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)

        ! Exchange potential information on guard grid cells.
        if((Flagbc.eq.1).or.(Flagbc.eq.5) ) then  
          ! Transverse open or finite with longitudinal opend
!          if(totnp.ne.1) then
            call guardexch1_Fldmger(temppotent,innx,inny,innz,grid)
!          endif
        else
          print*,"no such boundary conditions!!!"
          stop
        endif

! cache optimization here.
        !print*,"yadd: ",yadd,zadd,innx,inny,innz,1.0/hxi,1.0/hyi,1.0/hzi
        !Ex
        !egx = 0.0
        do k = zadd+1, innz-zadd
          do j = yadd+1, inny-yadd
            egx(1,j,k) = hxi*(temppotent(1,j,k)-temppotent(2,j,k))
            do i = 2, innx-1
              egx(i,j,k) = 0.5*hxi*(temppotent(i-1,j,k)- &
                           temppotent(i+1,j,k))
            enddo
            egx(innx,j,k) = hxi*(temppotent(innx-1,j,k)- &
                                 temppotent(innx,j,k))
          enddo
        enddo

        !print*,"pass Ex:",myidx,myidy,yadd,zadd
        !Ey
        !egy = 0.0
        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then !periodic in theta, E_{theta}

        if(nproccol.gt.1) then
          do k = 1+zadd, innz-zadd
            do j = 1+yadd, inny-yadd
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi
            enddo
          enddo

        else

          do k = 1+zadd, innz-zadd
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi
            enddo
          enddo

          do k = 1+zadd, innz-zadd
            do i = 2, innx
              egy(i,1,k) = 0.5*hyi*(temppotent(i,inny-1,k) -  &
                           temppotent(i,2,k))*hxi/(i-1)
              egy(i,inny,k) = egy(i,1,k)
            enddo
            !egy(1,1,k) = 0.5*hyi*(temppotent(1,inny-1,k) -  &
            !               temppotent(1,2,k))*hxi
            egy(1,1,k) = 0.0
            egy(1,inny,k) = egy(1,1,k)
          enddo
        endif

        else  ! open in Y

        if(nproccol.gt.1) then 
          if(myidy.eq.0) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,yadd+1,k) = hyi*(temppotent(i,yadd+1,k)- &
                                       temppotent(i,yadd+2,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+2, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else if(myidy.eq.(nproccol-1)) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,inny-yadd,k) = hyi*(temppotent(i,inny-yadd-1,k)- &
                                          temppotent(i,inny-yadd,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd-1
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          endif
        else
          do k = zadd+1, innz-zadd
            do i = 1, innx
              egy(i,1,k) = hyi*(temppotent(i,1,k)-temppotent(i,2,k))
            enddo
            do j = 2, inny-1
              do i = 1, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                             temppotent(i,j+1,k))
              enddo
            enddo
            do i = 1, innx
              egy(i,inny,k) = hyi*(temppotent(i,inny-1,k)- &
                                   temppotent(i,inny,k))
            enddo
          enddo
        endif

        endif

!        print*,"pass Ey:",myidx,myidy,inny,innx,innz

        !Ez
        !egz = 0.0
        if(nprocrow.gt.1) then 
          ! 3D open,or z open
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then 
            if(myidx.eq.0) then
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,zadd+1) = hzi*(temppotent(i,j,zadd+1)- &
                                         temppotent(i,j,zadd+2))
                enddo
              enddo
              do k = zadd+2, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            else if(myidx.eq.(nprocrow-1)) then
              do k = zadd+1, innz-zadd-1
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,innz-zadd) = hzi*(temppotent(i,j,innz-zadd-1)- &
                                            temppotent(i,j,innz-zadd))
                enddo
              enddo
            else
              do k = zadd+1, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            endif
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                               temppotent(i,j,k+1))
                enddo
              enddo
            enddo
          else
            print*,"no such boundary condition!!!"
            stop
          endif
        else
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1) = hzi*(temppotent(i,j,1)-temppotent(i,j,2))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1)=0.5*hzi*(temppotent(i,j,innz-1)-temppotent(i,j,2))
              enddo
            enddo
          else
          endif
          do k = 2, innz-1
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                      temppotent(i,j,k+1))
              enddo
            enddo
          enddo
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,innz))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = 0.5*hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,2))
              enddo
            enddo
          else
          endif
        endif

        !Send the E field to the neibhoring guard grid to do the CIC
        !interpolation.
!        if(totnp.ne.1) then
          call boundint4_Fldmger(egx,egy,egz,innx,inny,innz,grid)
!        endif

        !!biaobin, output space charge field
        !open(2,file='zsc.txt')
        !do k=1,innz
        !    write(2,105)egx(16,16,k),egy(16,16,k),egz(16,16,k)
        !close(2)

        !open(3,file='xsc.txt')
        !do i=1,innx
        !  write(3,105)egx(i,16,32),egy(i,16,32),egz(i,16,32)
        !enddo
        !close(3)
 
        !105 format(3(2x,e13.7))

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"before scatter:"
        !endif

        gam = -this%refptcl(6)
        curr = this%Current
        mass = this%Mass
        innp = this%Nptlocal
        chrg = this%Charge

        twopi = 2.0*Pi
        tmpscale = curr/Scfreq
        fpei = Clight*Clight*1.0e-7
        xk = 1/Scxl
        bet = sqrt(gam**2-1.0)/gam
        bbyk = bet/xk
        gambet = gam*bet
        brho = gambet/(Clight*chrg)*mass
        vz0 = bet*Clight
        perv0 = 2.0*curr*fpei/(brho*vz0*vz0*gam*gam)
        xycon = 0.5*perv0*gambet*bbyk*twopi/tmpscale
        tcon = bet*xycon*gam**2

        !add the wakefield
        call getlctabnm_CompDom(ptsgeom,temptab)
        ztable(0:npx-1) = temptab(1,0:npx-1,0)
        zdisp(0) = 0
        do kz = 1, npx-1
          zdisp(kz) = zdisp(kz-1)+ztable(kz-1)
        enddo
        tmpscale = Clight*Clight*1.0e-7
        do kz = 1,innz
          kst = zdisp(myidx)+kz-zadd !get the global index
          if(kst.eq.0) then
            kst = 1
          else if(kst.eq.Nz+1) then
            kst = Nz
          else
          endif
          do jy = 1, inny
            do ix = 1, innx
              !divided by tmpscale for wakefield is due to the fact that
              !space-charge field will be multiplied by tmpscale inside
              !the scattering function
              egx(ix,jy,kz) = egx(ix,jy,kz) + chrg*exwake(kst)/xycon/mass/bet/gam
              egy(ix,jy,kz) = egy(ix,jy,kz) + chrg*eywake(kst)/xycon/mass/bet/gam
              egz(ix,jy,kz) = egz(ix,jy,kz) + chrg*ezwake(kst)/tcon/mass
            enddo
          enddo
        enddo

        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then
        else
          call scatter1_BeamBunch(innp,innx,inny,innz,this%Pts1,egx,egy,egz,&
          ptsgeom,nprocrow,nproccol,myidx,myidy,gam,curr,tau,mass,chrg,Flagsc)
        endif

1000    continue

        t_force = t_force + elapsedtime_Timer(t0)

        end subroutine kick1wake_BeamBunch

        subroutine kick2wake_BeamBunch(this,beamelem,z,tau,innx,inny,innz, &
                  temppotent,ptsgeom,grid,Flagbc,flagerr,&
                  exwake,eywake,ezwake,Nz,npx,npy)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        type (BeamLineElem), intent(in) :: beamelem
        integer, intent(in) :: innx,inny,innz,Flagbc,flagerr,Nz,npx,npy
        type (CompDom), intent(in) :: ptsgeom
        double precision,dimension(innx,inny,innz),intent(inout) :: temppotent
        type (Pgrid2d), intent(in) :: grid
        double precision, intent(in) :: z, tau
        double precision, dimension(Nz) :: exwake,eywake,ezwake
        double precision, dimension(innx,inny,innz) :: egx,egy,egz
        double precision, dimension(3) :: msize
        double precision :: hxi, hyi, hzi
        double precision :: t0,tg,chge,mass,curr,gam
        integer :: totnp,nproccol,nprocrow,myid,myidx,myidy
        integer :: i, j, k, yadd, zadd, innp
!        integer :: comm2d,commcol,commrow
        double precision, dimension(0:npx-1) :: ztable,zdisp
        integer, dimension(2,0:npx-1,0:npy-1) :: temptab
        integer :: ix,jy,kz,kst
        double precision :: tmpscale
        double precision, dimension(innz) :: exwakelc,eywakelc,ezwakelc

        call starttime_Timer(t0)

        call getsize_Pgrid2d(grid,totnp,nproccol,nprocrow)
        call getpost_Pgrid2d(grid,myid,myidy,myidx)
        if(nproccol.gt.1) then
          yadd = 1
        else
          yadd = 0
        endif
        if(nprocrow.gt.1) then
          zadd = 1
        else
          zadd = 0
        endif

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.16) then
        !  print*,"before guardexch:"
        !endif

        curr = this%Current
        innp = this%Nptlocal
        tg = this%refptcl(5)
        gam = -this%refptcl(6)
        mass = this%Mass
        chge = this%Charge

        if(curr.gt.0.0) then
!------------------------------------------------------------------
! current greater than 0
    
        ! Exchange potential information on guard grid cells.
        if((Flagbc.eq.1).or.(Flagbc.eq.5)) then ! 3D open 
          if(totnp.ne.1) then
            call guardexch1_Fldmger(temppotent,innx,inny,innz,grid)
          endif
        else
          print*,"no such boundary condition!!!!"
          stop
        endif

! cache optimization here.
        !print*,"yadd: ",yadd,zadd,innx,inny,innz,1.0/hxi,1.0/hyi,1.0/hzi
        !Ex
        !egx = 0.0
        do k = zadd+1, innz-zadd
          do j = yadd+1, inny-yadd
            egx(1,j,k) = hxi*(temppotent(1,j,k)-temppotent(2,j,k))
            do i = 2, innx-1
              egx(i,j,k) = 0.5*hxi*(temppotent(i-1,j,k)- &
                           temppotent(i+1,j,k))
            enddo
            egx(innx,j,k) = hxi*(temppotent(innx-1,j,k)- &
                                 temppotent(innx,j,k))
          enddo
        enddo

        !Ey
        !egy = 0.0
        if((Flagbc.eq.3).or.(Flagbc.eq.4)) then  ! periodic in theta

        if(nproccol.gt.1) then
          do k = 1, innz
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi

            enddo
          enddo
        else
          do k = 1, innz
            do j = 2, inny-1
              do i = 2, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k) -  &
                             temppotent(i,j+1,k))*hxi/(i-1)
              enddo
              egy(1,j,k) = 0.0
              !egy(1,j,k) = 0.5*hyi*(temppotent(1,j-1,k) -  &
              !               temppotent(1,j+1,k))*hxi
            enddo
          enddo
          do k = 1, innz
            do i = 2, innx
              egy(i,1,k) = 0.5*hyi*(temppotent(i,inny-1,k) -  &
                           temppotent(i,2,k))*hxi/(i-1)
              egy(i,inny,k) = egy(i,1,k)
            enddo
            egy(1,1,k) = 0.0
            !egy(1,1,k) = 0.5*hyi*(temppotent(1,inny-1,k) -  &
            !               temppotent(1,2,k))*hxi
            egy(1,inny,k) = 0.0
            !egy(1,inny,k) = egy(1,1,k)
          enddo
        endif

        else  ! open in Y

        if(nproccol.gt.1) then 
          if(myidy.eq.0) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,yadd+1,k) = hyi*(temppotent(i,yadd+1,k)- &
                                       temppotent(i,yadd+2,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+2, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else if(myidy.eq.(nproccol-1)) then
            do k = zadd+1, innz-zadd
              do i = 1, innx
                egy(i,inny-yadd,k) = hyi*(temppotent(i,inny-yadd-1,k)- &
                                          temppotent(i,inny-yadd,k))
              enddo
            enddo
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd-1
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          else
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                               temppotent(i,j+1,k))
                enddo
              enddo
            enddo
          endif
        else
          do k = zadd+1, innz-zadd
            do i = 1, innx
              egy(i,1,k) = hyi*(temppotent(i,1,k)-temppotent(i,2,k))
            enddo
            do j = 2, inny-1
              do i = 1, innx
                egy(i,j,k) = 0.5*hyi*(temppotent(i,j-1,k)- &
                             temppotent(i,j+1,k))
              enddo
            enddo
            do i = 1, innx
              egy(i,inny,k) = hyi*(temppotent(i,inny-1,k)- &
                                   temppotent(i,inny,k))
            enddo
          enddo
        endif

        endif

        !Ez
        !egz = 0.0
        if(nprocrow.gt.1) then 
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            if(myidx.eq.0) then
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,zadd+1) = hzi*(temppotent(i,j,zadd+1)- &
                                         temppotent(i,j,zadd+2))
                enddo
              enddo
              do k = zadd+2, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            else if(myidx.eq.(nprocrow-1)) then
              do k = zadd+1, innz-zadd-1
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,innz-zadd) = hzi*(temppotent(i,j,innz-zadd-1)- &
                                            temppotent(i,j,innz-zadd))
                enddo
              enddo
            else
              do k = zadd+1, innz-zadd
                do j = yadd+1, inny-yadd
                  do i = 1, innx
                    egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                 temppotent(i,j,k+1))
                  enddo
                enddo
              enddo
            endif
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do k = zadd+1, innz-zadd
              do j = yadd+1, inny-yadd
                do i = 1, innx
                  egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                               temppotent(i,j,k+1))
                enddo
              enddo
            enddo
          else
            print*,"no such boundary condition!!!"
            stop
          endif
        else
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then ! 3D open
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1) = hzi*(temppotent(i,j,1)-temppotent(i,j,2))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then 
          ! 2D open, 1D periodic
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,1)=0.5*hzi*(temppotent(i,j,innz-1)-temppotent(i,j,2))
              enddo
            enddo
          else
          endif
          do k = 2, innz-1
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,k) = 0.5*hzi*(temppotent(i,j,k-1)- &
                                      temppotent(i,j,k+1))
              enddo
            enddo
          enddo
          if((Flagbc.eq.1).or.(Flagbc.eq.3).or.(Flagbc.eq.5)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,innz))
              enddo
            enddo
          else if((Flagbc.eq.2).or.(Flagbc.eq.4).or.(Flagbc.eq.6)) then
            do j = yadd+1, inny-yadd
              do i = 1, innx
                egz(i,j,innz) = 0.5*hzi*(temppotent(i,j,innz-1)- &
                                     temppotent(i,j,2))
              enddo
            enddo
          else
          endif
        endif

        ! find field from potential.
!        egx = 0.5*hxi*(cshift(temppotent,-1,1) -  &
!                       cshift(temppotent,1,1))
!        egy = 0.5*hyi*(cshift(temppotent,-1,2) -  &
!                       cshift(temppotent,1,2))
!        egz = 0.5*hzi*(cshift(temppotent,-1,3) -  &
!                      cshift(temppotent,1,3))

!        if(totnp.eq.1) then
!          egz(:,:,2) = 0.5*hzi*(temppotent(:,:,innz-1)-&
!                                temppotent(:,:,3))
!          egz(:,:,innz-1) = 0.5*hzi*(temppotent(:,:,innz-2)-&
!                                temppotent(:,:,2))
!          egy(:,2,:) = 0.5*hyi*(temppotent(:,inny-1,:)-&
!                                temppotent(:,3,:))
!          egy(:,inny-1,:) = 0.5*hyi*(temppotent(:,inny-2,:)-&
!                                temppotent(:,2,:))
!        endif

        !Send the E field to the neibhoring guard grid to do the CIC
        !interpolation.
        if(totnp.ne.1) then
          call boundint4_Fldmger(egx,egy,egz,innx,inny,innz,grid)
        endif

        !add the wakefield 
        call getlctabnm_CompDom(ptsgeom,temptab)
        ztable(0:npx-1) = temptab(1,0:npx-1,0)
        zdisp(0) = 0
        do kz = 1, npx-1
          zdisp(kz) = zdisp(kz-1)+ztable(kz-1)
        enddo
        tmpscale = Clight*Clight*1.0e-7
        do kz = 1,innz
          kst = zdisp(myidx)+kz-zadd !get the global index
          if(kst.eq.0) then
            kst = 1
          else if(kst.eq.Nz+1) then
            kst = Nz
          else
          endif
          !divided by tmpscale for wakefield is due to the fact that
          !space-charge field will be multiplied by tmpscale inside
          !the scattering function
          exwakelc(kz) =  exwake(kst)
          eywakelc(kz) =  eywake(kst)
          ezwakelc(kz) =  ezwake(kst)
        enddo
          call scatter2wake_BeamBunch(innp,innx,inny,innz,this%Pts1,egx,egy,egz,&
          ptsgeom,nprocrow,nproccol,myidx,myidy,tg,gam,curr,chge,mass,tau,z,&
          beamelem,exwakelc,eywakelc,ezwakelc)

        else
!------------------------------------------------------------------
! current is 0
            call scatter20_BeamBunch(innp,this%Pts1,tg,gam,chge,mass,tau,z,&
                                     beamelem)
        endif

        this%refptcl(6) = -gam

        !call MPI_BARRIER(comm2d,ierr)
        !if(myid.eq.0) then
        !  print*,"after kick:"
        !endif

        t_force = t_force + elapsedtime_Timer(t0)

        end subroutine kick2wake_BeamBunch

        subroutine scatter2wake_BeamBunch(innp,innx,inny,innz,rays,exg,&
        eyg,ezg,ptsgeom,npx,npy,myidx,myidy,tg,gam,curr,chge,mass,tau,z,&
        beamelem,exwakelc,eywakelc,ezwakelc)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (in), dimension (innx,inny,innz) :: exg,eyg,ezg 
        double precision, intent (in) :: curr,tau,mass,chge,tg,z
        double precision, dimension(innz) :: exwakelc,eywakelc,ezwakelc
        double precision, intent (inout) :: gam
        integer, intent(in) :: innp,innx,inny,innz,npx,npy,myidx,myidy
        type (BeamLineElem), intent(in) :: beamelem
        integer, dimension(2,0:npx-1,0:npy-1) :: table
        integer, dimension(0:npx-1) :: xtable
        integer, dimension(0:npy-1) :: ytable
        double precision :: ab, cd, ef
        integer :: n,i,ii
        double precision :: t0
        double precision :: hx,hxi,hy,hyi,hz,hzi,xmin,ymin,zmin
        double precision, dimension(3) :: msize
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: range, extfld
        type (CompDom) :: ptsgeom
        integer :: ix,jx,kx,ix1,jx1,kx1,ierr,kadd,jadd
        double precision :: twopi,xk,xl,bfreq,tmpscale,tmpgamma0,tmpgamma00,&
        beta0,qmcc,rcpgammai,betai,ez0,tmp1,tmp2,tmp3,tmp4,tmp5,tmp12,tmp23,&
        tmp13,pz,p1,p2,p3,a12,a13,a23,b1,b2,b3,s11,s12,s13,s21,s22,s23,&
        s31,s32,s33,det,tmpsq2,exn,eyn,ezn,ex,ey,ez,bx,by,bz
        double precision, dimension(6,NrIntvRf+1) :: extfld6
        double precision :: rr,hr,hri,mu0,te,tb,escale,rffreq,theta0,efr,&
                            er,btheta,ww,et,bt
        integer :: ir,ir1,FlagCart,FlagDisc
        !3D Cartesian coordinate.
        double precision,dimension(6,NxIntvRfg+1,NyIntvRfg+1)::extfld6xyz
        double precision :: xx,yy,hxx,hyy,hxxi,hyyi,efx,efy
        integer :: iy,iy1
        double precision :: exnwk,eynwk,eznwk

        call starttime_Timer( t0 )

        twopi = 2.0*Pi
        xk = 1/Scxl
        xl = Scxl
        bfreq = Scfreq
        !tmpscale = Clight*Clight*1.0e-7*curr/bfreq*chge
        tmpscale = Clight*Clight*1.0e-7 !curr*chge/bfreq are included in the charge density
        beta0 = sqrt(gam**2-1.0)/gam
        qmcc = chge/mass

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)
        hx = msize(1)
        hy = msize(2)
        hz = msize(3)

        call getrange_CompDom(ptsgeom,range)
        xmin = range(1)
        ymin = range(3)
        zmin = range(5)

        call getlctabnm_CompDom(ptsgeom,table)
        xtable(0) = 0
        do i = 1, npx - 1
          xtable(i) = xtable(i-1) + table(1,i-1,0)
        enddo

        ytable(0) = 0
        do i = 1, npy - 1
          ytable(i) = ytable(i-1) + table(2,0,i-1)
        enddo

        if(npx.gt.1) then
          kadd = -xtable(myidx) + 1
        else
          kadd = 0
        endif
        if(npy.gt.1) then
          jadd = -ytable(myidy) + 1
        else
          jadd = 0
        endif

        FlagDisc = 0
        FlagCart = 1
        if(associated(beamelem%pemfld)) then
          escale=beamelem%pemfld%Param(2)
          rffreq=beamelem%pemfld%Param(3)
          ww = rffreq/Scfreq
          theta0=beamelem%pemfld%Param(4)*asin(1.0)/90
          FlagDisc = 0.1+beamelem%pemfld%Param(13)
          FlagCart = 0.1+beamelem%pemfld%Param(14)

          if(FlagDisc.eq.1) then
            if(FlagCart.eq.1) then
              call getfld6_EMfld(beamelem%pemfld,z,extfld6)
              et = escale*cos(ww*tg+theta0)
              ez0 = extfld6(3,1)*et
              hr = (RmaxRf-RminRf)/NrIntvRf
              hri = 1.0/hr
            else if(FlagCart.eq.2) then
              call getfld6xyz_EMfld(beamelem%pemfld,z,extfld6xyz)
              hxx = (XmaxRfg-XminRfg)/NxIntvRfg
              hyy = (YmaxRfg-YminRfg)/NyIntvRfg
              hxxi = 1.0/hxx
              hyyi = 1.0/hyy
              xx = 0.0
              yy = 0.0
              ix = (xx-XminRfg)/hxx + 1
              ix1 = ix+1
              efx = (XminRfg-xx+ix*hxx)/hxx
              iy = (yy-YminRfg)/hyy + 1
              iy1 = iy+1
              efy = (YminRfg-yy+iy*hyy)/hyy
              ezn = extfld6xyz(3,ix,iy)*efx*efy + &
                    extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                    extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                    extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy)
              et = escale*cos(ww*tg+theta0)
              ez0 = ezn*et
            endif
          else if(FlagDisc.eq.2) then
            pos(1) = 0.0
            pos(2) = 0.0
            pos(3) = z
            pos(4) = tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
            ez0 = extfld(3)
            if(FlagCart.eq.1) then
              call getfld6_EMfld(beamelem%pemfld,z,extfld6)
              et = escale*cos(ww*tg+theta0)
              ez0 = ez0 + extfld6(3,1)*et
              hr = (RmaxRf-RminRf)/NrIntvRf
              hri = 1.0/hr
            else if(FlagCart.eq.2) then
              call getfld6xyz_EMfld(beamelem%pemfld,z,extfld6xyz)
              hxx = (XmaxRfg-XminRfg)/NxIntvRfg
              hyy = (YmaxRfg-YminRfg)/NyIntvRfg
              hxxi = 1.0/hxx
              hyyi = 1.0/hyy
              xx = 0.0
              yy = 0.0
              ix = (xx-XminRfg)/hxx + 1
              ix1 = ix+1
              efx = (XminRfg-xx+ix*hxx)/hxx
              iy = (yy-YminRfg)/hyy + 1
              iy1 = iy+1
              efy = (YminRfg-yy+iy*hyy)/hyy
              ezn = extfld6xyz(3,ix,iy)*efx*efy + &
                    extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                    extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                    extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy)
              et = escale*cos(ww*tg+theta0)
              ez0 = ez0 + ezn*et
            endif
          else
            pos(1) = 0.0
            pos(2) = 0.0
            pos(3) = z
            pos(4) = tg
            call getfld_BeamLineElem(beamelem,pos,extfld)
            ez0 = extfld(3)
          endif
        else
          pos(1) = 0.0
          pos(2) = 0.0
          pos(3) = z
          pos(4) = tg
          call getfld_BeamLineElem(beamelem,pos,extfld)
          ez0 = extfld(3)
        endif

        tmpgamma0 = gam + 0.5*tau*qmcc*ez0

        do n = 1, innp
          ix=(rays(1,n)-xmin)*hxi + 1
          ab=((xmin-rays(1,n))+ix*hx)*hxi
          jx=(rays(3,n)-ymin)*hyi + 1 + jadd
          cd=((ymin-rays(3,n))+(jx-jadd)*hy)*hyi
          kx=(rays(5,n)-zmin)*hzi + 1 + kadd
          ef=((zmin-rays(5,n))+(kx-kadd)*hz)*hzi

          ix1 = ix + 1
          jx1 = jx + 1
          kx1 = kx + 1

          exn = (exg(ix,jx,kx)*ab*cd*ef  &
                  +exg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +exg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +exg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +exg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +exg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +exg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +exg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          eyn = (eyg(ix,jx,kx)*ab*cd*ef  &
                  +eyg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +eyg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +eyg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +eyg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +eyg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +eyg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +eyg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          ezn = ezg(ix,jx,kx)*ab*cd*ef  &
                  +ezg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +ezg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +ezg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +ezg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +ezg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +ezg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +ezg(ix1,jx,kx)*(1.0-ab)*cd*ef

          exnwk = exwakelc(kx)*ef+exwakelc(kx1)*(1.0-ef)
          eynwk = eywakelc(kx)*ef+eywakelc(kx1)*(1.0-ef)
          eznwk = ezwakelc(kx)*ef+ezwakelc(kx1)*(1.0-ef)

          !Linear algorithm to transfer back from t to z.
          rcpgammai = 1.0/(-rays(6,n)+gam)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+rays(2,n)**2+ &
                                                rays(4,n)**2) )
          rays(5,n) = rays(5,n)*xk/(-gam*betai)
          rays(1,n) = rays(1,n)*xk
          rays(3,n) = rays(3,n)*xk

          if(FlagDisc.eq.1) then !use discrete data only
              !calculate field in Cartesian coordinate from the discrete
              !field function (r) in cylindrical coordinate
              et = escale*cos(ww*(tg+rays(5,n))+theta0)
              bt = escale*sin(ww*(tg+rays(5,n))+theta0)
              if(FlagCart.eq.1) then
                rr = sqrt(rays(1,n)*rays(1,n)+rays(3,n)*rays(3,n))*xl
                ir = rr*hri + 1
                if(ir.eq.NrIntvRf) ir=ir-1
                ir1 = ir+1
                efr = (ir*hr - rr)*hri
                er = (extfld6(1,ir)*efr+extfld6(1,ir1)*(1.0-efr))*et
                extfld(1) = er*rays(1,n)*xl/rr
                extfld(2) = er*rays(3,n)*xl/rr
                extfld(3) = (extfld6(3,ir)*efr+extfld6(3,ir1)*(1.0-efr))*et
                btheta = (extfld6(5,ir)*efr+extfld6(5,ir1)*(1.0-efr))*bt
                extfld(4) = -btheta*rays(3,n)*xl/rr
                extfld(5) = btheta*rays(1,n)*xl/rr
                extfld(6) = 0.0
              else if(FlagCart.eq.2) then
                xx = rays(1,n)*xl
                yy = rays(3,n)*xl
                ix = (xx-XminRfg)*hxxi + 1
                ix1 = ix+1
                efx = (XminRfg-xx+ix*hxx)*hxxi
                iy = (yy-YminRfg)*hyyi + 1
                iy1 = iy+1
                efy = (YminRfg-yy+iy*hyy)*hyyi
                extfld(1) = (extfld6xyz(1,ix,iy)*efx*efy + &
                      extfld6xyz(1,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(1,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(1,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(2) = (extfld6xyz(2,ix,iy)*efx*efy + &
                      extfld6xyz(2,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(2,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(2,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(3) = (extfld6xyz(3,ix,iy)*efx*efy + &
                      extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(4) = (extfld6xyz(4,ix,iy)*efx*efy + &
                      extfld6xyz(4,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(4,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(4,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(5) = (extfld6xyz(5,ix,iy)*efx*efy + &
                      extfld6xyz(5,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(5,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(5,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(6) = (extfld6xyz(6,ix,iy)*efx*efy + &
                      extfld6xyz(6,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(6,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(6,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
              endif
          !use both analytical function and discrete data.
          else if(FlagDisc.eq.2) then
              pos(1) = rays(1,n)*xl
              pos(2) = rays(3,n)*xl
              pos(3) = z
              pos(4) = rays(5,n) + tg
              !get field in Cartesian coordinate from analytical function.
              call getfld_BeamLineElem(beamelem,pos,extfld)
              !calculate field in Cartesian coordinate from the discrete
              !field function (r) in cylindrical coordinate
              et = escale*cos(ww*(tg+rays(5,n))+theta0)
              bt = escale*sin(ww*(tg+rays(5,n))+theta0)
              if(FlagCart.eq.1) then
                rr = sqrt(rays(1,n)*rays(1,n)+rays(3,n)*rays(3,n))*xl
                ir = rr*hri + 1
                if(ir.eq.NrIntvRf) ir=ir-1
                ir1 = ir+1
                efr = (ir*hr - rr)*hri
                er = (extfld6(1,ir)*efr+extfld6(1,ir1)*(1.0-efr))*et
                extfld(1) = extfld(1) + er*rays(1,n)*xl/rr
                extfld(2) = extfld(2) + er*rays(3,n)*xl/rr
                extfld(3) = extfld(3) + &
                            (extfld6(3,ir)*efr+extfld6(3,ir1)*(1.0-efr))*et
                btheta = (extfld6(5,ir)*efr+extfld6(5,ir1)*(1.0-efr))*bt
                extfld(4) = extfld(4) - btheta*rays(3,n)*xl/rr
                extfld(5) = extfld(5) + btheta*rays(1,n)*xl/rr
!                extfld(6) = extfld(6)
              else if(FlagCart.eq.2) then
                xx = rays(1,n)*xl
                yy = rays(3,n)*xl
                ix = (xx-XminRfg)*hxxi + 1
                ix1 = ix+1
                efx = (XminRfg-xx+ix*hxx)*hxxi
                iy = (yy-YminRfg)*hyyi + 1
                iy1 = iy+1
                efy = (YminRfg-yy+iy*hyy)*hyyi
                extfld(1) = (extfld6xyz(1,ix,iy)*efx*efy + &
                      extfld6xyz(1,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(1,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(1,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(2) = (extfld6xyz(2,ix,iy)*efx*efy + &
                      extfld6xyz(2,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(2,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(2,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(3) = (extfld6xyz(3,ix,iy)*efx*efy + &
                      extfld6xyz(3,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(3,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(3,ix1,iy1)*(1.0-efx)*(1.0-efy))*et
                extfld(4) = (extfld6xyz(4,ix,iy)*efx*efy + &
                      extfld6xyz(4,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(4,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(4,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(5) = (extfld6xyz(5,ix,iy)*efx*efy + &
                      extfld6xyz(5,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(5,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(5,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
                extfld(6) = (extfld6xyz(6,ix,iy)*efx*efy + &
                      extfld6xyz(6,ix,iy1)*efx*(1.0-efy) + &
                      extfld6xyz(6,ix1,iy)*(1.0-efx)*efy + &
                      extfld6xyz(6,ix1,iy1)*(1.0-efx)*(1.0-efy))*bt
              endif
          else !use analytical function data only
              !get field in Cartesian coordinate from analytical function.
              pos(1) = rays(1,n)*xl
              pos(2) = rays(3,n)*xl
              pos(3) = z
              pos(4) = rays(5,n) + tg
              call getfld_BeamLineElem(beamelem,pos,extfld)
          endif

          ex = tmpscale*exn+extfld(1) + exnwk
          ey = tmpscale*eyn+extfld(2) + eynwk
          ez = tmpscale*ezn+extfld(3) + eznwk
          bx = -beta0/Clight*tmpscale*eyn+extfld(4)
          by = beta0/Clight*tmpscale*exn+extfld(5)
          bz = extfld(6)
          tmp12 = -tau*Clight*bz*rays(7,n)/2
          tmp13 = tau*ex*rays(7,n)/2
          tmp23 = tau*ey*rays(7,n)/2
          tmp1 = tmpgamma0*ex*tau*rays(7,n)
          tmp2 = Clight*by*tau*rays(7,n)
          tmp3 = tmpgamma0*ey*tau*rays(7,n)
          tmp4 = Clight*bx*tau*rays(7,n)
!          tmp5 = (ez0-ez)*tau*rays(7,n)
          !for multi-charge state, qmcc not equal to rays(7,n)
          tmp5 = (ez0*qmcc-ez*rays(7,n))*tau
          pz = sqrt((gam-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2)
          p1 = rays(2,n)
          p2 = rays(4,n)
          p3 = rays(6,n)
          do ii = 1, 2
            a12 = tmp12/pz
            a13 = tmp13/pz
            a23 = tmp23/pz
            b1 = p1-a12*p2-a13*p3+tmp1/pz - tmp2
            b2 = a12*p1+p2-a23*p3+tmp3/pz + tmp4
            b3 = -a13*p1-a23*p2+p3 + tmp5
            det = 1+a12*a12-a13*a13-a23*a23
            s11 = 1-a23*a23
            s12 = -a12+a13*a23
            s13 = a12*a23-a13
            s21 = a12+a13*a23
            s22 = 1-a13*a13
            s23 = -a23-a13*a12
            s31 = -a12*a23-a13
            s32 = -a23+a12*a13
            s33 = 1+a12*a12
            rays(2,n) = (s11*b1+s12*b2+s13*b3)/det
            rays(4,n) = (s21*b1+s22*b2+s23*b3)/det
            rays(6,n) = (s31*b1+s32*b2+s33*b3)/det
            tmpgamma00 = gam + tau*qmcc*ez0
            tmpsq2 = (tmpgamma00-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2
            if(tmpsq2.gt.0.0) then
              pz = 0.5*pz + 0.5*sqrt(tmpsq2)
            endif
          enddo
        enddo
        gam = gam + tau*qmcc*ez0

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

!----------------------------------------------------------------
        end subroutine scatter2wake_BeamBunch

        subroutine scatter2errwake_BeamBunch(innp,innx,inny,innz,rays,exg,&
        eyg,ezg,ptsgeom,npx,npy,myidx,myidy,tg,gam,curr,chge,mass,tau,z,&
        beamelem,exwakelc,eywakelc,ezwakelc)
        implicit none
        include 'mpif.h'
        double precision, intent (inout), dimension (9,innp) :: rays
        double precision, intent (in), dimension (innx,inny,innz) :: exg,eyg,ezg 
        double precision, intent (in) :: curr,tau,mass,chge,tg,z
        double precision, dimension(innz) :: exwakelc,eywakelc,ezwakelc
        double precision, intent (inout) :: gam
        integer, intent(in) :: innp,innx,inny,innz,npx,npy,myidx,myidy
        type (BeamLineElem), intent(in) :: beamelem
        integer, dimension(2,0:npx-1,0:npy-1) :: table
        integer, dimension(0:npx-1) :: xtable
        integer, dimension(0:npy-1) :: ytable
        double precision :: ab, cd, ef
        integer :: n,i,ii
        double precision :: t0
        double precision :: hx,hxi,hy,hyi,hz,hzi,xmin,ymin,zmin
        double precision, dimension(3) :: msize
        double precision, dimension(4) :: pos
        double precision, dimension(6) :: range, extfld
        type (CompDom) :: ptsgeom
        integer :: ix,jx,kx,ix1,jx1,kx1,ierr,kadd,jadd
        double precision :: twopi,xk,xl,bfreq,tmpscale,tmpgamma0,tmpgamma00,&
        beta0,qmcc,rcpgammai,betai,ez0,tmp1,tmp2,tmp3,tmp4,tmp5,tmp12,tmp23,&
        tmp13,pz,p1,p2,p3,a12,a13,a23,b1,b2,b3,s11,s12,s13,s21,s22,s23,&
        s31,s32,s33,det,tmpsq2,exn,eyn,ezn,ex,ey,ez,bx,by,bz
        double precision, dimension(6) :: extfld6
        double precision :: rr,hr,hri,mu0,te,tb,escale,rffreq,theta0,efr,&
                            er,btheta,ww,et,bt
        integer :: ir,ir1,FlagCart,FlagDisc
        double precision :: dx,dy,anglex,angley,anglez
        double precision :: exnwk,eynwk,eznwk

        call starttime_Timer( t0 )

        twopi = 2.0*Pi
        xk = 1/Scxl
        xl = Scxl
        bfreq = Scfreq
        !tmpscale = Clight*Clight*1.0e-7*curr/bfreq*chge
        tmpscale = Clight*Clight*1.0e-7
        beta0 = sqrt(gam**2-1.0)/gam
        qmcc = chge/mass

        call getmsize_CompDom(ptsgeom,msize)
        hxi = 1.0/msize(1)
        hyi = 1.0/msize(2)
        hzi = 1.0/msize(3)
        hx = msize(1)
        hy = msize(2)
        hz = msize(3)

        call getrange_CompDom(ptsgeom,range)
        xmin = range(1)
        ymin = range(3)
        zmin = range(5)

        call getlctabnm_CompDom(ptsgeom,table)
        xtable(0) = 0
        do i = 1, npx - 1
          xtable(i) = xtable(i-1) + table(1,i-1,0)
        enddo

        ytable(0) = 0
        do i = 1, npy - 1
          ytable(i) = ytable(i-1) + table(2,0,i-1)
        enddo

        if(npx.gt.1) then
          kadd = -xtable(myidx) + 1
        else
          kadd = 0
        endif
        if(npy.gt.1) then
          jadd = -ytable(myidy) + 1
        else
          jadd = 0
        endif

        call geterr_BeamLineElem(beamelem,dx,dy,anglex,angley,anglez)

        FlagDisc = 0
        FlagCart = 1
        if(associated(beamelem%pemfld)) then
          FlagDisc = 0.1+beamelem%pemfld%Param(13)
          FlagCart = 0.1+beamelem%pemfld%Param(14)

          pos(1) = 0.0
          pos(2) = 0.0
          pos(3) = z
          pos(4) = tg
          if(FlagDisc.eq.1) then
            if(FlagCart.eq.1) then 
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
              ez0 = extfld6(3)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
              ez0 = extfld6(3)
            endif
          else if(FlagDisc.eq.2) then
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
            ez0 = extfld(3)
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
              ez0 = ez0 + extfld6(3)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
              ez0 = ez0 + extfld6(3)
            endif
          else
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
            ez0 = extfld(3)
          endif
        else
          pos(1) = 0.0
          pos(2) = 0.0
          pos(3) = z
          pos(4) = tg
          call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                       angley,anglez)
          ez0 = extfld(3)
        endif

        tmpgamma0 = gam + 0.5*tau*qmcc*ez0

        do n = 1, innp
          ix=(rays(1,n)-xmin)*hxi + 1
          ab=((xmin-rays(1,n))+ix*hx)*hxi
          jx=(rays(3,n)-ymin)*hyi + 1 + jadd
          cd=((ymin-rays(3,n))+(jx-jadd)*hy)*hyi
          kx=(rays(5,n)-zmin)*hzi + 1 + kadd
          ef=((zmin-rays(5,n))+(kx-kadd)*hz)*hzi

          ix1 = ix + 1
          jx1 = jx + 1
          kx1 = kx + 1

          exn = (exg(ix,jx,kx)*ab*cd*ef  &
                  +exg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +exg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +exg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +exg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +exg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +exg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +exg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          eyn = (eyg(ix,jx,kx)*ab*cd*ef  &
                  +eyg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +eyg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +eyg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +eyg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +eyg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +eyg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +eyg(ix1,jx,kx)*(1.0-ab)*cd*ef)*gam 

          ezn = ezg(ix,jx,kx)*ab*cd*ef  &
                  +ezg(ix,jx1,kx)*ab*(1.-cd)*ef &
                  +ezg(ix,jx1,kx1)*ab*(1.-cd)*(1.0-ef) &
                  +ezg(ix,jx,kx1)*ab*cd*(1.0-ef) &
                  +ezg(ix1,jx,kx1)*(1.0-ab)*cd*(1.0-ef) &
                  +ezg(ix1,jx1,kx1)*(1.0-ab)*(1.0-cd)*(1.0-ef)&
                  +ezg(ix1,jx1,kx)*(1.0-ab)*(1.0-cd)*ef &
                  +ezg(ix1,jx,kx)*(1.0-ab)*cd*ef

          exnwk = exwakelc(kx)*ef+exwakelc(kx1)*(1.0-ef)
          eynwk = eywakelc(kx)*ef+eywakelc(kx1)*(1.0-ef)
          eznwk = ezwakelc(kx)*ef+ezwakelc(kx1)*(1.0-ef)

          !Linear algorithm to transfer back from t to z.
          rcpgammai = 1.0/(-rays(6,n)+gam)
          betai = sqrt(1.0-rcpgammai*rcpgammai*(1+rays(2,n)**2+ &
                                                rays(4,n)**2) )
          rays(5,n) = rays(5,n)*xk/(-gam*betai)
          rays(1,n) = rays(1,n)*xk
          rays(3,n) = rays(3,n)*xk

          pos(1) = rays(1,n)*xl
          pos(2) = rays(3,n)*xl
          pos(3) = z
          pos(4) = rays(5,n) + tg

          if(FlagDisc.eq.1) then !use discrete data only
            !calculate field in Cartesian coordinate from the discrete
            !field function (r) in cylindrical coordinate
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld,dx,dy,anglex,&
                                  angley,anglez)
            else if(FlagCart.eq.2) then ! in Cartesian coordinate
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld,dx,dy,anglex,&
                                  angley,anglez)
            endif
          !use both analytical function and discrete data.
          else if(FlagDisc.eq.2) then
            !get field in Cartesian coordinate from analytical function.
            call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                        angley,anglez)
            !calculate field in Cartesian coordinate from the discrete
            !field function (r) in cylindrical coordinate
            if(FlagCart.eq.1) then
              call getfld6err_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            else if(FlagCart.eq.2) then
              call getfld6xyzerr_EMfld(beamelem%pemfld,pos,extfld6,dx,dy,anglex,&
                                  angley,anglez)
            endif
            extfld = extfld + extfld6
          else !use analytical function data only
              !get field in Cartesian coordinate from analytical function.
              call getflderr_BeamLineElem(beamelem,pos,extfld,dx,dy,anglex,&
                                          angley,anglez)
          endif

          ex = tmpscale*exn+extfld(1) + exnwk
          ey = tmpscale*eyn+extfld(2) + eynwk
          ez = tmpscale*ezn+extfld(3) + eznwk
          bx = -beta0/Clight*tmpscale*eyn+extfld(4)
          by = beta0/Clight*tmpscale*exn+extfld(5)
          bz = extfld(6)
          tmp12 = -tau*Clight*bz*rays(7,n)/2
          tmp13 = tau*ex*rays(7,n)/2
          tmp23 = tau*ey*rays(7,n)/2
          tmp1 = tmpgamma0*ex*tau*rays(7,n)
          tmp2 = Clight*by*tau*rays(7,n)
          tmp3 = tmpgamma0*ey*tau*rays(7,n)
          tmp4 = Clight*bx*tau*rays(7,n)
!          tmp5 = (ez0-ez)*tau*rays(7,n)
          !for multi-charge state, qmcc not equal to rays(7,n)
          tmp5 = (ez0*qmcc-ez*rays(7,n))*tau
          pz = sqrt((gam-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2)
          p1 = rays(2,n)
          p2 = rays(4,n)
          p3 = rays(6,n)
          do ii = 1, 2
            a12 = tmp12/pz
            a13 = tmp13/pz
            a23 = tmp23/pz
            b1 = p1-a12*p2-a13*p3+tmp1/pz - tmp2
            b2 = a12*p1+p2-a23*p3+tmp3/pz + tmp4
            b3 = -a13*p1-a23*p2+p3 + tmp5
            det = 1+a12*a12-a13*a13-a23*a23
            s11 = 1-a23*a23
            s12 = -a12+a13*a23
            s13 = a12*a23-a13
            s21 = a12+a13*a23
            s22 = 1-a13*a13
            s23 = -a23-a13*a12
            s31 = -a12*a23-a13
            s32 = -a23+a12*a13
            s33 = 1+a12*a12
            rays(2,n) = (s11*b1+s12*b2+s13*b3)/det
            rays(4,n) = (s21*b1+s22*b2+s23*b3)/det
            rays(6,n) = (s31*b1+s32*b2+s33*b3)/det
            tmpgamma00 = gam + tau*qmcc*ez0
            tmpsq2 = (tmpgamma00-rays(6,n))**2-1.0-rays(2,n)**2-rays(4,n)**2
            if(tmpsq2.gt.0.0) then
              pz = 0.5*pz + 0.5*sqrt(tmpsq2)
            endif
          enddo
        enddo
        gam = gam + tau*qmcc*ez0

        t_ntrslo = t_ntrslo + elapsedtime_Timer( t0 )

        end subroutine scatter2errwake_BeamBunch

! ================================================================================
        subroutine idealrf_nonlinearmap(this,drange,tau,nseg,nst,ihlf,&
                   Lc,simutype)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        real*8, dimension(12), intent(in) :: drange
        double precision, intent (in) :: tau,Lc
        integer, intent(in) :: nseg,nst,simutype
        integer, intent(inout) :: ihlf
        integer :: i
        real*8 :: vtmp,vtmpgrad,phi0lc,phi,&
                  fact,harm,cosphi
        real*8 :: gam0,gam,gambet,gambetz
        real*8 :: gami_1,gambeti_1,gambetzi_1,dgami
        real*8 :: gami_2,gambeti_2
        !reference bet at entrance and exit
        real*8 :: bet0,bet1
        real*8 :: w0,ws

        !print*,"nonlinear map for ideal cavity."

        !scale freq
        ws = 2*Pi*Scfreq

        !drange(2), max. accelerating gradient (V/m)
        vtmp = drange(2)/this%Mass
        harm = drange(3)/Scfreq   !Scfreq, i.e. scaling frequency in
                                  !line11 of ImpactZ.in
        !synchronous phase
        phi0lc = drange(4)*asin(1.0d0)/90

        !apply entrance focusing kick
        if(nst.eq.1 .and. mod(ihlf,2).eq.0) then
          gam0 = -this%refptcl(6)
          gambet = sqrt(gam0**2-1.0d0)
          do i = 1, this%Nptlocal
            gam = gam0 - this%Pts1(6,i)
            gambetz = sqrt(gam**2-1.0d0-this%Pts1(2,i)**2-this%Pts1(4,i)**2)
            phi = this%Pts1(5,i)*harm+phi0lc
            cosphi = cos(phi)
            vtmpgrad = vtmp*cosphi*Scxl
            if(abs(drange(5)+1.0)<1.0d-6) then
                !print*,"end focus for nonlinear rf map."
                this%Pts1(2,i) = this%Pts1(2,i)  &
                             -0.5d0*vtmpgrad*gambetz/gam*this%Pts1(1,i)
                this%Pts1(4,i) = this%Pts1(4,i)  &
                             -0.5d0*vtmpgrad*gambetz/gam*this%Pts1(3,i)
            else if(abs(drange(5)+0.75)<1.0d-6) then
                !print*,"comment end focus for nonlinear cavity map."
            end if
          enddo
        endif
        !drift under constant acceleration, using individual
        !particle momentum to propagate particles
        gam0 = -this%refptcl(6)
        gambet = sqrt(gam0**2-1.0d0)
        bet0 = sqrt(1.0d0-1.0d0/gam0**2)

        if (simutype.eq.1) then
          w0 = ws !linac simulation, harm refers to fs, thus fs should be fRF
        else if (simutype.eq.2) then
          !biaobin, for ring, harm refers to evo freq
          !evolution freq at entrance 
          w0 = 2*Pi*bet0*Clight/Lc
        else 
          print*,"Unknown simutype=",simutype, &
                 ". should be Linac or Ring."
          stop
        end if
        do i = 1, this%Nptlocal
          !entrance momentum of individual particle
          gami_1 = gam0 - this%Pts1(6,i)
          gambeti_1 = sqrt(gami_1**2-1.0d0)
          gambetzi_1 = sqrt(gami_1**2-1.0d0-this%Pts1(2,i)**2-this%Pts1(4,i)**2)
          !exit momentum of individual particle
          phi = this%Pts1(5,i)*harm+phi0lc
          dgami = tau*vtmp*cos(phi)
          gami_2 = gami_1+dgami
          gambeti_2 = sqrt(gami_2**2-1.0d0)

          if(abs(vtmp).lt.1.0d-6) then
            fact = tau/Scxl
          else
            fact = gambeti_1/dgami*dlog(gambeti_2/gambeti_1)*tau/Scxl
          endif

          this%Pts1(1,i) = this%Pts1(1,i) + fact*&
                           this%Pts1(2,i)/gambetzi_1
          this%Pts1(3,i) = this%Pts1(3,i) + fact*&
                           this%Pts1(4,i)/gambetzi_1
          !longitudinal direction same as linear map for drift                 
          this%Pts1(5,i) = this%Pts1(5,i) + (tau/Scxl)/gambet**3*&
                                            this%Pts1(6,i)
        enddo

        !update the reference particle energy
        this%refptcl(6) = this%refptcl(6) - tau*vtmp*cos(phi0lc)
        gam0 = -this%refptcl(6)
        bet1 = sqrt(1.0d0-1.0d0/gam0**2)

        !apply exit focusing kick
        if(nst.eq.nseg .and. mod(ihlf,2).eq.1) then
          do i = 1, this%Nptlocal
            gam = gam0 - this%Pts1(6,i)
            gambetz = sqrt(gam**2-1.0d0-this%Pts1(2,i)**2-this%Pts1(4,i)**2)
            phi = this%Pts1(5,i)*harm+phi0lc
            cosphi = cos(phi)
            vtmpgrad = vtmp*cosphi*Scxl
            if(abs(drange(5)+1.0)<1.0d-6) then
                !print*,"end focus for nonlinear rf map."
                this%Pts1(2,i) = this%Pts1(2,i) + &
                             0.5d0*vtmpgrad*gambetz/gam*this%Pts1(1,i)
                this%Pts1(4,i) = this%Pts1(4,i) + &
                             0.5d0*vtmpgrad*gambetz/gam*this%Pts1(3,i)
            else if(abs(drange(5)+0.75)<1.0d-6) then
                !print*,"comment end focus for nonlinear cavity map."             
            end if
            !apply the final longitudinal energy deviaton kicks
            !this does not work correctly at low energy
            !phi = this%Pts1(5,i)*harm+phi0lc

            !biaobin, update phi with changing evolution freq
            phi = harm*w0/ws*this%Pts1(5,i) +phi0lc
            this%Pts1(6,i) = this%Pts1(6,i)+2*nseg*tau*vtmp*(cos(phi0lc)-cos(phi))

            !biaobin, keep zi unchanged, Ti should be updated
            this%Pts1(5,i) = this%Pts1(5,i)*bet0/bet1

          enddo
        endif
        
        end subroutine idealrf_nonlinearmap

        subroutine idealrf_linearmap(this,drange,tau,nseg,nst,ihlf)
        implicit none
        include 'mpif.h'
        type (BeamBunch), intent(inout) :: this
        real*8, dimension(12), intent(in) :: drange
        double precision, intent (in) :: tau
        integer, intent(in) :: nseg,nst
        integer, intent(inout) :: ihlf
        integer :: i
        real*8 :: vtmp,vtmpgrad,phi0lc
        real*8 :: gam0,bet0,gambet0,dgam,gam1,bet1,gambet1,fRF        
        real*8 :: x0,xp0,y0,yp0,z0,delta0
        real*8 :: x1,xp1,y1,yp1,z1,delta1
        real*8 :: gam
        real*8 :: m11f,m12f,m21f,m22f,m33f,m34f,m43f,m44f,m55f,m56f,m65f,m66f
        real*8 :: m11m,m12m,m21m,m22m,m33m,m34m,m43m,m44m,m55m,m56m,m65m,m66m

        !print*,"linear map for ideal cavity."

        !max. accelerating gradient (V/m)
        vtmp = drange(2)/this%Mass        
        !synchronous phase
        phi0lc = drange(4)*asin(1.0d0)/90 
        vtmpgrad = vtmp*cos(phi0lc)
        fRF = drange(3)
        ! entrance momentum
        gam0    = -this%refptcl(6)
        gambet0 = sqrt(gam0**2-1.0d0)
        bet0   = gambet0/gam0
        ! exit momentum
        dgam = tau*vtmp*cos(phi0lc)
        gam1 = gam0+dgam
        gambet1 = sqrt(gam1**2-1.0d0)
        bet1 = gambet1/gam1
        !apply entrance focusing kick
        if(nst.eq.1 .and. mod(ihlf,2).eq.0) then
            if(abs(drange(5)+0.5)<1.0d-6) then
                !print*,"End focus for linear rf map."
                m21f = -vtmpgrad/(2.0d0*gam0)
                m43f = -vtmpgrad/(2.0d0*gam0)
            else if(abs(drange(5)+0.25)<1.0d-6) then
                !print*,"Comment end focus for linear rf map."
                m21f = 0.0d0
                m43f = 0.0d0
            end if
          do i = 1, this%Nptlocal
            gam = gam0 - this%Pts1(6,i)
            !initial phase, impactz => geo phase
            x0  = this%Pts1(1,i)*Scxl
            xp0 = this%Pts1(2,i)/gambet0
            y0  = this%Pts1(3,i)*Scxl
            yp0 = this%Pts1(4,i)/gambet0
            !apply transfer map
            x1  = x0
            xp1 = m21f*x0 + xp0
            y1  = y0
            yp1 = m43f*y0 + yp0
            !transform back to ImpactZ's phase
            this%Pts1(1,i) = x1/Scxl
            this%Pts1(2,i) = xp1*gambet0 
            this%Pts1(3,i) = y1/Scxl
            this%Pts1(4,i) = yp1*gambet0 
          enddo
        endif
        !drift under constant acceleration
        m12m = gambet0/vtmpgrad*dlog(gambet1/gambet0)
        m22m = gambet0/gambet1
        m34m = gambet0/vtmpgrad*dlog(gambet1/gambet0)
        m44m = gambet0/gambet1
        !energy chirp term, linear chirp
        m65m = dgam*tan(phi0lc)*2*(4.0d0*atan(1.0_8))*fRF/Clight/(gambet1*bet1)
        m66m = gambet0/gambet1
        do i = 1, this%Nptlocal
          x0  = this%Pts1(1,i)*Scxl
          xp0 = this%Pts1(2,i)/gambet0
          y0  = this%Pts1(3,i)*Scxl
          yp0 = this%Pts1(4,i)/gambet0
          z0  = -this%Pts1(5,i)*bet0*Scxl
          delta0 = -this%Pts1(6,i)/gambet0/bet0
          !apply transfer map
          x1  = x0 + m12m*xp0
          xp1 = m22m*xp0
          y1  = y0 + m34m*yp0
          yp1 = m44m*yp0     
          !longitudinal direction same as linear map for drift 
          !z1  = z0 !frozen model
          z1  = z0 + tau/(gambet0**2)*delta0
          delta1 = m65m*z0 + m66m*delta0
          !transform back to ImpactZ phase space
          this%Pts1(1,i) = x1/Scxl
          this%Pts1(2,i) = xp1*gambet1
          this%Pts1(3,i) = y1/Scxl
          this%Pts1(4,i) = yp1*gambet1
          this%Pts1(5,i) = -z1/Scxl/bet1
          this%Pts1(6,i) = -delta1*gambet1*bet1
        enddo
        !update the reference particle energy
        this%refptcl(6) = this%refptcl(6) - tau*vtmp*cos(phi0lc)

        !apply exit focusing kick
        if(nst.eq.nseg .and. mod(ihlf,2).eq.1) then
            if(abs(drange(5)+0.5)<1.0d-6) then
                !print*,"End focus for linear rf map."
                m21f = vtmpgrad/(2.0d0*gam1)
                m43f = vtmpgrad/(2.0d0*gam1)
            else if(abs(drange(5)+0.25)<1.0d-6) then
                !print*,"Comment end focus for linear rf map."
                m21f = 0.0d0
                m43f = 0.0d0
            end if
          do i = 1, this%Nptlocal
            x0  = this%Pts1(1,i)*Scxl
            xp0 = this%Pts1(2,i)/gambet1
            y0  = this%Pts1(3,i)*Scxl
            yp0 = this%Pts1(4,i)/gambet1
            !apply transfer map
            x1  = x0
            xp1 = m21f*x0 + xp0
            y1  = y0
            yp1 = m43f*y0 + yp0
            !transform back to ImpactZ's phase space
            this%Pts1(1,i) = x1/Scxl
            this%Pts1(2,i) = xp1*gambet1
            this%Pts1(3,i) = y1/Scxl
            this%Pts1(4,i) = yp1*gambet1
          enddo
        endif
        end subroutine idealrf_linearmap

      end module BeamBunchclass
