#!/bin/bash

# CONSTANTS
flags='RCMA' # git flag - rename-edit|copy-edit|modified|added
tmp_path='tmp' # dirrectory where delta will be stored
specifiedTests='' # list of spec tests, generates automatically
aClasses='' # list of apex classes. Spec  tests will be generated depend on this list
csvfile='gettests.csv' # file where spec tests stored
aquery="select ApexTestClass.Name, ApexClassOrTrigger.Name FROM ApexCodeCoverage WHERE ApexClassOrTrigger.Name " # query to generate spec tests

# For some reasons git thinks that Bamboo working directory is not safe, this is fix 
#git config --global --add safe.directory ${bamboo.build.working.directory}

if [ -d $tmp_path ]; then
    echo "Dirrecory exists"
else
    echo "Creating tmp directory"
    mkdir $tmp_path
fi

mapfile -t diffs < <(git diff --name-only --diff-filter="$flags" aLotS aLot)

function move_files_to_tmp() {
    if [[ "$file_name" == ".gitignore" ]] || [[ "$file_name" == "diff.sh" ]]; then
        :
    fi
    # This condition has to be here in case that aura and lwc dont cant be deplyed when files separated
    if [[ "$direc" == "aura" ]] || [[ "$direc" == "lwc" ]]; then
        file_name=$(echo $file_name | grep -o '[a-zA-Z]*\/[a-zA-Z]*\/[A-Za-z]*.*\/')
        echo "Moving $file_name into $tmp_path/$direc"
        mv $file_name $tmp_path/$direc
    # emails have subdirs
    elif [[ "$direc" == "email" ]]; then
        echo "Moving email $file_name to $tmp_path/$direc/$subdir"
        mv $file_name $tmp_path/$direc/$subdir
    fi
    # checking if file exists and if yes move it
    if [[ -f "$file_name" ]]; then
        echo "Moving $file_name into $tmp_path/$direc"
        mv $file_name $tmp_path/$direc
    else
        :
        # echo "$file_name already moved or doesn't exist"
    fi 
}

function moving_meta_file_to_tmp() {
    meta_file="$file_name-meta.xml"
    if [[ "$direc" == "email" ]]; then
        echo "Moving Email Meta to $tmp_path/$direc/$subdir"
        mv $meta_file $tmp_path/$direc/$subdir
    fi
    if [[ "$direc" == "aura" ]] || [[ "$direc" == "lwc" ]]; then
        :
    fi
    if [[ -f "$meta_file" ]]; then
        echo "Moving $meta_file to $tmp_path/$direc"
        mv $meta_file $tmp_path/$direc
    else
        :
        # echo "$meta_file already moved or doesn't exist"
    fi
}

function TestsForSTR {
    apex_class="$file_name"
    apex_class=$(echo "$apex_class" | sed -e 's/^[a-z].*\///') # removing 'src/''
    if [[ "$direc" == "classes" ]]; then
        local test_string="Test"
        apex_class=$(echo "$apex_class" | sed -e 's/\.cls//') # removing .cls
        if [[ "$apex_class" == *"-meta.xml"* ]] || [[ "$apex_class" == "" ]]; then
            :
        fi
        # adding to list of spec tests value from git diff if there were some test class changes
        if [[ "$apex_class" == *"$test_string"* ]]; then
            # validation of list to avoid unwanted ',' symbol
            if [[ "$specifiedTests" == "" ]]; then
                specifiedTests=$apex_class
            fi
            # adding to existing list new value 
            specifiedTests=$specifiedTests','$apex_class
        fi
        # validation of apex classes list to avoid unwanted ',' symbol
        if [[ "$aClasses" == "" ]]; then
            aClasses=$apex_class
        fi
        # if list of classes contains current value - skip
        if [[ $aClasses == *"$apex_class"* ]]; then
            :
        else
            aClasses=$aClasses','$apex_class
        fi
    fi
    if [[ "$direc" == "triggers" ]]; then
        trigger=$(echo "$apex_class" | sed -e 's/\.trigger//')
        if [[ "$trigger" == *"-meta.xml"* ]] || [[ "$trigger" == "" ]]; then
            :
        fi
        aClasses=$aClasses','$trigger
    fi
}

function SOQL_get_tests {
    sfdx force:data:soql:query --query "$aquery IN($aClasses)" --targetusername a10 --usetoolingapi --resultformat csv > "$csvfile"
    while IFS="," read -r test_name_col class_or_trigger_name_col; do
        # skipping if list contains this value of tests
        if [[ "$specifiedTests" == *"$test_name_col"* ]]; then
            continue
        fi
        # validation to avoid unwanted ',' symbol
        if [[ "$specifiedTests" == "" ]]; then
            specifiedTests=$test_name_col
        else
            specifiedTests=$specifiedTests', '$test_name_col
        fi
    done < <(tail -n +2 $csvfile)
}


function generate_delta(){
    IFS=$'\n'
    for file_name in "${diffs[@]}"; do
        # creating dirs for each of component
        for direc in $file_name; do
            direc=$(echo "$direc" | sed -e 's/"//')
            direc=$(echo "$direc" | sed -e 's/src\///')
            direc=$(echo "$direc" | sed -e 's/\/[A-Za-z].*//')
            # just validation to avoid unwanted dirrs. Add your condition if needed
            if [[ "$direc" == ".gitignore" ]] || [[ "$direc" == "diff.sh" ]] || [[ "$direc" == "destructiveChangesPost.xml" ]]; then
                :
            fi
            # vailadation of dirs existance
            if [[ -d $tmp_path/$direc ]]; then
                # echo "Dirrecotry $tmp_path/$direc exists"
                :
            else
                mkdir $tmp_path/$direc
            fi
            # emails has subdirs which must be created
            if [[ "$direc" == "email" ]]; then
                subdir=$file_name
                # Grepping for example "All" subfolder
                subdir=$(echo "$subdir" | grep -o '[^src\/email][a-zA-Z].*\/')
                if [[ -d $tmp_path/$direc/$subdir ]]; then
                    :
                else
                    mkdir $tmp_path/$direc/$subdir
                fi
            fi
            move_files_to_tmp
            moving_meta_file_to_tmp
            TestsForSTR
        done
    done    
}


generate_delta
# adding <'> symbol to bigining and end of each of class. Need for tests query
aClasses=$(echo "$aClasses" | sed -e "s/\b/'/g")
echo "For This classes tests will be found"
echo "$aClasses"

SOQL_get_tests
echo "This classes will be executed"
echo "$specifiedTests"
# Retiving file just to generate package xml of our delta
sfdx force:mdapi:retrieve -r mypkg/ -u a10 -d $tmp_path
unzip -q mypkg/unpackaged.zip
echo "Moving package.xml to tmp folder"
cp unpackaged/package.xml $tmp_path
sfdx force:mdapi:deploy --checkonly -u a10 -d $tmp_path -w -1 -l RunSpecifiedTests -r "$specifiedTests"