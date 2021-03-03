!201908, this module is from Kilean
!newly added:
!LagrangeInterp, interp, which is from M. Borland's Elegant source code
module MathModule
  implicit none
  private
  real*8, parameter :: pi    = 3.141592653589793d0
  real*8, parameter :: twopi = 6.283185307179586d0
  type :: mathTemplate
    contains
      procedure :: hamsl,iErf,randn
      procedure :: LagrangeInterp, interp
  end type
  type(mathTemplate), public :: math
  ! === example use ==================================
  ! x = math%randn()             ! normal distribution
  ! x_std = math%std(x,size(x))  ! get s.t.d. of x_std
  ! ==================================================
contains

real*8 function hamsl(self,j,at)
!==================================================================
! same with hammersley except that the sequence now start from "at"
!------------------------------------------------------------------
  implicit none
  class(mathTemplate) :: self
  integer, optional, intent(in) :: j,at
  integer, parameter            :: jmax=10
  real*8                        :: xs(jmax),xsi(jmax)
  integer                       :: i(jmax),nbase(jmax),i1(jmax),i2(jmax)
  data nbase/2,3,5,7,11,13,17,19,23,29/
  data i/jmax*1/
  if((.not. present(j)) .or. (.not. present(at))) then
    call random_number(hamsl) 
    return
  endif
  if(j<1) then
    call random_number(hamsl) 
    return
  endif
  if(at<=0) then
    call random_number(hamsl) 
    return
  endif
  if(at>i(j)) i(j) = at  ! starting index
  xs (j)=0.d0
  xsi(j)=1.0d0
  i2(j)= i(j)
  do
    xsi(j)=xsi(j)/float(nbase(j))
    i1 (j)= i2(j)/nbase(j)
    xs (j)= xs(j)+(i2(j)-nbase(j)*i1(j))*xsi(j)
    i2 (j)= i1(j)
    if(i2(j)<=0) exit
  enddo
  hamsl=xs(j)
  i(j)= i(j)+1
  return
end function 

real*8 function iErf(self,x)
! ==========================================================
! inverted error function
! original author:  Mark Law
! reference: https://github.com/markthelaw/GoStatHelper
! ------------------------------------------------------------      
  implicit none
  class(mathTemplate) :: self
  real*8, intent(in) :: x
  real*8 :: y, w, p
  
  y = x
  if(x>1d0-1d-16) y=1d0-1d-16    ! divergence correction 
  if(x<-1d0+1d-16) y=-1d0+1d-16  ! divergence correction 
  w = -log((1d0-y)*(1d0+y))      ! 1.0 - x * x would induce rounding errors near the boundaries +/-1
  if(w<6.25d0) then
    w = w - 3.125
    p =  -3.6444120640178196996d-21
    p =   -1.685059138182016589d-19 + p * w
    p =   1.2858480715256400167d-18 + p * w
    p =    1.115787767802518096d-17 + p * w
    p =   -1.333171662854620906d-16 + p * w
    p =   2.0972767875968561637d-17 + p * w
    p =   6.6376381343583238325d-15 + p * w
    p =  -4.0545662729752068639d-14 + p * w
    p =  -8.1519341976054721522d-14 + p * w
    p =   2.6335093153082322977d-12 + p * w
    p =  -1.2975133253453532498d-11 + p * w
    p =  -5.4154120542946279317d-11 + p * w
    p =    1.051212273321532285d-09 + p * w
    p =  -4.1126339803469836976d-09 + p * w
    p =  -2.9070369957882005086d-08 + p * w
    p =   4.2347877827932403518d-07 + p * w
    p =  -1.3654692000834678645d-06 + p * w
    p =  -1.3882523362786468719d-05 + p * w
    p =    0.0001867342080340571352 + p * w
    p =  -0.00074070253416626697512 + p * w
    p =   -0.0060336708714301490533 + p * w
    p =      0.24015818242558961693 + p * w
    p =       1.6536545626831027356 + p * w 
  elseif(w<16d0) then
    w = sqrt(w) - 3.25d0
    p =   2.2137376921775787049d-09
    p =   9.0756561938885390979d-08 + p * w
    p =  -2.7517406297064545428d-07 + p * w
    p =   1.8239629214389227755d-08 + p * w
    p =   1.5027403968909827627d-06 + p * w
    p =   -4.013867526981545969d-06 + p * w
    p =   2.9234449089955446044d-06 + p * w
    p =   1.2475304481671778723d-05 + p * w
    p =  -4.7318229009055733981d-05 + p * w
    p =   6.8284851459573175448d-05 + p * w
    p =   2.4031110387097893999d-05 + p * w
    p =   -0.0003550375203628474796 + p * w
    p =   0.00095328937973738049703 + p * w
    p =   -0.0016882755560235047313 + p * w
    p =    0.0024914420961078508066 + p * w
    p =   -0.0037512085075692412107 + p * w
    p =     0.005370914553590063617 + p * w
    p =       1.0052589676941592334 + p * w
    p =       3.0838856104922207635 + p * w      
  else
    w =  sqrt(w) - 5d0
    p =  -2.7109920616438573243d-11
    p =  -2.5556418169965252055d-10 + p * w
    p =   1.5076572693500548083d-09 + p * w
    p =  -3.7894654401267369937d-09 + p * w
    p =   7.6157012080783393804d-09 + p * w
    p =  -1.4960026627149240478d-08 + p * w
    p =   2.9147953450901080826d-08 + p * w
    p =  -6.7711997758452339498d-08 + p * w
    p =   2.2900482228026654717d-07 + p * w
    p =  -9.9298272942317002539d-07 + p * w
    p =   4.5260625972231537039d-06 + p * w
    p =  -1.9681778105531670567d-05 + p * w
    p =   7.5995277030017761139d-05 + p * w
    p =  -0.00021503011930044477347 + p * w
    p =  -0.00013871931833623122026 + p * w
    p =       1.0103004648645343977 + p * w
    p =       4.8499064014085844221 + p * w
  endif
  iErf = p*x
end function      

real*8 function cdfn(self,low,up,lowCut,upCut)
  implicit none
  class(mathTemplate) :: self
  real*8, intent(in) :: low,up
  real*8, optional, intent(in) :: lowCut,upCut
  real*8 :: Erf_lc,Erf_hc,ErfL,ErfH
  if(present(lowCut)) then
    Erf_lc = Erf(lowCut/sqrt(2d0))
  else
    Erf_lc = -1d0
  endif
  if(present(upCut)) then
    Erf_hc = Erf(upCut/sqrt(2d0))
  else
    Erf_hc =  1d0
  endif
  ErfL = Erf(low/sqrt(2d0))
  ErfH = Erf(up/sqrt(2d0))
  cdfn = (ErfH-ErfL)/(Erf_hc-Erf_lc)
end function cdfn

real*8 function randn(self, jHamm, at, low, up)
!==========================================
! hammersley sampling of local gaussian distribution 
! starting at "at" using inverse error function
!------------------------------------------
  implicit none
  class(mathTemplate) :: self
  integer,optional, intent(in) :: jHamm,at
  real*8, optional, intent(in) :: low,up
  real*8                       :: erfL,erfH
  if(present(low)) then
    erfL = Erf(low/sqrt(2d0))
  else
    erfL = -1d0
  endif
  if(present(up)) then
    erfH = Erf(up/sqrt(2d0))
  else
    erfH = 1d0
  endif  
  randn = sqrt(2d0)*self%iErf((erfH-erfL)*self%hamsl(jHamm,at)+erfL)
end function randn

! code form M. Borland's Elegant source C code
real*8 function interp(self,x,Fx,Uj,Nbin1)
  implicit none
  class(mathTemplate) :: self
  real*8, intent(in), dimension(Nbin1) :: x,Fx
  integer,intent(in) :: Nbin1
  real*8,intent(in) :: Uj
  integer :: lo,hi,mid

  lo=1
  hi=Nbin1
  do while ((hi-lo)>1)
      mid = (lo+hi)/2
      if (Uj<Fx(mid)) then
          hi=mid
      else
          lo=mid
      endif
  enddo
  interp = self%LagrangeInterp(x,Fx,lo,Uj,Nbin1)
end function interp

real*8 function LagrangeInterp(self,x,Fx,lo,Uj,Nbin1)
implicit none
  class(mathTemplate) :: self
  real*8, intent(in), dimension(Nbin1) :: x,Fx
  integer,intent(in) :: lo,Nbin1
  real*8,intent(in) :: Uj
  real*8 :: sum,denom,numer
  integer :: i,j
  
  sum=0.0d0
  do i=0,1
    denom=1.0d0
    numer=1.0d0
    do j=0,1
      if (i.ne.j) then
        denom=denom*(Fx(lo+i)-Fx(lo+j))
        numer=numer*(Uj-Fx(lo+j))
        if (numer.eq.0) then
          LagrangeInterp=x(lo+j)
          return
        end if
      end if
    end do
    if (denom.eq.0) then
      LagrangeInterp=0.0d0
      return
    end if
    sum=sum+x(lo+i)*numer/denom
  end do
  LagrangeInterp=sum
end function LagrangeInterp

end module MathModule
