#Name: Biaobin Li
#email: libb@ihep.ac.cn

# usage, in command line, type:
# source setup.sh
# It will temporary add the following environment 
# valuables to the path

# get current path
ROOTPATH=`pwd`
export PATH=$ROOTPATH/utilities:$ROOTPATH/src:$PATH

# if you want to write the env-variable to .zshrc/.bashrc
echo " " >> ~/.zshrc
echo "# install IMPACT-Z" >> ~/.zshrc
echo "# =============" >> ~/.zshrc

echo "export PATH=$ROOTPATH/utilities:$ROOTPATH/src:\$PATH" >> ~/.zshrc
echo "export PATH=$ROOTPATH/utilities/lattice_parser:\$PATH" >> ~/.zshrc
