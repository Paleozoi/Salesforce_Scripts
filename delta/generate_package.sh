#!/bin/bash
tmp_path='tmp'
flags='RCMA' # git flag - rename-edit|copy-edit|modified|added
file="package.xml"
package_xml_begining='<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">'

package_xml_ending="    <version>54.0</version>
</Package>"

echo "$package_xml_begining" > "$tmp_path/$file"

mapfile -t diffs < <(git diff  --name-only --diff-filter="$flags" release_90 full_90_delta_validation_specified_tests)

IFS=$'\n'
for diff in ${diffs[@]}; do
    case $diff in
        *.app) NAME="CustomApplication";;
        *.assigentRules) NAME="AssignmentRules";;
        */aura/*) NAME="AuraDefinitionBundle";;
        *.cls) NAME="ApexClass";;
        *.component) NAME="ApexComponent";;
        *.md*) NAME="CustomMetadata";;
        *.customPermission) NAME="CustomPermission";;
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
        *.LeadConvertSetting) NAME="LeadConvertSetting";;
        */lwc/*) NAME="LightningComponentBundle";;
        *.matchingRule) NAME="MatchingRule";;
        *.object) NAME="CustomObject";;
        *.objectTranslation) NAME="CustomObjectTranslation";;
        *.page) NAME="ApexPage";;
        *.permissionset) NAME="PermissionSet";;
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
        *.tab) NAME="CustomTab";;
        *.translation) NAME="Translations";;
        *.trigger) NAME="ApexTrigger";;
        *.workflow) NAME="Workflow";;
    esac
    echo "$NAME"
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
    if grep -q $NAME "$tmp_path/$file";then
        continue
    else
        echo "    <types>
        <members>*</members>
        <name>"$NAME"</name>
    </types>" >> "$tmp_path/$file"
    fi
done

echo "$package_xml_ending" >> "$tmp_path/$file"