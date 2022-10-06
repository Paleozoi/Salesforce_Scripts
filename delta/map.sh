#!/bin/bash

# get email: git log -1 --format="%aE"

# CONSTANTS
flags='RCMA' # git flag - rename-edit|copy-edit|modified|added
tmp_path='tmp' # dirrectory where delta will be stored
specifiedTests='' # list of spec tests, generates automatically
aClasses='' # list of apex classes. Spec  tests will be generated depend on this list
csvfile='gettests.csv' # file where spec tests stored
aquery="select ApexTestClass.Name, ApexClassOrTrigger.Name FROM ApexCodeCoverage WHERE ApexClassOrTrigger.Name " # query to generate spec tests
file="package.xml"
package_xml_begining='<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">'

package_xml_ending="    <version>54.0</version>
</Package>"




# For some reasons git thinks that Bamboo working directory is not safe, this is fix 
#git config --global --add safe.directory ${bamboo.build.working.directory}

if [ -d $tmp_path ]; then
    echo "Dirrecory exists"
else
    echo "Creating tmp directory"
    mkdir $tmp_path
fi

mapfile -t diffs < <(git diff --name-only --diff-filter="$flags" development full_94 )

function move_files_to_tmp() {
    if [[ "$file_name" == ".gitignore" ]] || [[ "$file_name" == "diff.sh" ]] || [[ "$file_name" == "destructiveChanges.xml" ]]; then
        :
    fi
    # This condition has to be here in case that aura and lwc cant be deplyed when files separated
    if [[ "$direc" == "aura" ]] || [[ "$direc" == "lwc" ]]; then
        if [ -e $file_name ]; then
            file_name=$(echo $file_name | grep -o '[a-zA-Z]*\/[a-zA-Z]*\/[A-Za-z]*.*\/')
            mv $file_name $tmp_path/$direc
        else
            :
        fi
    # emails have subdirs
    elif [[ "$direc" == "email" ]]; then
        mv $file_name $tmp_path/$direc/$subdir
    fi
    # checking if file exists and if yes move it
    if [[ -f "$file_name" ]]; then
        mv $file_name $tmp_path/$direc
    else
        :
        # echo "$file_name already moved or doesn't exist"
    fi 
}

function moving_meta_file_to_tmp() {
    meta_file="$file_name-meta.xml"
    if [[ "$direc" == "email" ]]; then
        mv $meta_file $tmp_path/$direc/$subdir
    fi
    if [[ "$direc" == "aura" ]] || [[ "$direc" == "lwc" ]]; then
        :
    fi
    if [[ -f "$meta_file" ]]; then
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
        if [[ "$apex_class" == *"-meta.xml"* ]]; then
            apex_class=$(echo "$apex_class" | sed -e 's/-meta.xml//')
        fi
        # adding to list of spec tests value from git diff if there were some test class changes
        if [[ "$apex_class" == *"$test_string"* ]] || [[ "$apex_class" == *"TEST"* ]]; then
            # validation of list to avoid unwanted ',' symbol
            if [[ "$specifiedTests" == "" ]]; then
                specifiedTests=$apex_class
            else
                # adding to existing list new value 
                specifiedTests=$specifiedTests','$apex_class
            fi
        else
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
        # validation of apex classes list to avoid unwanted ',' symbol
    fi
    if [[ "$direc" == "triggers" ]]; then
        trigger=$(echo "$apex_class" | sed -e 's/\.trigger//')
        if [[ "$trigger" == *"-meta.xml"* ]]; then
            trigger=$(echo "$trigger" | sed -e 's/-meta.xml//')
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


function create_packagexml(){
    IFS=$'\n'
    echo "Creating package.xml"
    echo "$package_xml_begining" > "$tmp_path/$file"
    for diff in ${diffs[@]}; do
        case $diff in
            *.app) NAME="CustomApplication";;
            *.assignmentRules) NAME="AssignmentRules";;
            */aura/*) NAME="AuraDefinitionBundle";;
            *.cls) NAME="ApexClass";;
            *.cls-meta.xml) continue;;
            *.component) NAME="ApexComponent";;
            *.md*) NAME="CustomMetadata";;
            *.customPermission) NAME="CustomPermission";;
            *.customPermission-meta.xml) NAME="CustomPermission";;
            */documents/*) NAME="Document";;
            *.duplicateRule) NAME="DuplicateRule";;
            */email/*) NAME="EmailTemplate";;
            */email/*/*-meta.xml) NAME="EmailTemplate";;
            *.flexipage) NAME="FlexiPage";;
            *.flow) NAME="Flow";;
            *.globalValueSet) NAME="GlobalValueSet";;
            *.group) NAME="Group";;
            *.labels) NAME="CustomLabels";;
            *.layout) NAME="Layout";;
            *.layout-meta.xml) NAME="Layout";;
            *.LeadConvertSetting) NAME="LeadConvertSetting";;
            */lwc/*) NAME="LightningComponentBundle";;
            *.matchingRule) NAME="MatchingRule";;
            *.object) NAME="CustomObject";;
            *.objectTranslation) NAME="CustomObjectTranslation";;
            *.page) NAME="ApexPage";;
            *.permissionset) NAME="PermissionSet";;
            *.permissionset-meta.xml) NAME="PermissionSet";;
            *.profile) NAME="Profile";;
            *.queueRoutingConfig) NAME="QueueRoutingConfig";;
            *.queue) NAME="Queue";;
            *.quickAction) NAME="QuickAction";;
            *.recommendationStrategy) NAME="RecommendationStrategy";;
            *.reportType) NAME="ReportType";;
            *.settings) NAME="KnowledgeSettings";;
            *.site) NAME="CustomSite";;
            *.standardValueSet) NAME="StandardValueSet";;
            *.resource) NAME="StaticResource";;
            *.resource-meta.xml) continue;;
            *.tab) NAME="CustomTab";;
            *.translation) NAME="Translations";;
            *.trigger) NAME="ApexTrigger";;
            *.workflow) NAME="Workflow";;
            *) NAME="UNKNOWN"
        esac
        # if [[ "$NAME" != "UNKNOWN TYPE" ]];then
        #     case $diff in
        #         src/email/*)
        #             MEMBER="${diff#src/email/}" 
        #             ;;
        #         src/aura/*)  
        #             MEMBER="${diff#src/aura/}" 
        #             MEMBER="${MEMBER%/*}"
        #             ;;
        #         src/lwc/*) 
        #             MEMBER="${diff#lwc/aura/}" 
        #             MEMBER="${MEMBER%/*}"
        #             ;;
        #         *) 
        #             MEMBER=$(basename "$diff")
        #             ;;    
        #     esac
        #     if [[ "$MEMBER" == *"-meta.xml" ]]; then
        #         MEMBER="${MEMBER%%.*}"
        #         MEMBER="${MEMBER%-meta*}"
        #     else
        #         MEMBER="${MEMBER%.*}"
        #     fi
        #     echo $MEMBER
        # fi
        if grep -qw $NAME "$tmp_path/$file";then
            continue
        else
            echo "    <types>
        <members>*</members>
        <name>$NAME</name>
    </types>" >> $tmp_path/$file
        fi
    done

    echo "$package_xml_ending" >> "$tmp_path/$file"
    echo "done"
}

function generate_delta(){
    echo "Generating Delta"
    IFS=$'\n'
    for file_name in "${diffs[@]}"; do
        # creating dirs for each of component
        for direc in $file_name; do
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
    echo "done"
}


generate_delta
create_packagexml
echo "PACKAGE XML GENERATED"
# adding <'> symbol to bigining and end of each of class. Need for tests query
aClasses=$(echo "$aClasses" | sed -e "s/\b/'/g")
# echo "For This classes tests will be found"
# echo "$aClasses"

echo "$aquery IN($aClasses)" > queryfile.txt

SOQL_get_tests
# echo "This classes will be executed"
# echo "$specifiedTests"

if [[ "$specifiedTests" == "" ]]; then
    sfdx force:mdapi:deploy --checkonly -u a10 -d $tmp_path -w -1
else
    sfdx force:mdapi:deploy --checkonly -u a10 -d $tmp_path -w -1 -l RunSpecifiedTests -r "$specifiedTests"
fi