import sys
import re

class lattice_parser:
    '''
    input:
    lines is lattice section lines,
    line is usedline
    '''    
    def __init__(self, fileName, lineName):

        self.fileName = fileName
        self.lineName = lineName.upper()  # in code, upper case convention
           
    def readfile(self):
        f = open(self.fileName,'r')
        lines = f.readlines()
        f.close()

        return lines
    
    def _combine_lines(self,lines):
        '''combine lines ended with & to one line'''

        j = 0
        for line in lines:
            if re.match(r'.*&+ *\n$',line):
                
                # delete '& \n'
                lines[j] = re.sub(r'&+ *\n',' ',lines[j])
    
                # combine these two line
                lines[j+1] = lines[j]+lines[j+1]
                
                # replace next line with comment line
                # to keep len(lines) unchanged, as in the for loop
                lines[j] = '! \n'
            j = j+1
                
        return lines

    def _delete_comment_blank_lines(self, lines):
        '''
        delete comment (start with !) and blank lines,
        white spaces in line are also deleted. 
        '''
        # get the index of comment and blank line
        j = 0;
        index=[]
        for line in lines:
            
            # delete all white space in each line
            lines[j] = lines[j].replace(' ','')
            
            # also \t tab space
            lines[j] = lines[j].replace('\t','')
    
            # get the index of comment and blank lines
            if re.match(r'^!',line):
                index.append(j)
            
            # blank lines, pay attention to \t tab space    
            elif re.match(r'^\t* *\n',line):
                index.append(j)
                        
            j = j+1
        
        # delete the comment and blank lines
        cnt = 0
        for j in index:
            del lines[j-cnt]
            cnt += 1
        
        return lines

    def _delete_redundant_comma(self, lines):
        '''
        delete all redundant comma,
        delete quatation marks in each line.
        '''
        j = 0
        for line in lines:
            # rpn expression expand, change here
            # remove quatation marks in line, '..' and "..."
            line = line.replace('\'','').replace('\"','')
    
            # remove rebundant comma
            tmplist = line.split(',')
            
            # remove all the '' in tmplist
            while '' in tmplist:
                tmplist.remove('')
    
            # replace lines[j] with no-redundant comma string
            lines[j] = ','.join( tmplist)
            j += 1
        
        return lines

    def _delete_backslashn(self, lines):
        '''
        delete all \n in lines
        '''
        j = 0
        for line in lines:
            lines[j] = line.replace('\n','')
            j += 1
        
        return lines

    def get_brieflines(self):
        '''
        transform lattice file to brief view, delete the comment lines, 
        blank lines, and so on
        '''
        lines = self.readfile()
        
        # transfor the lte file to brief view
        lines = self._combine_lines(lines)
        lines = self._delete_comment_blank_lines(lines)
        lines = self._delete_redundant_comma(lines)
        lines = self._delete_backslashn(lines)

        return lines    
   
    def _get_lattice(self, lines):
        '''
        save lattice lines in a dict, like:
            {'D1': {'NAME': 'D1', 'TYPE': 'DRIFT', 'L': '1.0'},
            'B1': {'NAME': 'B1', 'TYPE': 'BEND', 'ANGLE': '1.0'}
              ...
            'USELINE': {'NAME': 'USELINE', 'TYPE': 'LINE', 'LINE': 'D1,4*BC'}
            }
        '''
        # lines = self.get_brieflines() #only lattice section
        
        lattice = {}
        for line in lines:
            # there are two types line,
            # 1. type = element
            # 2. type = line
            
            if re.match(r'(\w+):(LINE)=',line,re.IGNORECASE):
                # print(line)
                line_type = 'LINE'
            elif re.match(r'(\w+):([a-zA-Z]+)(,)', line):
                # print(line)
                line_type = 'ELEMENT'
            else:
                print('Unrecognized ELEMENT or LINE name: ',line,',')
                print("ELEMENT NAME and LINE name should be (r'[a-zA-Z0-9_]+') style.")
                sys.exit()
        
            if line_type == 'ELEMENT': 
                # handle with element line    
                tmp = line.split(',')
                
                # get element name and type
                elem_name = tmp[0].split(':')[0].upper()  #upper case for element name
                elem_type = tmp[0].split(':')[1].upper()  #upper case all elem_type
                
                elem = dict()           
                elem['NAME'] = elem_name
                elem['TYPE'] = elem_type
                
                for para in tmp[1:]:
                    para_name = para.split('=')[0].upper()  #use upper case for all para_name
                    para_value = para.split('=')[1]
                    elem[para_name] = para_value
                    
                lattice[elem_name] = elem   
                
            elif line_type == 'LINE':
                beamline = dict()
                
                beamline_name = line.split(':')[0].upper() #upper case for beamline name
                beamline_line = line.split(':')[1].split('=')[1]
                beamline_line = beamline_line.strip('(').strip(')') #delete ()
                
                beamline['NAME'] = beamline_name
                beamline['TYPE'] = 'LINE'
                beamline['LINE'] = beamline_line.upper()
                
                lattice[beamline_name] = beamline
                        
        return(lattice) 

    def get_trackline(self, lines):
        '''
        get used line in .ele file
        '''
        # lines = self.get_brieflines()
        
        lattice = self._get_lattice(lines) 

        usedline = lattice[self.lineName]['LINE'].split(',')
        # expand the track line
        usedline = self._expandline(usedline, lines) 
        
        trackline = []
        for item in usedline:
            trackline.append( lattice[item] )
            
        return trackline
    
    def _expandline(self, line, lines):
        '''
        expand nested N*FODO to (FODO, FODO,...)
        expand FODO to (QF1,D1,QD1,....)
        '''  
        # lines = self.get_brieflines()
        
        lattice = self._get_lattice(lines)
        
        out = []        
        for item in line:
            if re.match(r'^\d+\*',item):  #4*FODO case
                tmp = item.split('*')
                tmp = int(tmp[0]) * [tmp[1]]                
                out.extend(self._expandline(tmp,lines))
            
            elif re.match(r'^[a-zA-Z]+\*',item):   #FODO*4 case
                tmp = item.split('*')
                tmp = int( tmp[1]) * [tmp[0]]
                out.extend( self._expandline(tmp,lines))
                print('ATTENTION: If in Elegant, you should use N*FODO, not FODO*N in .lte file.')    
            
            elif lattice[item]['TYPE'] == 'LINE':
                item = lattice[item]['LINE'].split(',')
                out.extend( self._expandline(item,lines)) # in case item is still LINE, recursion
                
            else:
                out.append(item)                    
        return out   
    
    def _is_number(self, s:str):
        '''
        To judge whether input string s is a number or not.
        '''
        try:
            float(s)
            return True
        except ValueError:
            return False      
