import sys
import re
from collections import defaultdict
import const
from copy import deepcopy
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
        
        self.control['DEFAULT_ORDER'] = 1
        self.control['P_CENTRAL_MEV'] = 0;
        
        self.control['FREQ_RF_SCALE'] = 2.856e9
        
        # turn all para values to str data type
        for key in self.control:
            self.control[key] = abs( self.control[key] )

    def __default_beam(self):
        self.beam['MASS'] = const.electron_mass
        self.beam['NP']   = int(1e3)
        self.beam['CHARGE'] = 1.0e-12 #[C]
        
        self.beam['SIGX'] = 1E-4     #[m]
        self.beam['SIGY'] = 1E-4     #[m]      
        self.beam['SIGZ'] = 1E-4     #[m]
        
        self.beam['SIGPX'] = 1E-3    #sig_gambetx [1]
        self.beam['SIGPY'] = 1E-3    #sig_gambety [1]
        self.beam['SIGE']  = 1.0E-3  #            [eV] 
        
        self.beam['SIGXPX'] = 0.0
        self.beam['SIGYPY'] = 0.0
        self.beam['CHIRP_H'] = 0.0
        
        # in future, may use elegant's style to define every phase space 
        # distribution respectively
        self.beam['DISTRIBUTION_TYPE'] = 45
        
        # turn all para values to str data type
        for key in self.beam:
            self.beam[key] = abs(self.beam[key])

    def __default_lattice(self):
        # drift
        #-------------
        self.lattice['DRIFT']['L'] = 0.0
        self.lattice['DRIFT']['STEPS'] = 1
        self.lattice['DRIFT']['MAP_STEPS'] = 1
        self.lattice['DRIFT']['ORDER'] = 1
        self.lattice['DRIFT']['PIP_RADIUS'] = 0.014

        # quad
        #-------------
        self.lattice['QUAD']['L'] = 0.0
        self.lattice['QUAD']['STEPS'] = 1
        self.lattice['QUAD']['MAP_STEPS'] = 1
        self.lattice['QUAD']['ORDER'] = 1
        self.lattice['QUAD']['K1'] = 0.0 
        self.lattice['QUAD']['PIP_RADIUS'] = 0.014
        self.lattice['QUAD']['DX'] = 0.0
        self.lattice['QUAD']['DY'] = 0.0
        self.lattice['QUAD']['ROTATE_X'] = 0.0 #[rad]
        self.lattice['QUAD']['ROTATE_Y'] = 0.0
        self.lattice['QUAD']['ROTATE_Z'] = 0.0

        # BEND
        #-------------
        self.lattice['BEND']['L'] = 0.0
        self.lattice['BEND']['STEPS'] = 1
        self.lattice['BEND']['MAP_STEPS'] = 1
        self.lattice['BEND']['ORDER'] = 1
        self.lattice['BEND']['ANGLE'] = 0.0
        self.lattice['BEND']['E1'] = 0.0
        self.lattice['BEND']['E2'] = 0.0
        self.lattice['BEND']['K1'] = 0.0
        self.lattice['BEND']['HGAP'] = 0.014 #half gap
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
        self.lattice['RFCW']['STEPS'] = 1
        self.lattice['RFCW']['MAP_STEPS'] = 1
        self.lattice['RFCW']['ORDER'] = 1
        self.lattice['RFCW']['VOLT'] = 0.0
        self.lattice['RFCW']['GRADIENT'] = 0.0
        self.lattice['RFCW']['PHASE'] = 0.0
        self.lattice['RFCW']['FREQ'] = 2.856e9
        self.lattice['RFCW']['PIP_RADIUS'] = 0.014
        self.lattice['RFCW']['DX'] = 0.0
        self.lattice['RFCW']['DY'] = 0.0
        self.lattice['RFCW']['ROTATE_X'] = 0.0
        self.lattice['RFCW']['ROTATE_Y'] = 0.0
        self.lattice['RFCW']['ROTATE_Z'] = 0.0
        self.lattice['RFCW']['ZWAKE'] = 0
        self.lattice['RFCW']['TRWAKE'] = 0
        self.lattice['RFCW']['WAKEFILE_ID'] = None

        # watch
        #-------------
        self.lattice['WATCH']['FILENAME_ID'] = 1000
        self.lattice['WATCH']['SAMPLE_FREQ'] = 1
        self.lattice['WATCH']['COORDINATE_CONVENTION'] = 'NORMAL' #(x,gambetx,y,gambety,t,gam)
        self.lattice['WATCH']['SLICE_INFORMATION'] = 1  # by default add -8 element simultaneously
        self.lattice['WATCH']['SLICE_BIN'] = 128

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
            if elem['TYPE'] in self.lattice.keys():
                tmp = deepcopy(self.lattice[elem['TYPE']])
                      
                for elem_para in elem.keys():
                    tmp[elem_para] = elem[elem_para] 
                
                # replace trackline
                trackline[j] = tmp
                j += 1        
            else:
                print("Unknown element type in lattice section!")
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
        control_lines.append( self.beam['NP'] )
        control_lines.append( '1 0 1 \n' )
        
        # line-3
        control_lines.append( self.control['MESHX'] )
        control_lines.append( self.control['MESHY'] )
        control_lines.append( self.control['MESHZ'] )
        control_lines.append('1  0.014 0.014 0.10 \n')
        
        # line-4
        control_lines.append( self.beam['DISTRIBUTION_TYPE'] )
        control_lines.append( '0 0 1 \n' )
        
        # line-5
        control_lines.append( self.beam['NP'] )
        control_lines.append( '\n' )
        
        # line-6
        # current averaged over FREQ_RF_SCALE
        current = float(self.beam['CHARGE'])*float(self.control['FREQ_RF_SCALE'])
        current = abs(current)
        control_lines.append( str(current) )
        control_lines.append('\n')
        
        # line-7
        charge_sign = float(self.beam['CHARGE'])/abs(float(self.beam['CHARGE']))
        q_m = 1/float(self.beam['MASS'])*charge_sign
        control_lines.append(str(q_m))
        control_lines.append('\n')
        
        # line-8 to line-10
        sig_gam = float(self.beam['SIGE'])/float(self.beam['MASS']) 

        control_lines.append( self.beam['SIGX'] )
        control_lines.append( self.beam['SIGPX'] )
        control_lines.append( self.beam['SIGXPX'] )
        control_lines.append( '1.0 1.0 0.0 0.0 \n' )

        control_lines.append( self.beam['SIGY'] )
        control_lines.append( self.beam['SIGPY'] )
        control_lines.append( self.beam['SIGYPY'] )
        control_lines.append( '1.0 1.0 0.0 0.0 \n' )
       
        control_lines.append( self.beam['SIGZ'] )
        control_lines.append( str(sig_gam) ) 
        control_lines.append( '0.0' )         # currently, sig_zgam=0, left for chirp setting
        control_lines.append( '1.0 1.0 0.0 0.0 \n' )
        
        # line-11
        control_lines.append(str(current))
        control_lines.append( self.control['P_CENTRAL_MEV'] )
        control_lines.append( self.beam['MASS'] )
        control_lines.append( str(charge_sign) )
        control_lines.append( self.control['FREQ_RF_SCALE'] )
        control_lines.append( '0.0 \n' )
        
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
                map_flag = self._get_driftmap_flag(elem)

                lte_lines.append( elem['L'] )
                lte_lines.append( elem['STEPS'] )
                lte_lines.append( elem['MAP_STEPS'] )
                lte_lines.append('0')
                lte_lines.append(elem['PIP_RADIUS'])
                lte_lines.append(map_flag)
                lte_lines.append('/ \n')

            elif elem['TYPE'] == 'QUAD':
                map_flag = self._get_quadmap_flag(elem)

                lte_lines.append(elem['L'])
                lte_lines.append(elem['STEPS'])
                lte_lines.append(elem['MAP_STEPS'])
                lte_lines.append(elem['1'])
                lte_lines.append( elem['K1'] )
                lte_lines.append( map_flag )
                lte_lines.append(elem['PIP_RADIUS'])
                lte_lines.append(elem['DX'])
                lte_lines.append(elem['DY'])
                lte_lines.append(elem['ROTATE_X'])
                lte_lines.append(elem['ROTATE_Y'])
                lte_lines.append(elem['ROTATE_Z'])
                lte_lines.append('/ \n')

            elif elem['TYPE'] == 'BEND':
                map_flag = self._get_bendmap_flag(elem)

                lte_lines.append(elem['L'])
                lte_lines.append(elem['STEPS'])
                lte_lines.append(elem['MAP_STEPS'])
                lte_lines.append('4')
                lte_lines.append(elem['ANGLE'])
                lte_lines.append(elem['K1']) 
                lte_lines.append( map_flag )
                lte_lines.append(elem['HGAP'])
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
  
            elif elem['TYPE'] == 'RFCW':
                map_flag = self._get_rfcwmap_flag(elem)
                wake_flag = self._get_wakefield_flag(elem)
                
                if float(elem['VOLT'])==0:
                    gradient = 0.0
                else:
                    gradient = float(elem['VOLT'])/float(elem['L']) #V/m
                    
                phase = float(elem['PHASE']) - 90 #cos for impactz, elegant sin function
                
                # add -41 wakefield element
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
                                    
                # cavity lines
                lte_lines.append(elem['L'])
                lte_lines.append(elem['STEPS'])
                lte_lines.append(elem['MAP_STEPS'])
                lte_lines.append('103')
                lte_lines.append(str(gradient))
                lte_lines.append(elem['FREQ'])
                lte_lines.append( str(phase) )
                lte_lines.append( map_flag )
                lte_lines.append('/ \n')
                       
                # wakefield stops at the exit of cavity
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
                    lte_lines.append( str(int(elem['FILENAME_ID']) +1000) )
                    lte_lines.append('-8')
                    lte_lines.append(elem['SLICE_BIN'])
                    lte_lines.append('/ \n')    
                
                else:
                    print('Unknown flag for SLICE_INFORMATION, it should be 0 or 1.')
                    sys.exit()
        
        lte_lines = ' '.join(lte_lines)
        return lte_lines
    
    def _get_driftmap_flag(self, elem :dict):
    
        if elem['ORDER'] == '1':     #linear map
            flag = '-1'
        elif elem['ORDER'] == '2':    #real nonlinear map
            flag = ''      #keep blank, same as ImpactZ-V-2.1
        else:
            print('Element',elem['NAME'],':unknown order is given.')
            sys.exit()
        return flag
    
    def _get_quadmap_flag(self, elem :dict):
    
        if elem['ORDER'] == '1':     #linear map
            flag = '-5'
        elif elem['ORDER'] == '2':    #nonlinear map
            flag = '-15'
        else:
            print('Element',elem['NAME'],':unknown ORDER is given.')
            sys.exit()
        return flag
    
    def _get_bendmap_flag(self, elem :dict):
    
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
    
        if elem['ORDER'] == '1':     #linear map
            flag = '-0.5'
 
        elif elem['ORDER'] == '2':    #nonlinear map
            flag = '-1.0'
    
        else:
            print('Element',elem['NAME'],':unknown ORDER is given.')
            sys.exit()
            
        return flag   
    def _get_wakefield_flag(self, elem :dict):
        '''
        get -41 wakefield element flag.
        '''
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
    
    def elegant2impactz_map(self):
        pass
        

        
# usage examples
# =====================
# file_name = 'tmp.impz'
# line_name = 'useline'

# example-1
# ---------
# lte = lattice_parser(file_name,line_name)

# lines = lte.get_brieflines()
# trackline = lte.get_trackline(lines)


# example-2
# ---------
# lte = impactz_parser(file_name,line_name)
# lte.write_impactzin()    

# trackline = lte.update_trackline()
# control   = lte.update_control()
# beam      = lte.update_beam()



# lattice_sec = lte.get_lattice_section()
# control_sec   = lte.get_control_section()
# beam_sec      = lte.get_beam_section()

# print(lte.control)
# print(lte.beam)
# print(lte.lattice)


# print( lte.get_impactzin_control() ) 
      
# print( lte.get_impactzin_lattice() )   
        
    
    



