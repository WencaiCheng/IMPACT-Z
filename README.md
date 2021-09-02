# 1. lte2impactzin

# syntax

- `!` starts comments, comments following `!` are ignored.



- `&` 换行符

  ```bash
  D1: drift, &
      L=100   !comments here
  
  B1: Bend, angle=1.0, CSR=1, &  !comments here
      order=2
  ```

  ==First line is legal, fourth line is not legal.== `&` should be followed with `\n` character.

  

- element and line name should start with \[a-zA-Z]\[_]\[0-9]



- nested feature is surported

  ```
  D1: drift, &   ! comments here
  L=1.0
  
  B1: Bend,, angle="1.0"
  B2: Bend, angle=1.0
  B3: Bend, angle=1.0
  B4: Bend, angle=1.0
  
  BC: line=(B1,B2,B3,B4)
  
  BC-2: line=(2*BC)
  
  useline: line=(D1,2*BC-2)
  ```

- `,` and `;` are both supported in `beam` and `control` sections

  like:

  ```
  &beam
  	mass = 0.511;
  	Np = 1000;
  	charge = 1.0e-12;
  	sigx   = 0.1e-3,	sigxp  = 1.0e-3;  sigxxp = 0.0;	
  	sigy   = 0.1e-3;  sigyp  = 1.0e-3,  sigyyp= 0.0;
  	sigz  = 1.0e-3;   sigE = 1.0e3;     
  	chirp_h = 0.0;
  	
  	distribution_type = 45;
  &end
  ```

  

# code structure

- lattice_parser
- impactz_parser : lattice_parser
  - get_lattice_section
  - get_beam_section
  - get_control_section

- genimpactz



# lattice_parser

programing notes

- `N*FODO` case, how to expand it ?

  ```python
  #like, expand line=['4*FODO','BC1'] to ['FODO','FODO','FODO','FODO','BC1']
  
  line=['4*FODO','BC1']
  
  tmpline = []
  for item in line:
      if re.match(r'^\d+\*',item):    # 4*FODO case
          tmp = item.split('*')
          tmpline.extend( int(tmp[0]) * [tmp[1]])
  
      elif re.match(r'^[a-zA-Z]+\*',item):  # FODO*4 case
          tmp = item.split('*')
          tmpline.extend( int( tmp[1]) * [tmp[0]] )
          print('ATTENTION: If in Elegant, you should use N*FODO, not FODO*N in .lte file.')
  
      else:
          tmpline.append(item)
  line = tmpline
  ```





# impactz_parser

Right now, only add those parameters I used mostly and understood well. ==DO NOT add the parameters I have not tested yet.==



Code design methods:

-  If not in dict keys list, then set default values
- not case sensitive, use upper to match element or parameters name
- priority, if sentence



## control section

The values following are all default values.

```bash
&control
  core_num_T=1;
  core_num_L=1;
  
  meshx= 64;
  meshy= 64;
  meshz= 64;
 
  kinetic_energy= 0;       !kinetic energy [eV]
  default_order= 1;
  
  freq_rf_scale= 2.856e9;

  steps=1;    ! 1kicks/m
  maps=1      ! 1 map/half_step
  
	tsc=0;      !transverse space charge off
	lsc=0;      !longitudinal space charge off
	
	csr=0;      !csr off
	zwake=0;    !longitudinal wakefield off
	trwake=0;   !transverse wakefield off
	
	pipe_radius=0.014;  !pipe radius, [m]
	
	turn=1;  !for ring multi-turn simulation  
	outfq=1;
	
	RingSimu=0;
	
&end
```

- core_num_T, core_num_L, processor layout, the product of these numbers must equal the number of processors that you run on. 

- gridx, gridy, gridz, grid setting for PIC space charge simulation.

- default_order, 1 refers to linear map, 2 refers to nonlinear map for all elements. It has ==lower priority to the ORDER setted in each individual element==. 

- W [eV], kinetic_energy，即动能。注意与 ELEGANT 的 p_central_mev 区别开来：

  p_central_mev, 数值上即等于 $\gamma_0\beta_0$ [MeV/c], 即 $pc=\sqrt{\epsilon^2-\epsilon_0^2}=\gamma\beta m_0c^2=\sqrt{W^2+2W\epsilon_0}$

- f_scale, [Hz], scaling frequency.



### 新增一行

ImpactZ.in 中新增加了一行：

`Flagsc turn_number output_frequency SimuType`



1. space charge control:

- tsc=0, lsc=0: Flagsc=0
- tsc=0, lsc=1: Flagsc=1
- tsc=1, lsc=0: Flagsc=2
- tsc=1, lsc=1: Flagsc=3

No need to set current being 0 for space charge OFF.



==To do==

- [ ] If space charge OFF, but wakefield ON ?



2. turn_number

   Ring 的模拟圈数。`turn>1` 则认为是 ring simulation，不要利用该参数来重复 linac 的模拟次数。如果想像FODO 一样，$num \times FODO$ 来复制 lattice，应该在 lattice section 中使用 lattice 重复的特性。

​        

​       对于Linac 模拟，不要设置 `turn_number>1`，不然会引发错误。   

   

3. outfq

每多少圈 `watch` 元件有效。如`turn=5001`, `outfq=100`. Lattice 设置如下：

```
w0: watch, filename_ID=1000, sample_freq=1, slice_bin=20, slice_information=0, coordinate_convention="NORMAL"
line: line=(w0,cav0,RCS)
```

则会分别输出初始分布，100, 200, ..., 5000 圈后分布:

`fort.1000, fort.1100, fort.1200,...,fort.5000`.

turn 之所以设置 5001，是为了输出第5000圈之后的分布，所以故意多跑了一圈。



4. Ring or Linac simulation

In python level:

| Parameter Name | Units | Type | Default | Description                                                  |
| -------------- | ----- | ---- | ------- | ------------------------------------------------------------ |
| RingSimu       |       | int  | 0       | By default, ==Linac simulation is applied==. If RingSimu=1, then Ring simulation is applied. Mainly influence is at: phase folding, RF cavity frequency if based on $f_0$. |

In fortran level:

```
SimuType = 1 => Linac 
SimuType = 2 => Ring
```

对于 Linac 模拟，`freq_rf_scale` 可设置为 linac 频率，也可以不这么设置，仅仅是作为 scale 而存在的设置值。但对于 Ring 而言，因存在纵向的相位折叠，折叠时是相对于回旋周期而言的，因此 `fs=f0`，fs 应设置为回旋频率。当粒子速度逐圈变化时，`f0`会逐渐高于`fs`，此时，`fs` 不变，`f0`需要每圈重新计算。



## beam parameters

The listed values are default values if un-defined in input file.

```bash
&beam	
	mass   = 0.511e6;
	charge = -1.0;
	
	Np = 1000;
	total_charge = 1.0e-12;
	distribution_type = 45;
	
	sigx = 0.0,	sigpx = 0.0,  sigxpx  = 0.0;	
	sigy = 0.0, sigpy = 0.0,  sigypy  = 0.0;
	sigz = 0.0, sigE  = 0.0,  chirp_h = 0.0;  

  emit_nx = 0.0;
  emit_x = 0.0 ;
  beta_x = 1.0;
  alpha_x = 0.0;
  
  emit_ny = 0.0;
  emit_y = 0.0;
  beta_y = 1.0;
  alpha_y = 0.0;
&end
```

- mass, [eV], for electron mass=0.511,  for proton mass=938.27e6.
- charge, for electron, charge=-1.0, for proton, charge=1.0
- total_charge, [C], if total_charge=0, space charge will be turned off.
- Np, particle number.
- sigx, sigy, sigz, beam RMS size in unit of [m].
- sigpx, sigpy, beam RMS momentum, px and py refer to $\gamma\beta_x$ and $\gamma\beta_y$.
- sigE, [eV], beam RMS energy spread.
- chirp_h  [/m], beam energy chirp h. h consistent with z, z>0 is head. So for four dipole chicane, negative chirp results in bunch length compression.
- distribution_type, if equal to 19, read-in beam distribution, coordinate definition is ???
- mismatch, off-set not added yet



如果:

- If emit_x or emit_nx not equal to 0, then use twiss parameters for (x, px, y, py) distribution
- otherwise, use sig values





## lattice elements

```
&lattice
D1: drift, L=1.0
B1: Bend, angle=1.0
&end
```



If ORDER=0, i.e. not explicitly set in each ELEMENT, then the transfer map order is determined by DEFAULT_ORDER in control section.





### DRIFT

A drift space implemented as a linear matrix, or exactly drift map, see Wolski's book for more information.

| Parameter Name | Units | Type   | Default | Description                                                  |
| -------------- | ----- | ------ | ------- | ------------------------------------------------------------ |
| L              | m     | double | 0.0     | length of drift                                              |
| steps          |       | int    | 0       | 1 step means a half-drift + a space-charge kick + a half-drift |
| map_steps      |       | int    | 0       | each half-drift involves computing a map for that half-element, computed by numerical integration with 1 map_steps |
| order          |       | int    | 0       | 1 or 2, linear map or nonlinear map                          |
| pipe_radius    | m     | double | 0.0     | pip radius                                                   |

For space charge simulations, one should increase the steps number where beam size changes too much to meet the convergence. 



### QUAD

A quadrupole implemented as a linear matrix or nonlinear map, see Wolski's book for more information.

| Parameter Name | Units       | Type   | Default | Description                                                  |
| -------------- | ----------- | ------ | ------- | ------------------------------------------------------------ |
| L              | m           | double | 0.0     | length                                                       |
| steps          |       | int    | 0      | how much section is divided into |
| map_steps      |       | int    | 0      | map steps |
| order          |       | int    | 0      | 1 or 2, linear map or nonlinear map                          |
| $K_1$          | $\rm{/m^2}$ | double | 0.0     | quadrupole strength, $K_1=\frac{1}{(B\rho)_0}\frac{\partial B_y}{\partial x}$ |
| pipe_radius | m           | double | 0.0   | pip radius |
| Dx | m           | double | 0.0     | x misalignment error |
| Dy | m           | double | 0.0     | y misalignment error |
| rotate_x | rad         | double | 0.0     | rotation error in x direction |
| rotate_y | rad         | double | 0.0     | rotation error in y direction |
| ratate_z | rad         | double | 0.0     | rotation error in y direction |



### BEND

A magnetic dipole implemented as a matrix, up to 2nd order. See K. Brown paper for more information.

| Parameter Name | Units        | Type   | Default | Description                                                  |
| -------------- | ------------ | ------ | ------- | ------------------------------------------------------------ |
| L              | m            | double | 0.0     | arc length                                                   |
| steps          |              | int    | 0       | how much section is divided into                             |
| map_steps      |              | int    | 0       | map steps                                                    |
| order          |              | int    | 0       | 1 or 2, linear map or nonlinear map                          |
| angle          | rad          | double | 0.0     | bend angle                                                   |
| E1             | rad          | double | 0.0     | entrance edge angle                                          |
| E2             | rad          | double | 0.0     | exit edge angle                                              |
| $K_1$          | $1\rm{/m^2}$ | double | 0.0     | quadrupole strength, $K_1=\frac{1}{(B\rho)_0}\frac{\partial B_y}{\partial x}$, not added yet in V2.1 version. |
| PIPE_RADIUS    | m            | double | 0.0     | half gap between poles                                       |
| h1             | 1/m          | double | 0.0     | entrance pole-face curvature                                 |
| h2             | 1/m          | double | 0.0     | exit pole-face curvature                                     |
| fint           |              | double | 0.0     | integrated fringe field                                      |
| Dx             | m            | double | 0.0     | x misalignment error                                         |
| Dy             | m            | double | 0.0     | y misalignment error                                         |
| rotate_x       | rad          | double | 0.0     | rotation error in x direction                                |
| rotate_y       | rad          | double | 0.0     | rotation error in y direction                                |
| ratate_z       | rad          | double | 0.0     | rotation error in y direction                                |
| CSR            |              | int    | 0       | 0/1, whether to include 1D-CSR effects or not.               |



Error parameters of Dx, Dy, rotate_x, rotate_y, rotate_z are added in version-2.1.

Elegant fint is set 0.5 as default value.



### EMATRIX

Kick particles use given transfer matrix. Currently only support (m11,m33,m55,m56,m65).

| Parameter Name | Units | Type   | Default | Description                                                  |
| -------------- | ----- | ------ | ------- | ------------------------------------------------------------ |
| PIPE_RADIUS    |       | double | 0.0     | un-used                                                      |
| R11            |       | double | 1.0     | for x direction shrink                                       |
| R33            |       | double | 1.0     | for y direction shrink.                                      |
| R55            |       | double | 1.0     | for z direction shrink                                       |
| R56            |       | double | 0.0     | momentum compaction factor, because we used z>0 for beam head, so positive m56 results bunch length compression in four dipole chicane. |
| R65            |       | double | 0.0     | for energy chirp, R65<0 for chicane compression, R65>0 for de-chirp. |
| R66            |       | double | 1.0     |                                                              |
| T566           |       | double | 0.0     |                                                              |





### RFCW

RF cavity with exact phase dependence. Model is drift + acceleration momentum kick + drift.

| Parameter Name | Units  | Type   | Default | Description                                                  |
| -------------- | ------ | ------ | ------- | ------------------------------------------------------------ |
| L              | m      | double | 0.0     | length                                                       |
| steps          |        | int    | 0       | steps                                                        |
| map_steps      |        | int    | 0       | map steps                                                    |
| order          |        | int    | 0       | 1 or 2, linear map or nonlinear map                          |
| volt           | V      | double | 0.0     | peak voltage                                                 |
| gradient       | V/m    | double | 0.0     | peak acceleration gradient, ==volt has priority if both volt and gradient are given==. |
| phase          | degree | double | 0.0     | driven phase,  sin() function is used (same as ELEGANT, different with IMPACT-Z), $E_z=A\cdot \rm{sin}(kz+\phi)$, phase=90 is the crest for acceleration |
| freq           | Hz     | double | 2.856e9 | RF frequency                                                 |
| end_focus      |        | int    | 1       | turn ON or OFF cavity end focus effects. 0 for OFF, 1 for ON. |
| pipe_radius    | m      | double | 0.0     | pip radius                                                   |
| Dx             | m      | double | 0.0     | x misalignment error                                         |
| Dy             | m      | double | 0.0     | y misalignment error                                         |
| rotate_x       | rad    | double | 0.0     | rotation error in x direction                                |
| rotate_y       | rad    | double | 0.0     | rotation error in y direction                                |
| ratate_z       | rad    | double | 0.0     | rotation error in z direction                                |
| zwake          |        | int    | 0       | 0/1, if zero, longitudinal wake is turned off                |
| trwake         |        | int    | 0       | 0/1, if zero, transverse wakes are turned off                |
| wakefile_ID    |        | int    | None    | If  WAKEFIEL_ID=41, it refers to `rfdata41.in` , which contains RF structure wakefield, 1st column is s [m],  2nd column is longitudinal wakefield $w_L$ [V/C/m], 3rd column is transverse wakefield $w_T$ [$\rm{V/C/m^2}$]. |
| ac_mode        |        | int    | 0       | for RCS AC mode, if equal 1, then rfdata_ac.in should be given. And NONLINEAR map will be called, order=1 will be overwritten. |

rfdata_ac.in::q:

```
line_number harmonic number

col 1: time (s)

col 2: brho (T m), not used in IMPACT-Z, 0 is also OK

col 3: voltage (GV)

col 4: phase (degree), sin function, changed to cos in math.f90
```

In IMPACT-Z source code: 

​		ac_mode=1, end focus, ID=-0.55

​        ac_mode=1, NO end focus, ID=-0.65  







### WATCH

Output particle distribution and beam slice information into fort.N and fort.2N files, where N is the filename_ID. 

| Parameter Name        | Units | Type   | Default | Description                                                  |
| --------------------- | ----- | ------ | ------- | ------------------------------------------------------------ |
| filename_ID           |       | int    | 1000    | number larger than 1000 is recommended                       |
| sample_freq           |       | int    | 1       | if sample_freq=10, every 10 particles output 1 particle      |
| coordinate_convention |       | string | normal  | 'NORMAL' or 'IMPACT-Z'                                       |
| slice_information     |       | int    | 1       | whether output slice information, i.e. whether add -8 element simultaneously |
| slice_bin             |       | int    | 128     | bins number for getting histogram slice information.         |

If  coordinate_convention='normal', output phase space is $(x,\gamma\beta_x,y,\gamma\beta_y,t,\gamma)$, where $x,y,t$ are in .  For coordinate_convention='IMPACT-Z', output phase space is $(xw/c,\gamma\beta_x,yw/c,\gamma\beta_y,wt,-(\gamma-\gamma_0))$,  where $w$ is $w=2\pi f$, $f$ is the scaling frequency.

If filename_ID = 1001, then the output file would be fort.1001 and fort.6001. fort.6001 refers to ImpactZ -8 element output file (+5000), which outputs slice information. The columns in this file are as following:

| Column number | Units | Description                                |
| ------------- | ----- | ------------------------------------------ |
| 1             | m     | bunch length                               |
| 2             |       | particle number per slice                  |
| 3             | A     | current per slice                          |
| 4             | mrad  | x-direction normalized emittance per slice |
| 5             | mrad  | y-direction normalized emittance per slice |
| 6             |       | relative energy spread, dE/E per slice     |
| 7             | eV    | uncorrelated energy spread per slice       |
| 8             | m     | $<x>$                                      |
| 9             | m     | $<y>$                                      |
| 10            |       | x-direction mismatch factor ???            |
| 11            |       | y-direction mismatch factor ???            |



### SHIFTCENTER

Shift the beam center to the origin point for 6-direction coordinates.

```
elem1: shiftcenter, L=0;
```

In order to keep the format consistence with other elements (for re expression),  `L=0` must be added.



The original `0 0 0 -1`  only shift transverse coordinates, now 6D shift.

==question:== Then what's `-21` elements used for?



### RingRF

BPM type element, zero length. Thin cavity model applied in Ring simulation, both DC and AC model.

In ImpactZ.in file, -42 element is added:

```bash 
0 0 0 -42 radius(m) volt(eV) phase(degree) harmNum flag
```

where `flag` is used for option `AC or DC model`.

```
flag=1, DC, default value
flag=2, AC
```





For python level:

```
cav0: RingRF,radius= ,
```

| Parameter Name | Units  | Type   | Default | Description                                                  |
| -------------- | ------ | ------ | ------- | ------------------------------------------------------------ |
| volt           | V      | double | 0.0     | peak voltage                                                 |
| phase          | degree | double | 0.0     | driven phase,  sin() function is used (same as ELEGANT, different with IMPACT-Z), $E_z=A\cdot \rm{sin}(kz+\phi)$, phase=90 is the crest for acceleration。Automatic change to cos func when generate Impactz.in |
| harm           |        | int    | 1       | harmonic number, $f_{RF}=harm\times f_{0}$                   |
| pipe_radius    | m      | double | 0.0     | pip radius, not used yet                                     |
| ac_mode        |        | int    | 0       | default is DC model. For RCS AC mode, if equal 1, then `rfdata_ac.in` file should be given. And NONLINEAR map will be called. |

rfdata_ac.in:

```bash
line_number harmonic_number

col 1: time (s)

col 2: brho (T m), not used in IMPACT-Z, 0 is also OK

col 3: voltage (GV)

col 4: phase (degree), sin function, auto changed to cos in math.f90
```



如何做到 RF curve 文件只读取一次：

只在第一次遇到时读取文件，最后 deallocate 即可。



# data process

## fort.24 & fort.25

Add 4 additional columns data output:

| 8     | 9      | 10   | 11    | 12   |
| ----- | ------ | ---- | ----- | ---- |
| betax | gammax | etax | etaxp | turn |

## fort.18

7th col: time(s)

8th col: brho (T m)

9th col: turn













# to do

- [ ] sc off, wake on
- [ ] AC模式下，文件只读取一次
- [ ] 



- default order in control section should control all settings in lattice, lower priority than ORDER in each element.
- ~~total_charge=0, turn off space charge~~.
- ~~add a charge=1.0/-1.0 parameter.~~
- how to keep charge and current when space charge is off.
- rpn expression in lattice section is not supported yet.
- ~~comment "!" is not supported in beam and control section.~~
- 增加对 MARK 元件的支持，增加一个 class 支持 elegant 元件的直接转换



- 赋值功能

  ![image-20210310143358408](../../../../IHEPBox/documents/Typora/pics/image-20210310143358408-9188819.png)

  已添加。



- [ ] elegant2impactz.py

  read in elegant .lte type lattice, convert it to ImpactZ.in.

  convention:

  - lte file is not case sensitive, both  `drift` and `DRIFT` are supported.



# 2. Fortran level

use ID flag to control elements behavior

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

<br/>usage:ID=-1

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
