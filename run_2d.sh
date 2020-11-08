#initialize run
rm -r *trans
link_0=1

#create folder for first run
mkdir $link_0\trans
cp -r constant system 0 $link_0\trans
cd $link_0\trans

#preprocess for first run
blockMesh > blockMesh.log
topoSet > topoSet.log
subsetMesh -overwrite c0 -patch floatingObject > subsetMesh.log
setFields > setFields.log

#run sistem with stopping criteria of 1 m total falling distance 
loop=0
while [ $loop -ne -1 ]
do
#run solver with one step at a time
#check aspect ratio at every step
#set max aspect ratio to specific value.
#solver will run with stopping criteria of maxAspectRatio=3
    aspectRatio=1
    while [ $aspectRatio -lt 3 ]
    do
        interFoam > interFoam.log
        checkMesh -latestTime > checkMesh.log
        aspectRatio=$(grep "aspect" checkMesh.log)
        aspectRatio=$(echo $aspectRatio|cut -d " " -f5)
        aspectRatio=$(echo $aspectRatio|cut -d "." -f1)
    done
#export results for paraView
    foamToVTK

#grab final simulation time
    time=$(grep "Time = " checkMesh.log)
    time=$(echo $time|cut -d " " -f3)

#garb the displacement vector and vector components for each axis
    centOfMass_line=$(grep "Rotation" $time/uniform/sixDoFRigidBodyMotionState)           
    centOfMass_x=$(echo $centOfMass_line|cut -d " " -f3)
    centOfMass_y=$(echo $centOfMass_line|cut -d " " -f4)
    centOfMass_z=$(echo $centOfMass_line|cut -d " " -f5)

#calculate negatives of the displacement vector components
    a=$(echo $centOfMass_x|cut -d "." -f1)
    b=$(echo $centOfMass_x|cut -d "." -f2)
    neg_centOfMass_x=$((-1*$a)).$b

    a=$(echo $centOfMass_y|cut -d "." -f1)
    b=$(echo $centOfMass_y|cut -d "." -f2)
    neg_centOfMass_y=$((-1*$a)).$b

    a=$(echo $centOfMass_z|cut -d "." -f1)
    loop=$a
    b=$(echo $centOfMass_z|cut -d "." -f2)
    neg_centOfMass_z=$((-1*$a)).$b


#create new run directory and move the constant and system folders
    cd ..
    link=$(($link_0 + 1))
    mkdir $link\trans
    cp -r $link_0\trans/constant $link_0\trans/system $link\trans 
    cd $link\trans

#replace the center of mass with previous run's final value
    centOfMass_old=$(grep "centreOfMass" constant/dynamicMeshDict)
    sed -i "s|$centOfMass_old|$centOfMass_line|" constant/dynamicMeshDict    
    sed -i "s|Rotation|Mass|" constant/dynamicMeshDict

#start preprocessing for current run
    blockMesh > blockMesh.log

#1st transformation. move mesh to negative direction amount of total displacement 
    vector="($neg_centOfMass_x $neg_centOfMass_y $neg_centOfMass_z)"
    transformPoints -translate "$vector"
#create floatingObject
    topoSet > topoSet.log
    subsetMesh -overwrite c0 -patch floatingObject > subsetMesh.log

#second transformation. move mesh to original point.
    vector="($centOfMass_x $centOfMass_y $centOfMass_z)"
    transformPoints -translate "$vector"
    setFields > setFields.log

#move point file in order to perform mapField
    cp -r ../$link_0\trans/$time .
    cp constant/polyMesh/points $time/polyMesh/.

#map the fields from previous folder's last time step to current folder
    mapFields ../$link_0\trans -consistent > mapField.log

#initialize point displacement 
    cp ../pointDisplacement $time/

#adjust variable for directory creations 
    link_0=$link

done

#run solver for one last time
aspectRatio=1
while [ $aspectRatio -lt 3 ]
    do
        interFoam > interFoam.log
        checkMesh -latestTime > checkMesh.log
        aspectRatio=$(grep "aspect" checkMesh.log)
        aspectRatio=$(echo $aspectRatio|cut -d " " -f5)
        aspectRatio=$(echo $aspectRatio|cut -d "." -f1)
    done
