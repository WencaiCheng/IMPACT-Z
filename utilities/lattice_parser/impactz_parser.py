import sys
import re
from collections import defaultdict
from copy import deepcopy
from math import sqrt, pi
import math
import const
from lattice_parser import lattice_parser

nest_dict = lambda: defaultdict(nest_dict) # to define a['key1']['key2'] = value
                 

# class: impactz_parser
#======================
class impactz_parser(lattice_parser):
    def __init__(self, fileName, lineName):
        lattice_parser.__init__(self,fileName, lineName)
        
        self.control = {}
        self.beam = {}
        self.lattice = nest_dict()
        
        # initiate with default values
        self.__default_control()
        self.__default_beam()
        self.__default_lattice()
        
        # update with read in *.impz file
        self.control = self.update_control()
        self.beam    = self.update_beam()
        self.lattice = self.update_trackline()
        
    def write_impactzin(self):
        '''
        generate ImpactZ.in file.
        '''
        control_file = self.get_impactzin_control()
        lattice_file = self.get_impactzin_lattice()
        
        with open('ImpactZ.in','w') as f:
            f.write(control_file)
            f.write(lattice_file)

        f.close()     
                  
    def get_lattice_section(self):
        '''
        get lattice section. 

        '''
        
        lines = self.get_brieflines()
        
        # get lattice section
        pattern1 = re.compile(r'^&lattice$',re.I)  #not case sensitive
        pattern2 = re.compile(r'^&end$',re.I)
        
        j1,j2 = self._get_index(pattern1, pattern2, lines)
        
        lattice = lines[j1+1:j2]  # ignored 1st and last element, i.e. &lattice and &end
        
        # get the tracked line
        trackline = self.get_trackline(lattice)
        return trackline
    
    def get_control_section(self):
        '''
        get control section.
        '''
        
        lines = self.get_brieflines()
        
        # get lattice section
        pattern1 = re.compile(r'^&control$',re.I)  #not case sensitive
        pattern2 = re.compile(r'^&end$',re.I)
        
        j1,j2 = self._get_index(pattern1, pattern2, lines)
        
        control_lines = lines[j1+1:j2]  # ignored 1st and last element, i.e. &lattice and &end
        
        control = {}
        for line in control_lines:
            tmp = re.split(';|,',line) # , and ; are both supported
        
            # remove white space
            while '' in tmp:
                tmp.remove('')
            
            for j in tmp:
                tmp2 = j.split('=')
                
                name = tmp2[0].upper()
                value = tmp2[1]
                
                # in case math expression, such as:
                #     FREQ_RF_SCALE = 2.998e8/2/pi
                try:
                    eval(value)
                except:
                    pass
                else:
                    value = eval(value.lower())
                    value = str(value)  #back to string
                
                control[name] = value                
                
        return control         
        
    def get_beam_section(self):
        '''
        get beam section.
        '''
        
        lines = self.get_brieflines()
        
        # get lattice section
        pattern1 = re.compile(r'^&beam$',re.I)  #not case sensitive
        pattern2 = re.compile(r'^&end$',re.I)
        
        j1,j2 = self._get_index(pattern1, pattern2, lines)
        
        beam_lines = lines[j1+1:j2]  # ignored 1st and last element, i.e. &lattice and &end

        beam = {}
        for line in beam_lines:
            tmp = re.split(';|,',line) # , and ; are both supported
        
            # remove white space
            while '' in tmp:
                tmp.remove('')
            
            for j in tmp:
                tmp2 = j.split('=')
                
                name = tmp2[0].upper()
                value = tmp2[1]
                
                # in case math expression, such as:
                #    total_charge=20*5e-3/2.998e8
                try:
                    eval(value)
                except:
                    pass
                else:
                    value = eval(value.lower())
                    value = str(value)  #back to string
                
                beam[name] = value
                                         
        return beam  
               
    def _get_index(self, pattern1, pattern2, lines):
        '''
        get start and finished index of (&control,...,&end)    
        '''
        
        j1 = int(1e6)
        j2 = int(1e6)
        cnt = 0
        for line in lines:
            if re.match(pattern1, line):  
                j1 = cnt
                break
            cnt += 1
                    
        cnt = j1
        for j in range(j1, len(lines)):
            if re.match(pattern2,lines[j]):
                j2 = cnt  
                break                  
            cnt += 1    
            
        if j1 == int(1e6):
            print(pattern1,"not found. Input file is wrong.")
            sys.exit()
        elif j2==int(1e6):
            print(pattern2,"not found. Input file is wrong.")
            sys.exit()
                      
        return j1,j2

    
    def __default_control(self):    
        self.control['CORE_NUM_T'] = 1  #transverse direction computor core number      
        self.control['CORE_NUM_L'] = 1  #longitudinal direction 
        self.control['MESHX'] = 64
        self.control['MESHY'] = 64
        self.control['MESHZ'] = 64
        self.control['KINETIC_ENERGY'] = 0;  # kinetic energy W, E=W+E0
        self.control['FREQ_RF_SCALE'] = 2.856e9
        self.control['DEFAULT_ORDER'] = 1
        self.control['STEPS'] = 1 #1kick/m
        self.control['MAPS']  = 1 #1map/half_step
        self.control['TSC'] = 0
        self.control['LSC'] = 0
        self.control['CSR'] = 0
        self.control['ZWAKE'] = 0
        self.control['TRWAKE'] = 0
        self.control['PIPE_RADIUS'] = 0.014 #pipe radius[m], by default, 0.014m
        self.control['TURN'] = 1
        self.control['OUTFQ'] = 1
        self.control['RINGSIMU']  = 0 

        # turn all para values to str data type
        for key in self.control:
            self.control[key] = str( self.control[key] )

    def __default_beam(self):
        self.beam['MASS'] = const.electron_mass
        self.beam['CHARGE'] = -1.0
        self.beam['NP']   = int(1e3)
        self.beam['TOTAL_CHARGE'] = 1.0e-12 #[C]
        
        self.beam['SIGX'] = 0.0     #[m]
        self.beam['SIGY'] = 0.0     #[m]      
        self.beam['SIGZ'] = 0.0     #[m]
        
        self.beam['SIGPX'] = 0.0    #sig_gambetx/gambet0 [rad]
        self.beam['SIGPY'] = 0.0    #sig_gambety/gambet0 [rad]
        self.beam['SIGE']  = 0.0    #                    [eV] 
        
        self.beam['SIGXPX'] = 0.0
        self.beam['SIGYPY'] = 0.0
        self.beam['CHIRP_H'] = 0.0 #z>0 is head, h<0 for chicane compressor
        
        # for twiss parameters settings
        self.beam['EMIT_X'] = 0.0
        self.beam['EMIT_NX'] = 0.0   
        self.beam['BETA_X'] = 1.0
        self.beam['ALPHA_X'] = 0.0

        self.beam['EMIT_Y'] = 0.0
        self.beam['EMIT_NY'] = 0.0   
        self.beam['BETA_Y'] = 1.0
        self.beam['ALPHA_Y'] = 0.0
        
        # in future, may use elegant's style to define every phase space 
        # distribution respectively
        self.beam['DISTRIBUTION_TYPE'] = 45
        
        # turn all para values to str data type
        for key in self.beam:
            self.beam[key] = str(self.beam[key])

    def __default_lattice(self):
        # drift
        #-------------
        self.lattice['DRIFT']['L'] = 0.0
        self.lattice['DRIFT']['STEPS'] = 0
        self.lattice['DRIFT']['MAPS'] = 0
        self.lattice['DRIFT']['ORDER'] = 0
        self.lattice['DRIFT']['PIPE_RADIUS'] = 0.0

        # quad
        #-------------
        self.lattice['QUAD']['L'] = 0.0
        self.lattice['QUAD']['STEPS'] = 0
        self.lattice['QUAD']['MAPS'] = 0
        self.lattice['QUAD']['ORDER'] = 0
        self.lattice['QUAD']['K1'] = 0.0 
        self.lattice['QUAD']['PIPE_RADIUS'] = 0.0
        self.lattice['QUAD']['DX'] = 0.0
        self.lattice['QUAD']['DY'] = 0.0
        self.lattice['QUAD']['ROTATE_X'] = 0.0 #[rad]
        self.lattice['QUAD']['ROTATE_Y'] = 0.0
        self.lattice['QUAD']['ROTATE_Z'] = 0.0

        # BEND
        #-------------
        self.lattice['BEND']['L'] = 0.0
        self.lattice['BEND']['STEPS'] = 0
        self.lattice['BEND']['MAPS'] = 0
        self.lattice['BEND']['ORDER'] = 0
        self.lattice['BEND']['ANGLE'] = 0.0
        self.lattice['BEND']['E1'] = 0.0
        self.lattice['BEND']['E2'] = 0.0
        self.lattice['BEND']['K1'] = 0.0
        self.lattice['BEND']['PIPE_RADIUS'] = 0.0 #half gap
        self.lattice['BEND']['H1'] = 0.0
        self.lattice['BEND']['H2'] = 0.0
        self.lattice['BEND']['FINT'] = 0.0
        self.lattice['BEND']['DX'] = 0.0
        self.lattice['BEND']['DY'] = 0.0
        self.lattice['BEND']['ROTATE_X'] = 0.0
        self.lattice['BEND']['ROTATE_Y'] = 0.0
        self.lattice['BEND']['ROTATE_Z'] = 0.0
        self.lattice['BEND']['CSR'] = 0

        # RFCW 
        #-------------
        self.lattice['RFCW']['L'] = 0.0
        self.lattice['RFCW']['STEPS'] = 0
        self.lattice['RFCW']['MAPS'] = 0
        self.lattice['RFCW']['ORDER'] = 0
        self.lattice['RFCW']['VOLT'] = 0.0
        self.lattice['RFCW']['GRADIENT'] = 0.0
        self.lattice['RFCW']['PHASE'] = 0.0
        self.lattice['RFCW']['FREQ'] = 2.856e9
        self.lattice['RFCW']['END_FOCUS'] = 1
        self.lattice['RFCW']['PIPE_RADIUS'] = 0.0
        self.lattice['RFCW']['DX'] = 0.0
        self.lattice['RFCW']['DY'] = 0.0
        self.lattice['RFCW']['ROTATE_X'] = 0.0
        self.lattice['RFCW']['ROTATE_Y'] = 0.0
        self.lattice['RFCW']['ROTATE_Z'] = 0.0
        self.lattice['RFCW']['ZWAKE'] = 0
        self.lattice['RFCW']['TRWAKE'] = 0
        self.lattice['RFCW']['WAKEFILE_ID'] = None
        self.lattice['RFCW']['AC_MODE'] = 0

        # EMATRIX
        #-------------
        self.lattice['EMATRIX']['PIPE_RADIUS'] = 0.0
        self.lattice['EMATRIX']['R11'] = 1.0
        self.lattice['EMATRIX']['R33'] = 1.0
        self.lattice['EMATRIX']['R55'] = 1.0
        self.lattice['EMATRIX']['R56'] = 0.0
        self.lattice['EMATRIX']['R65'] = 0.0
        self.lattice['EMATRIX']['R66'] = 1.0

        # watch
        #-------------
        self.lattice['WATCH']['FILENAME_ID'] = 1000
        self.lattice['WATCH']['SAMPLE_FREQ'] = 1
        self.lattice['WATCH']['COORDINATE_CONVENTION'] = 'NORMAL' #(x,gambetx,y,gambety,t,gam)
        self.lattice['WATCH']['SLICE_INFORMATION'] = 1  # by default add -8 element simultaneously
        self.lattice['WATCH']['SLICE_BIN'] = 128

        # RingRF BPM element
        self.lattice['RINGRF']['VOLT']  = 0.0     #eV
        self.lattice['RINGRF']['PHASE'] = 0.0     #deg in sin func  
        self.lattice['RINGRF']['HARM']  = 1
        self.lattice['RINGRF']['PIPE_RADIUS'] = 0.0
        self.lattice['RINGRF']['AC_MODE'] = 0
        
        # shift the centroid of beam to the axis origin point
        #----------------------------------------------------
        # shift to center, has no para right now 
        self.lattice['SHIFTCENTER']

        #turn all lattice elem values to string data type
        for elem in self.lattice.keys():
            for key in self.lattice[elem].keys():
                self.lattice[elem][key] = str(self.lattice[elem][key])
        
    def update_trackline(self):
        '''
        read in *.impz, then add the default values from self.__default_lattice dict, 
        finally update the read in track_line lattice para values
        '''
        trackline = self.get_lattice_section() # get the tracking line
        
        j = 0
        for elem in trackline:
            # check if the element type is in self.lattice.keys, i.e. whether in
            # dict_keys(['DRIFT', 'QUAD', 'BEND', 'RFCW', 'WATCH'])          
            
            # map sbend to bend
            if elem['TYPE'] in ['SBEND']:
                elem['TYPE'] = 'BEND'

            # map quadrupole to quad 
            if elem['TYPE'] in ['QUADRUPOLE']:
                elem['TYPE'] = 'QUAD'

            # map monitor, hkicker, vkicker, sextupole to drift, temporary    
            if elem['TYPE'] in ['DRIFT','MONITOR','HKICKER','VKICKER','SEXTUPOLE']:
                elem['TYPE'] = 'DRIFT'

            if elem['TYPE'] in self.lattice.keys():
                tmp = deepcopy(self.lattice[elem['TYPE']])
                      
                for elem_para in elem.keys():
                    tmp[elem_para] = elem[elem_para] 
                
                # replace trackline
                trackline[j] = tmp
                j += 1        
            else:
                print("Unknown element type in lattice section:",elem['TYPE'])
                sys.exit()
       
        # turn all elem value to string data type
    

        return trackline
    
    def update_control(self):
        '''
        update control:dict with read in para values.
        '''
        control_sec   = self.get_control_section()
        
        control = deepcopy( self.control )
        for key in control_sec.keys():
            if key in self.control.keys():               
                # update with read in values
                control[key] = control_sec[key]
            else:
                print('Unknow control item:',key,'=',control_sec[key])    
                sys.exit()
               
        ## turn all values to string data type
        #for key in control.keys():
        #    control[key] = str(control[key])

        return control

    def update_beam(self):
        '''
        update beam:dict with read in para values.
        '''
        beam_sec   = self.get_beam_section()
        
        beam = deepcopy( self.beam )
        for key in beam_sec.keys():
            if key in self.beam.keys():               
                # update with read in values
                beam[key] = beam_sec[key]
            else:
                print('Unknow beam item:',key,'=',beam_sec[key])    
                sys.exit()
        return beam
    
       
    def get_impactzin_control(self):
        
        '''
        *.impz file to ImpactZ.in
        '''
        # control section
        #----------------
        control_lines = [' !=================== \n']
        control_lines.append('! control section \n')
        control_lines.append('!=================== \n')
        
        
        # line-1 
        control_lines.append(self.control['CORE_NUM_L'])
        control_lines.append(self.control['CORE_NUM_T'])
        control_lines.append( '\n' )
        
        # line-2
        control_lines.append( '6' )
        
        Np = int(float(self.beam['NP']))
        control_lines.append( str(Np) )
        control_lines.append( '1 0 1 \n' )
        
        # line-3
        control_lines.append( self.control['MESHX'] )
        control_lines.append( self.control['MESHY'] )
        control_lines.append( self.control['MESHZ'] )
        control_lines.append('1')
        control_lines.append(self.control['PIPE_RADIUS'])
        control_lines.append(self.control['PIPE_RADIUS'])
        control_lines.append('0.10 \n')
        
        # line-4
        control_lines.append( self.beam['DISTRIBUTION_TYPE'] )
        control_lines.append( '0 0 1 \n' )
        
        # line-5
        control_lines.append( str(Np) )
        control_lines.append( '\n' )
        
        # line-6
        # current averaged over FREQ_RF_SCALE
        current = float(self.beam['TOTAL_CHARGE'])*float(self.control['FREQ_RF_SCALE'])
        current = abs(current)  # current should be positive value even for electron beams,
                                # otherwise, negative current will turn off space charge.
        control_lines.append( str(current) )
        control_lines.append('\n')
        
        # line-7
        charge = float(self.beam['CHARGE'])
        q_m = 1/float(self.beam['MASS'])*charge  # q/m 
        control_lines.append(str(q_m))
        control_lines.append('\n')
        
        # line-8 to line-10
        # ==================
        # beam distribution  
        # ==================
        Scxl = const.c_light/(2*math.pi*float(self.control['FREQ_RF_SCALE'])) 
        gam0 = (float(self.control['KINETIC_ENERGY'])+float(self.beam['MASS']))/float(self.beam['MASS'])
        gambet0 = sqrt(gam0**2-1.0)
        bet0 = gambet0/gam0
        # twiss2sig
        # ---------
        # X-PX
        emitx = float(self.beam['EMIT_X'])
        emit_nx = float(self.beam['EMIT_NX']) 
        if emit_nx != 0.0:
            emitx = emit_nx/gambet0
            
        if emitx != 0.0:
            betax = float(self.beam['BETA_X'])
            alphax = float(self.beam['ALPHA_X'])
            
            sigx  = sqrt(emitx*betax/(1+alphax**2))
            sigpx = sqrt(emitx/betax)*gambet0
            sigxpx = alphax/sqrt(1+alphax**2)
            
            self.beam['SIGX'] = str(sigx)
            self.beam['SIGPX'] = str(sigpx)
            self.beam['SIGXPX'] = str(sigxpx)
        
        # Y-PY
        emity = float(self.beam['EMIT_Y'])
        emit_ny = float(self.beam['EMIT_NY']) 
        if emit_ny != 0.0:
            emity = emit_ny/gambet0
            
        if emity != 0.0:           
            betay = float(self.beam['BETA_Y'])
            alphay = float(self.beam['ALPHA_Y'])
            
            sigy  = sqrt(emity*betay/(1+alphay**2))
            sigpy = sqrt(emity/betay)*gambet0
            sigypy = alphay/sqrt(1+alphay**2)
            
            self.beam['SIGY'] = str(sigy)
            self.beam['SIGPY'] = str(sigpy)
            self.beam['SIGYPY'] = str(sigypy) 
            
        # transform to IMPACT-Z coordinates    
        sigx  = float(self.beam['SIGX'])/Scxl
        #sigpx = float(self.beam['SIGPX'])
        sigxpx = float(self.beam['SIGXPX']) # no unit para
        sigy  = float(self.beam['SIGY'])/Scxl
        #sigpy = float(self.beam['SIGPY'])    
        sigypy = float(self.beam['SIGYPY'])
        sig_phi = float(self.beam['SIGZ'])/Scxl/bet0 
        sig_dgam = float(self.beam['SIGE'])/float(self.beam['MASS']) 
        
        control_lines.append( str(sigx) )
        control_lines.append( self.beam['SIGPX'] )
        control_lines.append( str(sigxpx) )
        control_lines.append( '1.0 1.0 0.0 0.0 \n' )

        control_lines.append( str(sigy) )
        control_lines.append( self.beam['SIGPY'] )
        control_lines.append( str(sigypy) )
        control_lines.append( '1.0 1.0 0.0 0.0 \n' )
       
        control_lines.append( str(sig_phi) )
        control_lines.append( str(sig_dgam) ) 
        control_lines.append( self.beam['CHIRP_H'] )  #[/m], muz used for chirp setting
        control_lines.append( '1.0 1.0 0.0 0.0 \n' )
        
        # line-11
        control_lines.append(str(current))
        control_lines.append( self.control['KINETIC_ENERGY'] )
        control_lines.append( self.beam['MASS'] )
        control_lines.append( self.beam['CHARGE'] )
        control_lines.append( self.control['FREQ_RF_SCALE'] )
        control_lines.append( '0.0 \n' )

        # line-12, Biaobin Li added in 03/12/2021
        if self.control['RINGSIMU'] == '1':
            simutype = 2
        else:
            simutype = 1

        Flagsc = self._get_sc_flag()
        control_lines.append( str(Flagsc) )
        control_lines.append( self.control['TURN'] )
        control_lines.append( self.control['OUTFQ'] )
        control_lines.append( str(simutype) )
        control_lines.append( '\n' )

        control_lines = ' '.join(control_lines)
        return control_lines

    def get_impactzin_lattice(self):
        '''
        generate lattice section in ImpactZ.in file.        
        '''
        lte_lines = [' !=================== \n']
        lte_lines.append('! lattice lines \n')
        lte_lines.append('!=================== \n')        
        
        
        for elem in self.lattice:
            if elem['TYPE'] == 'DRIFT':
                if float(elem['L']) == 0:
                    # ignore 0.0 length drift
                    pass
                else:
                    map_flag = self._get_driftmap_flag(elem)
                    self._set_steps_maps_radius(elem)

                    lte_lines.append( elem['L'] )
                    lte_lines.append( elem['STEPS'] )
                    lte_lines.append( elem['MAPS'] )
                    lte_lines.append('0')
                    lte_lines.append(elem['PIPE_RADIUS'])
                    lte_lines.append(map_flag)
                    lte_lines.append('/ \n')

            elif elem['TYPE'] == 'QUAD':
                map_flag = self._get_quadmap_flag(elem)
                self._set_steps_maps_radius(elem)

                lte_lines.append(elem['L'])
                lte_lines.append(elem['STEPS'])
                lte_lines.append(elem['MAPS'])
                lte_lines.append('1')
                lte_lines.append( elem['K1'] )
                lte_lines.append( map_flag )
                lte_lines.append(elem['PIPE_RADIUS'])
                lte_lines.append(elem['DX'])
                lte_lines.append(elem['DY'])
                lte_lines.append(elem['ROTATE_X'])
                lte_lines.append(elem['ROTATE_Y'])
                lte_lines.append(elem['ROTATE_Z'])
                lte_lines.append('/ \n')

            elif elem['TYPE'] == 'BEND':
                map_flag = self._get_bendmap_flag(elem)
                self._set_steps_maps_radius(elem)

                lte_lines.append(elem['L'])
                lte_lines.append(elem['STEPS'])
                lte_lines.append(elem['MAPS'])
                lte_lines.append('4')
                lte_lines.append(elem['ANGLE'])
                lte_lines.append(elem['K1']) 
                lte_lines.append( map_flag )
                lte_lines.append(elem['PIPE_RADIUS'])
                lte_lines.append(elem['E1']) 
                lte_lines.append(elem['E2']) 
                lte_lines.append(elem['H1'])
                lte_lines.append(elem['H2'])
                lte_lines.append(elem['FINT'])
                lte_lines.append(elem['DX'])
                lte_lines.append(elem['DY'])
                lte_lines.append(elem['ROTATE_X'])
                lte_lines.append(elem['ROTATE_Y'])
                lte_lines.append(elem['ROTATE_Z'])
                lte_lines.append('/ \n')

            elif elem['TYPE'] == 'EMATRIX':
                #pipe_radius currently not used
                if elem['PIPE_RADIUS'] == '0.0' :
                    elem['PIPE_RADIUS'] = self.control['PIPE_RADIUS']

                lte_lines.append('0 0 0 -22')
                lte_lines.append(elem['PIPE_RADIUS'])
                lte_lines.append(elem['R11'])
                lte_lines.append(elem['R33'])
                lte_lines.append(elem['R55'])
                lte_lines.append(elem['R56'])
                lte_lines.append(elem['R65'])
                lte_lines.append(elem['R66'])
                lte_lines.append('/ \n')

            elif elem['TYPE'] == 'SHIFTCENTER':
                lte_lines.append('0 0 0 -1')
                lte_lines.append('/ \n')

            elif elem['TYPE'] == 'RFCW':
                map_flag = self._get_rfcwmap_flag(elem)
                wake_flag = self._get_wakefield_flag(elem)
                if float(elem['VOLT'])==0:
                    gradient = 0.0
                else:
                    gradient = float(elem['VOLT'])/float(elem['L']) #V/m
                phase = float(elem['PHASE']) - 90 #cos for impactz, elegant sin function
                
                # add -41 wakefield element
                # ------------------------
                if elem['WAKEFILE_ID']=='None':
                    pass
                elif self._is_number(elem['WAKEFILE_ID']):
                    # print('Wakefield for cavity',elem['NAME'],'is added.')  
                    # print('rfdata',elem['WAKEFILE_ID'],'.in should be given in current path.')                   
                    lte_lines.append('0 0 1 -41 1.0')
                    lte_lines.append(elem['WAKEFILE_ID'])
                    lte_lines.append(wake_flag)
                    lte_lines.append('/ \n')
                else:
                    print('ERROR: WAKEFILE_ID should be a int number, refer to wakefield file, like WAKEFILE_ID=41,' \
                          'refers to rfdata41.in file.')
                    sys.exit()

                self._set_steps_maps_radius(elem)
                # cavity lines
                # ------------------------
                lte_lines.append(elem['L'])
                lte_lines.append(elem['STEPS'])
                lte_lines.append(elem['MAPS'])
                lte_lines.append('103')
                lte_lines.append(str(gradient))
                lte_lines.append(elem['FREQ'])
                lte_lines.append( str(phase) )
                lte_lines.append( map_flag )
                lte_lines.append(elem['PIPE_RADIUS'] )
                lte_lines.append('/ \n')
                       
                # wakefield stops at the exit of cavity
                # ------------------------
                if elem['WAKEFILE_ID']=='None':
                    pass
                elif self._is_number(elem['WAKEFILE_ID']):
                    lte_lines.append('0 0 1 -41 1.0')
                    lte_lines.append(elem['WAKEFILE_ID'])
                    lte_lines.append('-1 / \n')            
                else:
                    print('ERROR: WAKEFILE_ID should be a int number, refer to wakefield file, like WAKEFILE_ID=41,' \
                          'refers to rfdata41.in file.')
                    sys.exit()   
            
            elif elem['TYPE'] == 'WATCH':
                if elem['COORDINATE_CONVENTION'] == 'NORMAL':
                    sample_sign = -1
                    
                elif elem['COORDINATE_CONVENTION'] == 'IMPACT-Z':
                    sample_sign = 1                    
                else:
                    print('Unknown coordinate convention for -2 element.')
                    sys.exit()
                    
                elem['SAMPLE_FREQ'] = abs(int(elem['SAMPLE_FREQ'])) *sample_sign   
                elem['SAMPLE_FREQ'] = str(elem['SAMPLE_FREQ'])
                    
                lte_lines.append('0 0')
                lte_lines.append(elem['FILENAME_ID'])
                lte_lines.append('-2')
                lte_lines.append(elem['SAMPLE_FREQ'])
                lte_lines.append('/ \n')
                
                # whether add -8 element
                if elem['SLICE_INFORMATION'] == '0':
                    pass
                
                elif elem['SLICE_INFORMATION'] == '1':
                    lte_lines.append('0 0')
                    lte_lines.append( str(int(elem['FILENAME_ID']) +10000) )
                    lte_lines.append('-8')
                    lte_lines.append(elem['SLICE_BIN'])
                    lte_lines.append('/ \n')    
                else:
                    print('Unknown flag for SLICE_INFORMATION, it should be 0 or 1.')
                    sys.exit()

            elif elem['TYPE'] == 'RINGRF':
                if elem['PIPE_RADIUS'] == '0.0' :
                    elem['PIPE_RADIUS'] = self.control['PIPE_RADIUS'] 

                if elem['AC_MODE'] == '1':
                    mode = 2
                else:
                    mode = 1
                lte_lines.append('0 0 0 -42')
                lte_lines.append(elem['PIPE_RADIUS'])
                lte_lines.append(elem['VOLT'])
                lte_lines.append(elem['PHASE'])
                lte_lines.append(elem['HARM'])
                lte_lines.append(str(mode))
                lte_lines.append('/ \n')

       
        lte_lines = ' '.join(lte_lines)
        return lte_lines
    
    def _get_driftmap_flag(self, elem :dict):
        if elem['ORDER'] == '0':
            # set by DEFAULT_ORDER
            elem['ORDER'] = self.control['DEFAULT_ORDER']

        if elem['ORDER'] == '1':     #linear map
            flag = '-1'
        elif elem['ORDER'] == '2':    #real nonlinear map
            flag = ''      #keep blank, same as ImpactZ-V-2.1
        else:
            print('Element',elem['NAME'],':unknown order is given.')
            sys.exit()

        return flag
    
    def _get_quadmap_flag(self, elem :dict):
        if elem['ORDER'] == '0':
            # set by DEFAULT_ORDER
            elem['ORDER'] = self.control['DEFAULT_ORDER']

        if elem['ORDER'] == '1':     #linear map
            flag = '-5'
        elif elem['ORDER'] == '2':    #nonlinear map
            flag = '-15'
        else:
            print('Element',elem['NAME'],':unknown ORDER is given.')
            sys.exit()
        return flag
    
    def _get_bendmap_flag(self, elem :dict):
        if elem['ORDER'] == '0':
            # set by DEFAULT_ORDER
            elem['ORDER'] = self.control['DEFAULT_ORDER']    
        if elem['CSR'] == '0':
            elem['CSR'] = self.control['CSR']

        if   elem['ORDER']=='1' and elem['CSR']=='0':              
            flag = '25'
        elif elem['ORDER']=='1' and elem['CSR']=='1':     
            flag = '75'
        elif elem['ORDER']=='2' and elem['CSR']=='0':     
            flag = '150'
        elif elem['ORDER']=='2' and elem['CSR']=='1':     
            flag = '250'
        else:
            print('Element',elem['NAME'],':unknown ORDER or CSR flag are given, ORDER=1/2, CSR=0/1.')
            sys.exit()
        return flag
    
    def _get_rfcwmap_flag(self, elem :dict):
        if elem['ORDER'] == '0':
            # set by DEFAULT_ORDER
            elem['ORDER'] = self.control['DEFAULT_ORDER']    

        if elem['ORDER'] == '1':     #linear map
            if elem['END_FOCUS']=='1':
                flag='-0.5'
            elif elem['END_FOCUS']=='0':
                flag='-0.25'
            else:
                print('Element',elem['NAME'],':unknown END_FOCUS flag is given.')
                sys.exit()
 
        elif elem['ORDER'] == '2':    #nonlinear map
            if elem['END_FOCUS']=='1':
                flag='-1.0'
            elif elem['END_FOCUS']=='0':
                flag='-0.75'
            else:
                print('Element',elem['NAME'],':unknown END_FOCUS flag is given.')
                sys.exit()
        else:
            print('Element',elem['NAME'],':unknown ORDER is given.')
            sys.exit()
       
        #ac_mode has higher priority
        if elem['AC_MODE']=='1':
            if elem['END_FOCUS']=='1':    #nonlinear map
                flag='-0.55'
            elif elem['END_FOCUS']=='0':   #nonlinear map
                flag='-0.65'
            else:
                print('Element',elem['NAME'],':unknown END_FOCUS flag is given.')
                sys.exit()
            
        return flag   

    def _get_sc_flag(self):
        '''
        Set Flagsc value based on TSC and LSC values in lte.impz
        '''
        if   self.control['TSC']=='0' and self.control['LSC']=='0':
            Flagsc=0
        elif self.control['TSC']=='0' and self.control['LSC']=='1':
            Flagsc=1
        elif self.control['TSC']=='1' and self.control['LSC']=='0':
            Flagsc=2
        elif self.control['TSC']=='1' and self.control['LSC']=='1':
            Flagsc=3
        else:
            print("Error: TSC and LSC value should be integer 0 or 1.")
            sys.exit()
        return Flagsc

    def _get_wakefield_flag(self, elem :dict):
        '''
        get -41 wakefield element flag.
        '''
        # global settings from control section
        if elem['ZWAKE']=='0':
            elem['ZWAKE'] = self.control['ZWAKE']
        if elem['TRWAKE']=='0':
            elem['TRWAKE'] = self.control['TRWAKE']

        # get flag
        if   elem['ZWAKE']=='0' and elem['TRWAKE']=='0':
            # turn-off wakefield
            flag = '-1'
        elif elem['ZWAKE']=='1' and elem['TRWAKE']=='0':
            flag = '5'
        elif elem['ZWAKE']=='0' and elem['TRWAKE']=='1':
            flag = '15'
        elif elem['ZWAKE']=='1' and elem['TRWAKE']=='1':
            flag = '25'
        else:
            print('Unknown flag for ZWAKE or TRWAKE, value should be 0 or 1.')
            sys.exit()
        return flag
    
    def _set_steps_maps_radius(self, elem :dict):
        '''
        set default maps and steps based on control settings
        '''
        steps = float(self.control['STEPS'])
        length = float(elem['L'])
        
        if elem['STEPS'] == '0':
            elem['STEPS'] = str(math.ceil(steps*length))
        
        # in case element length is 0.0, steps cannot be 0
        if length==0.0:
            elem['STEPS'] = '1'

        if elem['MAPS']=='0':
            elem['MAPS'] = self.control['MAPS']
        if elem['PIPE_RADIUS'] == '0.0' :
            elem['PIPE_RADIUS'] = self.control['PIPE_RADIUS']

    def elegant2impactz_map(self):
        pass
        
if __name__=='__main__':
        
    # usage examples
    # =====================
    file_name = 'rcs.impz'   
    line_name = 'RCS'
    
    # example-1
    # ---------
    # lte = lattice_parser(file_name,line_name)
    # lines = lte.get_brieflines()
    # trackline = lte.get_trackline(lines)
    
    # example-2
    # ---------
    lte = impactz_parser(file_name,line_name)
    lte.write_impactzin()    
    
    # trackline = lte.update_trackline()
    # control   = lte.update_control()
    # beam      = lte.update_beam()
    
    # lattice_sec = lte.get_lattice_section()
    # control_sec   = lte.get_control_section()
    # beam_sec      = lte.get_beam_section()
    
        
    
    



